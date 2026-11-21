import Foundation
import Combine

@MainActor
final class MerchantTicketDetailViewModel: ObservableObject {
    @Published private(set) var ticket: MerchantSupportTicket?
    @Published private(set) var reference = ""
    @Published private(set) var messages: [MerchantChatMessage] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isSending = false
    @Published private(set) var hasMore = false
    @Published private(set) var error: APIError?
    @Published private(set) var pageError: APIError?
    @Published private(set) var sendError: APIError?
    @Published private(set) var scrollRequest = UUID()
    @Published var draft = ""

    let ticketID: String
    private let responseHandler: ResponseHandler?
    private let token: () -> String?
    private var loadedToken: String?
    private var conversation: MerchantTicketConversation?
    private var page = 1
    private var generation = UUID()
    private var active = true
    private var loadTask: Task<Void, Never>?
    private var pageTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?

    var canReply: Bool { conversation?.canReply == true && conversation?.roomID != nil }
    var canSend: Bool {
        canReply && !isSending && loadTask == nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(ticketID: String, ticket: MerchantSupportTicket?, responseHandler: ResponseHandler?, token: @escaping () -> String?) {
        self.ticketID = ticketID; self.ticket = ticket; self.responseHandler = responseHandler; self.token = token
        loadedToken = token()
    }

    func activate() { active = true }

    /// Own the request so cancellation of a SwiftUI refresh gesture cannot drop its response.
    func reload(silently: Bool = false) async {
        guard active, responseHandler != nil, !isSending else { return }
        guard let requestToken = prepareSession() else { return }
        if let loadTask { await loadTask.value; return }
        pageTask?.cancel(); pageTask = nil; isLoadingMore = false
        let generation = UUID(); self.generation = generation
        isLoading = !silently || !hasLoaded; error = nil; pageError = nil
        let task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == generation { self.isLoading = false; self.loadTask = nil } }
            do {
                let response = try await self.loadTicket(page: 1, token: requestToken)
                try Task.checkCancellation()
                guard self.accepts(requestToken, generation) else { return }
                let result = try MerchantTicketConversation(response: response, ticketID: self.ticketID)
                guard result.currentPage == 1 else { throw APIError.invalidResponse }
                let firstLoad = !self.hasLoaded
                let preserveHistory = silently && self.conversation?.roomID == result.roomID
                self.apply(result)
                self.messages = MerchantChatMessage.ordered((preserveHistory ? self.messages : []) + result.messages)
                self.page = preserveHistory ? min(self.page, result.totalPages) : 1
                self.hasMore = self.page < result.totalPages
                self.hasLoaded = true
                if firstLoad { self.scrollRequest = UUID() }
            } catch {
                guard self.accepts(requestToken, generation), !Self.cancelled(error) else { return }
                self.error = APIError.map(error)
            }
        }
        loadTask = task
        await task.value
    }

    func loadMore() async {
        guard active, responseHandler != nil, let requestToken = prepareSession(),
              hasMore, loadTask == nil, pageTask == nil, !isSending else { return }
        let generation = self.generation, next = page + 1, roomID = conversation?.roomID
        isLoadingMore = true; pageError = nil
        let task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == generation { self.isLoadingMore = false; self.pageTask = nil } }
            do {
                let response = try await self.loadTicket(page: next, token: requestToken)
                try Task.checkCancellation()
                guard self.accepts(requestToken, generation) else { return }
                let result = try MerchantTicketConversation(response: response, ticketID: self.ticketID)
                guard result.currentPage == next, result.roomID == roomID else { throw APIError.invalidResponse }
                self.apply(result)
                self.messages = MerchantChatMessage.ordered(self.messages + result.messages)
                self.page = next; self.hasMore = next < result.totalPages
            } catch {
                guard self.accepts(requestToken, generation), !Self.cancelled(error) else { return }
                self.pageError = APIError.map(error)
            }
        }
        pageTask = task
        await task.value
    }

    func send() async {
        guard active, let responseHandler, let requestToken = prepareSession(),
              canSend, let roomID = conversation?.roomID else { return }
        pageTask?.cancel(); pageTask = nil; isLoadingMore = false
        let generation = UUID(); self.generation = generation
        let originalDraft = draft, message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true; sendError = nil
        let task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == generation { self.isSending = false; self.sendTask = nil } }
            do {
                guard MerchantTicketType.validID(roomID), !message.isEmpty else { throw APIError.configuration }
                let sent = try await responseHandler.data(
                    from: SupportTicketEndpoints.sendMessage(roomID: roomID, message: message, token: requestToken),
                    language: AppLanguageManager.shared.apiLanguage)
                try Task.checkCancellation()
                guard self.accepts(requestToken, generation) else { return }
                guard sent.roomID == roomID, sent.isSender else { throw APIError.invalidResponse }
                self.messages = MerchantChatMessage.ordered(self.messages + [.init(sent: sent)])
                if self.draft == originalDraft { self.draft = "" }
                self.scrollRequest = UUID()
            } catch {
                guard self.accepts(requestToken, generation), !Self.cancelled(error) else { return }
                self.sendError = APIError.map(error)
            }
        }
        sendTask = task
        await task.value
        // Reconcile permissions and server history without retrying the POST.
        if active && generation == self.generation { await reload(silently: true) }
    }

    private func loadTicket(page: Int, token: String) async throws -> MerchantSupportResponse {
        guard let responseHandler, page > 0, MerchantTicketType.validID(ticketID) else { throw APIError.configuration }
        let response = try await responseHandler.get(SupportTicketEndpoints.ticket(id: ticketID, page: page, token: token))
        guard response.data != nil else { throw APIError.invalidResponse }
        return response
    }

    func stop() {
        active = false; generation = UUID()
        loadTask?.cancel(); pageTask?.cancel(); sendTask?.cancel()
        loadTask = nil; pageTask = nil; sendTask = nil
        isLoading = false; isLoadingMore = false; isSending = false
    }

    private func apply(_ result: MerchantTicketConversation) {
        conversation = result; ticket = result.ticket; reference = result.reference
    }

    private func prepareSession() -> String? {
        let current = token()
        if current != loadedToken { clear(); loadedToken = current }
        guard let current, !current.isEmpty else { error = .unauthenticated(nil); return nil }
        return current
    }

    private func accepts(_ token: String, _ generation: UUID) -> Bool {
        guard active, self.generation == generation, !Task.isCancelled else { return false }
        guard self.token() == token else { clear(); loadedToken = nil; return false }
        return true
    }

    private func clear() {
        stop(); active = true
        ticket = nil; conversation = nil; reference = ""; messages = []; draft = ""
        hasLoaded = false; hasMore = false; page = 1; error = nil; pageError = nil; sendError = nil
    }

    private static func cancelled(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    deinit { loadTask?.cancel(); pageTask?.cancel(); sendTask?.cancel() }
}

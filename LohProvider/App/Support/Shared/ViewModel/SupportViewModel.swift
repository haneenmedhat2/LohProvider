import Foundation
import Combine

@MainActor
final class MerchantSupportViewModel: ObservableObject {
    @Published private(set) var tickets: [MerchantSupportTicket] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var error: APIError?
    @Published private(set) var isSubmitting = false
    @Published private(set) var ticketTypes: [MerchantTicketType] = []
    @Published private(set) var isLoadingTicketTypes = false
    @Published private(set) var ticketTypesError: APIError?
    @Published private(set) var ticketOrders: [MerchantTicketOrder] = []
    @Published private(set) var isLoadingTicketOrders = false
    @Published private(set) var ticketOrdersError: APIError?
    private let responseHandler: ResponseHandler?
    private let token: () -> String?
    private var generation = UUID()
    private var loadedToken: String?
    private var loadedTypesToken: String?
    private var typesGeneration = UUID()
    private var loadedOrdersToken: String?
    private var ordersGeneration = UUID()
    // Creation only returns a message. Keep its receipt separate from server ticket IDs.
    private var receipts: [String: MerchantSupportTicket] = [:]

    init(responseHandler: ResponseHandler, token: @escaping () -> String?) {
        self.responseHandler = responseHandler
        self.token = token
    }

    #if DEBUG
    init(tickets: [MerchantSupportTicket]? = nil) {
        self.tickets = tickets ?? Self.samples
        self.ticketTypes = [.init(id: "1", name: "General issue")]
        self.ticketOrders = [.init(id: "17", orderNumber: "#LOH-202617")]
        responseHandler = nil
        token = { nil }
        hasLoaded = true
    }
    #endif

    func ticket(_ id: String) -> MerchantSupportTicket? { tickets.first { $0.id == id } ?? receipts[id] }

    func conversation(for id: String) -> MerchantTicketDetailViewModel {
        .init(ticketID: id, ticket: ticket(id), responseHandler: responseHandler, token: token)
    }

    func loadTicketTypes() async {
        guard let responseHandler else { return }
        let generation = UUID()
        typesGeneration = generation
        let requestToken = token()
        if loadedTypesToken != requestToken { ticketTypes = [] }
        loadedTypesToken = requestToken
        ticketTypesError = nil
        isLoadingTicketTypes = true
        defer {
            if typesGeneration == generation {
                isLoadingTicketTypes = false
                if token() != requestToken {
                    ticketTypes = []
                    ticketTypesError = nil
                    loadedTypesToken = nil
                }
            }
        }
        do {
            guard let requestToken, !requestToken.isEmpty else { throw APIError.unauthenticated(nil) }
            let types: [MerchantTicketType] = try await responseHandler.data(
                from: SupportTicketEndpoints.types(token: requestToken), language: AppLanguageManager.shared.apiLanguage)
            guard Set(types.map(\.id)).count == types.count else { throw APIError.invalidResponse }
            try Task.checkCancellation()
            guard typesGeneration == generation, token() == requestToken else { return }
            ticketTypes = types
        } catch {
            guard typesGeneration == generation, !Task.isCancelled, token() == requestToken else { return }
            ticketTypesError = APIError.map(error)
        }
    }

    func loadTicketOrders() async {
        guard let responseHandler else { return }
        let generation = UUID()
        ordersGeneration = generation
        let requestToken = token()
        if loadedOrdersToken != requestToken { ticketOrders = [] }
        loadedOrdersToken = requestToken
        ticketOrdersError = nil
        isLoadingTicketOrders = true
        defer {
            if ordersGeneration == generation {
                isLoadingTicketOrders = false
                if token() != requestToken {
                    ticketOrders = []
                    ticketOrdersError = nil
                    loadedOrdersToken = nil
                }
            }
        }
        do {
            guard let requestToken, !requestToken.isEmpty else { throw APIError.unauthenticated(nil) }
            let orders: [MerchantTicketOrder] = try await responseHandler.data(
                from: SupportTicketEndpoints.orders(token: requestToken), language: AppLanguageManager.shared.apiLanguage)
            guard Set(orders.map(\.id)).count == orders.count else { throw APIError.invalidResponse }
            try Task.checkCancellation()
            guard ordersGeneration == generation, token() == requestToken else { return }
            ticketOrders = orders
        } catch {
            guard ordersGeneration == generation, !Task.isCancelled, token() == requestToken else { return }
            ticketOrdersError = APIError.map(error)
        }
    }

    func reload() async {
        guard let responseHandler else { return }
        let generation = UUID()
        self.generation = generation
        let requestToken = token()
        if loadedToken != requestToken {
            tickets = []; receipts = [:]; hasLoaded = false
        }
        loadedToken = requestToken
        error = nil
        isLoading = true
        defer {
            if self.generation == generation {
                isLoading = false
                if token() != requestToken {
                    tickets = []; receipts = [:]; hasLoaded = false; error = nil; loadedToken = nil
                }
            }
        }
        do {
            try Task.checkCancellation()
            guard let requestToken, !requestToken.isEmpty else { throw APIError.unauthenticated(nil) }
            let response = try await responseHandler.get(SupportTicketEndpoints.tickets(token: requestToken))
            guard response.data != nil else { throw APIError.invalidResponse }
            try Task.checkCancellation()
            guard self.generation == generation, token() == requestToken else { return }
            tickets = try MerchantSupportTicket.list(from: response)
            hasLoaded = true
        } catch {
            guard self.generation == generation, !Task.isCancelled,
                  !(error is CancellationError), (error as? URLError)?.code != .cancelled,
                  token() == requestToken else { return }
            self.error = APIError.map(error)
        }
    }

    @discardableResult
    func submit(_ draft: MerchantTicketDraft, now: Date = Date()) async throws -> MerchantSupportTicket {
        guard draft.isValid else { throw APIError.configuration }
        if responseHandler != nil {
            guard let requestToken = token(), loadedTypesToken == requestToken,
                  ticketTypes.contains(where: { $0.id == draft.typeID }) else {
                throw APIError.configuration
            }
            if let orderID = draft.orderID {
                guard loadedOrdersToken == requestToken,
                      ticketOrders.contains(where: { $0.id == orderID }) else {
                    throw APIError.configuration
                }
            }
        }
        guard !isSubmitting else { throw APIError.requestInProgress }
        isSubmitting = true
        defer { isSubmitting = false }
        try Task.checkCancellation()
        if let responseHandler {
            guard let requestToken = token(), !requestToken.isEmpty else { throw APIError.unauthenticated(nil) }
            let request = MerchantSupportRequest(typeID: draft.typeID, orderID: draft.orderID,
                                                 title: draft.title, description: draft.detail)
            _ = try await responseHandler.get(
                SupportTicketEndpoints.create(fields: try request.formFields(), token: requestToken))
            try Task.checkCancellation()
            guard token() == requestToken else { throw CancellationError() }
        }
        let detail = MerchantSupportText(verbatim: draft.detail.trimmingCharacters(in: .whitespacesAndNewlines))
        let ticket = MerchantSupportTicket(id: UUID().uuidString,
            name: "", phone: "",
            title: .init(verbatim: draft.title.trimmingCharacters(in: .whitespacesAndNewlines)),
            detail: detail, created: now, isOpen: responseHandler == nil ? true : nil,
            messages: responseHandler == nil ? [.init(fromSupport: false, text: detail, date: now)] : [],
            typeName: ticketTypes.first(where: { $0.id == draft.typeID })?.name,
            orderID: draft.orderID)
        receipts[ticket.id] = ticket
        #if DEBUG
        if responseHandler == nil { tickets.insert(ticket, at: 0) }
        #endif
        return ticket
    }

    #if DEBUG
    static let samples: [MerchantSupportTicket] = {
        let formatter = ISO8601DateFormatter()
        func date(_ value: String) -> Date { formatter.date(from: value)! }
        let firstDate = date("2024-07-30T09:41:00+03:00")
        let issue = MerchantSupportText("When trying to use the offer, an error appears... The request cannot be completed.", "عند محاولة استخدام العرض يظهر لي خطأ ولا يمكن إتمام الطلب.")
        let replies: [MerchantTicketMessage] = [
            .init(fromSupport: false, text: issue, date: firstDate),
            .init(fromSupport: true, text: .init("Hello,\nWe have received your request and started reviewing the issue. We will get back to you as soon as possible. Thank you for contacting us.", "أهلاً بك، تم استلام طلبك وبدأ مراجعة المشكلة. سنقوم بالرد عليك في أقرب وقت ممكن. شكراً لتواصلك معنا."), date: date("2024-07-30T10:15:00+03:00")),
            .init(fromSupport: false, text: .init("Thank you, I'll wait for your response.", "شكراً لكم، بانتظار ردكم."), date: date("2024-07-30T11:02:00+03:00")),
            .init(fromSupport: true, text: .init("The issue has been resolved. Please update the app and try again. We hope you are now able to use the offer without any issues. Thank you.", "تم حل المشكلة بنجاح. يرجى تحديث التطبيق ثم المحاولة مرة أخرى. في حال استمرت المشكلة تواصل معنا. شكراً لك."), date: date("2024-07-30T12:30:00+03:00"))
        ]
        let rows: [(String, MerchantSupportText, MerchantSupportText, Date)] = [
            ("offer", .init("Issue using the offer", "مشكلة في استخدام العرض"), issue, firstDate),
            ("refund", .init("Refund Request", "استرجاع المبلغ"), .init("The refund has been completed successfully. Thank you.", "تم استرجاع المبلغ بنجاح، شكراً لكم."), date("2024-07-25T16:30:00+03:00")),
            ("suggestion", .init("Suggest an Offer", "اقتراح بشأن العروض"), .init("Suggest adding new offers in the cafes section.", "اقتراح إضافة عروض جديدة في قسم الكافيهات."), date("2024-07-18T11:20:00+03:00")),
            ("verification", .init("I didn't receive the verification code", "لم أستلم رمز التحقق"), .init("The issue has been resolved, and we have sent you the verification code now.", "تم حل المشكلة، وصلتني رسالة التحقق الآن."), date("2024-07-10T08:15:00+03:00"))
        ]
        return rows.map { id, title, detail, created in
            MerchantSupportTicket(id: id, name: "Ahmed Mohammed", phone: "05XXXXXXXX", title: title,
                                  detail: detail, created: created, isOpen: id == "offer",
                                  messages: id == "offer" ? replies : [.init(fromSupport: false, text: detail, date: created)])
        }
    }()
    #endif
}

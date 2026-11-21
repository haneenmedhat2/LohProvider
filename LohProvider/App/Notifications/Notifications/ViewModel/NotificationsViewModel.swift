import Foundation
import Combine

@MainActor
final class MerchantNotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [MerchantNotification] = []
    @Published private(set) var count: Int?
    @Published private(set) var countError: APIError?
    @Published private(set) var hasLoaded = false
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: APIError?
    @Published private(set) var pageError: APIError?
    @Published private(set) var mutationError: APIError?
    @Published private(set) var deleting: MerchantNotificationDeletion?
    @Published private(set) var isMarkingRead = false

    var isMutating: Bool { deleting != nil || isMarkingRead }
    var canMarkAllAsRead: Bool {
        !isMutating && ((count ?? 0) > 0 || notifications.contains { $0.isRead != true })
    }

    private let responseHandler: ResponseHandler?
    private let token: () -> String?
    private var accountToken: String?
    private var page = 0
    private var generation = UUID()
    private var countGeneration = UUID()
    private var mutationGeneration = UUID()
    private var refreshID = UUID()
    private var refreshTask: Task<Void, Never>?
    private var locallyReadIDs: Set<String> = []

    func dismissMutationError() { mutationError = nil }

    init(responseHandler: ResponseHandler? = nil, token: @escaping () -> String? = { nil }) {
        self.responseHandler = responseHandler
        self.token = token
        accountToken = token()
    }

    func refreshCount() async {
        synchronizeAccount()
        guard let responseHandler, let current = token(), !isMutating else { return }
        let id = UUID()
        countGeneration = id
        countError = nil
        defer { synchronizeAccount() }
        do {
            let result: MerchantNotificationCount = try await responseHandler.data(
                from: NotificationEndpoints.count(token: current), language: AppLanguageManager.shared.apiLanguage)
            try Task.checkCancellation()
            guard countGeneration == id, token() == current else { return }
            count = result.count
        } catch {
            guard countGeneration == id, token() == current, !isCancellation(error) else { return }
            countError = APIError.map(error)
        }
    }

    /// SwiftUI's refresh gesture may cancel its task before the response arrives.
    func reload() async {
        synchronizeAccount()
        guard !isMutating else { return }
        cancelRefresh()
        let id = UUID()
        refreshID = id
        let task = Task {
            await fetch(replacing: true)
            if !Task.isCancelled { await refreshCount() }
        }
        refreshTask = task
        await task.value
        if refreshID == id { refreshTask = nil }
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = UUID()
        generation = UUID()
        isLoading = false
        isLoadingMore = false
    }

    func loadMore() async {
        synchronizeAccount()
        guard hasMore, !isLoading, !isLoadingMore, !isMutating else { return }
        await fetch(replacing: false)
    }

    private func fetch(replacing: Bool) async {
        guard !Task.isCancelled else { return }
        synchronizeAccount()
        guard let responseHandler else { hasLoaded = true; return }
        let id = replacing ? UUID() : generation
        generation = id
        if replacing { isLoading = true; isLoadingMore = false; error = nil; pageError = nil }
        else { isLoadingMore = true; pageError = nil }
        defer {
            if generation == id {
                if replacing { isLoading = false } else { isLoadingMore = false }
            }
            synchronizeAccount()
        }
        do {
            guard let current = token() else { throw APIError.unauthenticated(nil) }
            let requestedPage = replacing ? 1 : page + 1
            let result: MerchantNotificationPage = try await responseHandler.data(
                from: NotificationEndpoints.list(page: requestedPage, perPage: nil, token: current),
                language: AppLanguageManager.shared.apiLanguage)
            guard result.pagination.currentPage == requestedPage else { throw APIError.invalidResponse }
            try Task.checkCancellation()
            guard generation == id, token() == current else { return }
            var seen: Set<String> = []
            notifications = ((replacing ? [] : notifications) + result.notifications)
                .filter { seen.insert($0.id).inserted }
                .map { item in
                    var item = item
                    if locallyReadIDs.contains(item.id) { item.isRead = true }
                    return item
                }
            page = result.pagination.currentPage
            hasMore = result.hasMore
            hasLoaded = true
        } catch {
            guard generation == id, accountToken == token(), !isCancellation(error) else { return }
            if replacing { self.error = APIError.map(error) }
            else { pageError = APIError.map(error) }
        }
    }

    @discardableResult
    func markAllAsRead() async -> Bool {
        await markRead(id: nil)
    }

    @discardableResult
    func markAsRead(id: String) async -> Bool {
        await markRead(id: id)
    }

    private func markRead(id notificationID: String?) async -> Bool {
        synchronizeAccount()
        guard !Task.isCancelled, !isMutating, let responseHandler, let current = token() else { return false }
        let previousReadState: Bool?
        if let notificationID {
            guard let notification = notifications.first(where: { $0.id == notificationID }) else { return false }
            if notification.isRead == true { return true }
            previousReadState = notification.isRead
        } else {
            guard canMarkAllAsRead else { return false }
            previousReadState = nil
        }
        cancelRefresh()
        countGeneration = UUID()
        let id = UUID()
        mutationGeneration = id
        isMarkingRead = true
        mutationError = nil
        do {
            if let notificationID {
                try validateID(notificationID)
                try await responseHandler.perform(NotificationEndpoints.markAsRead(id: notificationID, token: current),
                                                  language: AppLanguageManager.shared.apiLanguage)
            } else {
                try await responseHandler.perform(NotificationEndpoints.markAllAsRead(token: current),
                                                  language: AppLanguageManager.shared.apiLanguage)
            }
            try Task.checkCancellation()
            guard mutationGeneration == id, token() == current else { synchronizeAccount(); return false }
            let readIDs = notificationID.map { [$0] } ?? notifications.map(\.id)
            locallyReadIDs.formUnion(readIDs)
            for index in notifications.indices where locallyReadIDs.contains(notifications[index].id) {
                notifications[index].isRead = true
            }
            isMarkingRead = false
            if notificationID == nil {
                count = 0
                countError = nil
            } else if previousReadState == false, let count {
                self.count = max(0, count - 1)
            } else {
                // Missing read flags cannot tell us whether this changed the unread count.
                await refreshCount()
            }
            return token() == current
        } catch {
            guard mutationGeneration == id, token() == current else { synchronizeAccount(); return false }
            isMarkingRead = false
            if !isCancellation(error) { mutationError = APIError.map(error) }
            return false
        }
    }

    func delete(_ action: MerchantNotificationDeletion) async {
        synchronizeAccount()
        guard !isMutating, let responseHandler, let current = token() else { return }
        if case .one(let id) = action, !notifications.contains(where: { $0.id == id }) { return }
        guard !notifications.isEmpty else { return }
        cancelRefresh()
        countGeneration = UUID()
        deleting = action
        mutationError = nil
        let id = UUID()
        mutationGeneration = id
        do {
            switch action {
            case .one(let notificationID):
                try validateID(notificationID)
                try await responseHandler.perform(
                    NotificationEndpoints.delete(id: notificationID, token: current),
                    language: AppLanguageManager.shared.apiLanguage)
            case .all:
                try await responseHandler.perform(
                    NotificationEndpoints.deleteAll(token: current), language: AppLanguageManager.shared.apiLanguage)
            }
            try Task.checkCancellation()
            guard mutationGeneration == id, token() == current else { synchronizeAccount(); return }
            switch action {
            case .one(let notificationID):
                notifications.removeAll { $0.id == notificationID }
                locallyReadIDs.remove(notificationID)
            case .all:
                notifications = []; locallyReadIDs = []; page = 0; hasMore = false; hasLoaded = true
            }
            count = nil
            deleting = nil
            error = nil; pageError = nil
            // Removing an item shifts page boundaries; reload page one before paginating again.
            if case .one = action { hasMore = false; await reload() }
            else { await refreshCount() }
        } catch {
            guard mutationGeneration == id, token() == current else { synchronizeAccount(); return }
            deleting = nil
            if !isCancellation(error) { mutationError = APIError.map(error) }
        }
    }

    private func synchronizeAccount() {
        let current = token()
        guard current != accountToken else { return }
        cancelRefresh()
        countGeneration = UUID()
        mutationGeneration = UUID()
        accountToken = current
        notifications = []; locallyReadIDs = []; count = nil; page = 0
        countError = nil
        hasLoaded = false; hasMore = false
        error = nil; pageError = nil; mutationError = nil; deleting = nil; isMarkingRead = false
    }

    private func validateID(_ value: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !value.isEmpty, value.unicodeScalars.allSatisfy(allowed.contains) else { throw APIError.configuration }
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}

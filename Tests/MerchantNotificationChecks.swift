import Foundation

// Host-only network boundary. Production endpoints, payload decoding, and view-model logic are compiled below.
enum APIError: Error, Equatable {
    case invalidResponse, configuration, offline, unauthenticated(String?)
    static func map(_ error: Error) -> APIError { error as? APIError ?? .invalidResponse }
}
typealias APIParameters = [String: Any?]
enum RequestMethod { case get, patch, delete }
enum RequestHeaderType { case authorized(token: String) }
struct Endpoint<Response: Decodable> {
    let method: RequestMethod
    let path: String
    let queries: APIParameters?
    let headerType: RequestHeaderType
    init(method: RequestMethod = .get, path: String, queries: APIParameters? = nil, headerType: RequestHeaderType) {
        self.method = method; self.path = path; self.queries = queries; self.headerType = headerType
    }
}
struct AppLanguageManager {
    static let shared = AppLanguageManager()
    let apiLanguage = "ar"
}
@MainActor protocol ResponseHandler {
    func data<Value: Decodable>(from endpoint: Endpoint<APIEnvelope<Value>>, language: String?) async throws -> Value
    func perform(_ endpoint: Endpoint<APIEnvelope<APIEmpty>>, language: String?) async throws
}
@MainActor final class NotificationClient: ResponseHandler {
    struct Request {
        let method: RequestMethod
        let path: String
        let token: String
        let page: Int?
    }
    var requests: [Request] = []
    var action: (Request) async throws -> Data = { _ in throw APIError.offline }
    private func send<T: Decodable>(_ endpoint: Endpoint<T>) async throws -> Data {
        let token: String
        switch endpoint.headerType { case .authorized(let value): token = value }
        let request = Request(method: endpoint.method, path: endpoint.path, token: token, page: endpoint.queries?["page"] as? Int)
        requests.append(request)
        return try await action(request)
    }
    func data<Value: Decodable>(from endpoint: Endpoint<APIEnvelope<Value>>, language: String?) async throws -> Value {
        let result = try JSONDecoder().decode(APIEnvelope<Value>.self, from: await send(endpoint))
        guard result.key == "success", let data = result.data else { throw APIError.invalidResponse }
        return data
    }
    func perform(_ endpoint: Endpoint<APIEnvelope<APIEmpty>>, language: String?) async throws {
        let result = try JSONDecoder().decode(APIEnvelope<APIEmpty>.self, from: await send(endpoint))
        guard result.key == "success" else { throw APIError.invalidResponse }
    }
}

@main
struct MerchantNotificationChecks {
    static func expect(_ condition: Bool, _ message: String = "Notification check failed") {
        precondition(condition, message)
    }
    static let success = Data(#"{"key":"success"}"#.utf8)
    static func count(_ value: Int) -> Data { Data("{\"key\":\"success\",\"data\":{\"count\":\(value)}}".utf8) }
    static func row(_ id: String, read: Any? = false) -> [String: Any] {
        var row: [String: Any] = ["id": id, "title": "Offer", "body": "Details", "created_at": "منذ شهر",
                                  "is_clickable": true, "coupon_id": 42]
        if let read { row["is_read"] = read }
        return row
    }
    static func page(_ rows: [[String: Any]], current: Int = 1, pages: Int = 1, total: Int? = nil) -> Data {
        try! JSONSerialization.data(withJSONObject: ["key": "success", "data": [
            "pagination": ["total_items": total ?? rows.count, "count_items": rows.count, "per_page": 20,
                           "total_pages": pages, "current_page": current], "data": rows]])
    }
    @MainActor static func main() async throws {
        try decoding()
        try await readActions()
        await concurrentRequests()
        await accountIsolation()
        await cancellationAndInvalidIDs()
        print("Passed: notification read decoding, both PATCH routes, unread counts, failure/retry, retained rows, deletion, stale reads, duplicate protection, cancellation, and account isolation.")
    }

    static func decoding() throws {
        func decoded(_ fields: [String: Any]) throws -> MerchantNotification {
            try JSONDecoder().decode(MerchantNotification.self,
                                     from: JSONSerialization.data(withJSONObject: row("routing").merging(fields) { _, new in new }))
        }
        expect(try decoded(["type": "new_order", "key": "owner_notify", "order_id": 25, "coupon_id": 12]).destination == .order("25"))
        expect(try decoded(["type": "settlement_request", "coupon_id": 12]).destination == .settlements)
        expect(try decoded(["type": "new_order", "order_id": "0"]).destination == .notifications)
        expect(try decoded(["type": "new_order", "order_id": "25", "is_clickable": false]).destination == .order("25"))
        expect(try decoded(["type": "owner_notify", "data": ["type": "new_order", "order_id": "25"],
                            "is_clickable": false]).destination == .order("25"))
        expect(try decoded(["key": "new_order", "type": "owner_notify", "order_id": 25,
                            "is_clickable": false]).destination == .order("25"))
        expect(try decoded(["key": "new_order", "data": ["type": "owner_notify", "order_id": "25"]]).destination == .order("25"))
        expect(try decoded(["type": "settlement_request", "is_clickable": false]).destination == .settlements)
        expect(MerchantNotificationDestination.fromPush(["type": "new_order", "key": "owner_notify", "order_id": "25"]) == .order("25"))
        expect(MerchantNotificationDestination.fromPush(["data": ["type": "settlement_request", "amount": "250.00"]]) == .settlements)
        for value: Any in [true, 1, "1", "true"] {
            let model = try JSONDecoder().decode(MerchantNotification.self, from: JSONSerialization.data(withJSONObject: row("1", read: value)))
            expect(model.isRead == true)
        }
        for value: Any in [false, 0, "0", "false"] {
            let model = try JSONDecoder().decode(MerchantNotification.self, from: JSONSerialization.data(withJSONObject: row("1", read: value)))
            expect(model.isRead == false)
        }
        var data = row("1", read: nil)
        let unknown = try JSONDecoder().decode(MerchantNotification.self, from: JSONSerialization.data(withJSONObject: data))
        expect(unknown.isRead == nil)
        data["read_at"] = NSNull()
        expect(try JSONDecoder().decode(MerchantNotification.self, from: JSONSerialization.data(withJSONObject: data)).isRead == false)
        data["read_at"] = "2026-11-08T12:00:00Z"
        expect(try JSONDecoder().decode(MerchantNotification.self, from: JSONSerialization.data(withJSONObject: data)).isRead == true)
    }

    @MainActor static func readActions() async throws {
        let client = NotificationClient()
        let model = MerchantNotificationsViewModel(responseHandler: client, token: { "token" })
        var rows = [row("1"), row("2"), row("3", read: true)]
        var unread = 2
        var failWrites = false
        client.action = { request in
            if request.method == .patch {
                if failWrites { throw APIError.offline }
                return success
            }
            if request.method == .delete { rows.removeAll { $0["id"] as? String == "1" }; return success }
            return request.path.hasSuffix("count-notifications") ? count(unread) : page(rows)
        }
        await model.reload()
        expect(model.count == 2 && model.notifications.count == 3)
        expect(await model.markAsRead(id: "1"))
        expect(model.count == 1 && model.notifications[0].isRead == true && model.notifications[1].isRead == false)
        let firstRead = client.requests.last!
        expect(firstRead.path == "vendor/read-notification/1" && firstRead.method == .patch && firstRead.token == "token")
        let calls = client.requests.count
        expect(await model.markAsRead(id: "1"))
        expect(client.requests.count == calls, "Already-read notifications must not decrement the badge twice")
        failWrites = true
        expect(!(await model.markAllAsRead()))
        expect(model.count == 1 && model.notifications[1].isRead == false && model.mutationError == .offline)
        failWrites = false
        expect(await model.markAllAsRead())
        expect(client.requests.last?.path == "vendor/read-notifications" && client.requests.last?.method == .patch)
        expect(model.count == 0 && model.notifications.count == 3 && model.notifications.allSatisfy { $0.isRead == true })
        expect(!model.canMarkAllAsRead && model.mutationError == nil)
        expect(!client.requests.contains { $0.method == .delete })

        rows.append(row("new")); unread = 1
        await model.reload()
        expect(model.notifications[0].isRead == true && model.notifications.last?.isRead == false,
                     "Refresh must preserve confirmed reads without marking new arrivals read")
        rows.append(row("legacy", read: nil))
        await model.reload()
        unread = 0
        expect(await model.markAsRead(id: "legacy"))
        expect(model.count == 0 && client.requests.last?.path == "vendor/count-notifications")
        await model.delete(.one("1"))
        expect(!model.notifications.contains { $0.id == "1" } && model.mutationError == nil)
    }

    @MainActor static func concurrentRequests() async {
        let client = NotificationClient()
        let model = MerchantNotificationsViewModel(responseHandler: client, token: { "token" })
        client.action = { request in request.path.hasSuffix("count-notifications") ? count(2) : page([row("1"), row("2")]) }
        await model.reload()
        var pendingCount: CheckedContinuation<Data, Error>?
        client.action = { _ in try await withCheckedThrowingContinuation { pendingCount = $0 } }
        let counting = Task { await model.refreshCount() }
        while pendingCount == nil { await Task.yield() }
        var pendingWrite: CheckedContinuation<Data, Error>?
        client.action = { _ in try await withCheckedThrowingContinuation { pendingWrite = $0 } }
        let marking = Task { await model.markAllAsRead() }
        while pendingWrite == nil { await Task.yield() }
        let calls = client.requests.count
        await model.reload(); await model.loadMore(); await model.delete(.one("1"))
        expect(!(await model.markAllAsRead()))
        expect(!(await model.markAsRead(id: "1")))
        expect(client.requests.count == calls && model.isMutating)
        pendingWrite?.resume(returning: success)
        expect(await marking.value)
        pendingCount?.resume(returning: count(99))
        await counting.value
        expect(model.count == 0 && !model.isMutating, "An older count response must not undo marking read")
    }

    @MainActor static func accountIsolation() async {
        var token = "old"
        let client = NotificationClient()
        let model = MerchantNotificationsViewModel(responseHandler: client, token: { token })
        client.action = { request in request.path.hasSuffix("count-notifications") ? count(1) : page([row(request.token)]) }
        await model.reload()
        var pending: CheckedContinuation<Data, Error>?
        client.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let marking = Task { await model.markAllAsRead() }
        while pending == nil { await Task.yield() }
        token = "new"
        client.action = { request in request.path.hasSuffix("count-notifications") ? count(1) : page([row(request.token)]) }
        await model.reload()
        pending?.resume(returning: success)
        expect(!(await marking.value))
        expect(model.notifications.first?.id == "new" && model.notifications.first?.isRead == false && model.count == 1)
    }

    @MainActor static func cancellationAndInvalidIDs() async {
        let client = NotificationClient()
        let model = MerchantNotificationsViewModel(responseHandler: client, token: { "token" })
        client.action = { request in request.path.hasSuffix("count-notifications") ? count(2) : page([row("bad/id"), row("good")]) }
        await model.reload()
        let calls = client.requests.count
        expect(!(await model.markAsRead(id: "bad/id")))
        expect(client.requests.count == calls && model.mutationError == .configuration)
        model.dismissMutationError()
        var pending: CheckedContinuation<Data, Error>?
        client.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let marking = Task { await model.markAsRead(id: "good") }
        while pending == nil { await Task.yield() }
        marking.cancel()
        pending?.resume(returning: success)
        expect(!(await marking.value))
        expect(model.count == 2 && model.notifications.last?.isRead == false && !model.isMutating && model.mutationError == nil)
    }
}

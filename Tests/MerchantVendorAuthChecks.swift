import Foundation

@MainActor
private final class VendorAuthTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var response = HTTPResponse(statusCode: 200, data: Data())
    var failure: Error?
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        if let failure { throw failure }
        return response
    }
    func respond(_ json: String, status: Int = 200) {
        failure = nil
        response = .init(statusCode: status, data: Data(json.utf8))
    }
}

@main
struct MerchantVendorAuthChecks {
    // Synthetic data follows each of the four saved Vendor/Auth notifications response examples.
    private static let notificationID = "00000000-0000-4000-8000-000000000001"
    private static let currentRow = #"{"id":"00000000-0000-4000-8000-000000000001","key":"coupon_notify","title":"Test offer","body":"Offer updated","is_clickable":true,"coupon_id":42,"created_at":"منذ دقيقتين"}"#
    private static let legacyRow = #"{"id":"00000000-0000-4000-8000-000000000002","type":"test","title":"Test notification","body":"Example body","data":{"type":"test"},"created_at":"منذ شهر"}"#

    private static func pageJSON(page: Int, pages: Int, total: Int, rows: String, count: Int, perPage: String = "20", nested: Bool = false) -> String {
        let page = """
        {"pagination":{"total_items":\(total),"count_items":\(count),"per_page":\(perPage),"total_pages":\(pages),"current_page":\(page),"next_page_url":"https://untrusted.example/notifications?page=99","perv_page_url":"http://localhost:8000/api/v1/notifications?page=1"},"data":[\(rows)]}
        """
        return "{\"key\":\"success\",\"data\":" + (nested ? "{\"notifications\":\(page)}" : page) + "}"
    }

    @MainActor static func main() async throws {
        let transport = VendorAuthTransport()
        var language = "ar"
        var unauthorized: String?
        let client = DefaultResponseHandler(transport: transport, language: { language }, logger: .init(output: { _ in }))
        client.onUnauthorized = { unauthorized = $0 }
        let notifications = MerchantNotificationService(client: client)
        let auth = MerchantAuthService(client: client)

        transport.respond(pageJSON(page: 1, pages: 1, total: 1, rows: currentRow, count: 1))
        let first = try await notifications.notifications(token: "merchant-token")
        precondition(first.notifications.count == 1 && first.pagination.totalItems == 1 && !first.hasMore)
        let row = first.notifications[0]
        precondition(row.id == notificationID && row.type == "coupon_notify" && row.isClickable && row.couponID == "42")
        precondition(row.createdAt == "منذ دقيقتين", "Localized relative dates must not be interpreted as timestamps")
        checkRequest(transport, path: "notifications", method: "GET")
        let firstQuery = query(transport)
        precondition(firstQuery == [URLQueryItem(name: "page", value: "1")])
        precondition(transport.requests.last?.value(forHTTPHeaderField: "lang") == "ar")

        language = "en"
        transport.respond(pageJSON(page: 2, pages: 3, total: 3, rows: legacyRow, count: 1, perPage: #""1""#, nested: true))
        let dynamic = try await notifications.notifications(page: 2, perPage: 1, token: "merchant-token")
        precondition(dynamic.hasMore && dynamic.pagination.perPage == 1 && dynamic.pagination.currentPage == 2)
        precondition(dynamic.notifications[0].type == "test" && !dynamic.notifications[0].isClickable && dynamic.notifications[0].couponID == nil)
        precondition(query(transport) == [.init(name: "page", value: "2"), .init(name: "paginate", value: "1")])
        precondition(transport.requests.last?.value(forHTTPHeaderField: "lang") == "en")
        precondition(transport.requests.count == 2, "Pagination must not follow URLs from the response")

        transport.respond(pageJSON(page: 1, pages: 1, total: 0, rows: "", count: 0, nested: true))
        let empty = try await notifications.notifications(token: "merchant-token")
        precondition(empty.notifications.isEmpty && empty.pagination.totalItems == 0 && !empty.hasMore)
        transport.respond(pageJSON(page: 2, pages: 1, total: 3, rows: "", count: 0, nested: true))
        let outOfRange = try await notifications.notifications(page: 2, token: "merchant-token")
        precondition(outOfRange.notifications.isEmpty && !outOfRange.hasMore)

        let nonclickable = currentRow.replacingOccurrences(of: "\"coupon_id\":42", with: "\"coupon_id\":0")
            .replacingOccurrences(of: "\"is_clickable\":true", with: "\"is_clickable\":false")
        transport.respond(pageJSON(page: 1, pages: 1, total: 1, rows: nonclickable, count: 1))
        let zeroCoupon = try await notifications.notifications(token: "merchant-token")
        precondition(zeroCoupon.notifications[0].couponID == nil && !zeroCoupon.notifications[0].isClickable)

        for (value, expected) in [("0", 0), (#""4""#, 4)] {
            transport.respond("{\"key\":\"success\",\"data\":{\"count\":\(value)}}")
            let count = try await notifications.count(token: "merchant-token")
            precondition(count == expected)
            checkRequest(transport, path: "count-notifications", method: "GET")
            precondition(query(transport).isEmpty)
        }

        transport.respond(#"{"key":"success","msg":"Deleted"}"#)
        try await notifications.deleteNotification(id: notificationID, token: "merchant-token")
        checkRequest(transport, path: "delete-notification/" + notificationID, method: "DELETE")
        try await notifications.deleteAll(token: "merchant-token")
        checkRequest(transport, path: "delete-notifications", method: "DELETE")
        try await auth.deleteAccount(token: "merchant-token")
        checkRequest(transport, path: "delete-account", method: "DELETE")
        precondition(query(transport).isEmpty)

        transport.respond(#"{"key":"success","msg":"Language updated"}"#)
        for code in ["en", "ar"] {
            try await auth.changeLanguage(code, token: "merchant-token")
            let request = transport.requests.last!
            precondition(request.url?.absoluteString == "https://upgrade.loh.com.sa/api/change-lang?lang=" + code)
            precondition(request.httpMethod == "PATCH" && request.httpBody == nil)
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer merchant-token")
            precondition(query(transport) == [.init(name: "lang", value: code)])
        }
        let requestCount = transport.requests.count
        await expect(.configuration) { try await auth.changeLanguage("fr", token: "merchant-token") }
        await expect(.configuration) { _ = try await notifications.notifications(page: 0, token: "merchant-token") }
        await expect(.configuration) { _ = try await notifications.notifications(perPage: 0, token: "merchant-token") }
        for id in ["", "../profile", "a/b", "a?b", "a#b", "%2F", "\n"] {
            await expect(.configuration) { try await notifications.deleteNotification(id: id, token: "merchant-token") }
        }
        precondition(transport.requests.count == requestCount, "Invalid arguments must fail before a request")

        for invalid in [#"{"key":"success","data":{}}"#,
                        pageJSON(page: 1, pages: 1, total: 1, rows: currentRow, count: 0),
                        pageJSON(page: 2, pages: 2, total: 1, rows: currentRow, count: 1),
                        pageJSON(page: 1, pages: 1, total: 1, rows: currentRow, count: 1, perPage: "0")] {
            transport.respond(invalid)
            await expect(.invalidResponse) { _ = try await notifications.notifications(token: "merchant-token") }
        }
        transport.respond(#"{"key":"success","data":{"count":-1}}"#)
        await expect(.invalidResponse) { _ = try await notifications.count(token: "merchant-token") }

        transport.respond(#"{"key":"fail","msg":"Cannot delete"}"#)
        let beforeFailure = transport.requests.count
        await expect(.server(message: "Cannot delete", fields: [:])) { try await notifications.deleteAll(token: "merchant-token") }
        await expect(.server(message: "Cannot delete", fields: [:])) { try await auth.deleteAccount(token: "merchant-token") }
        precondition(transport.requests.count == beforeFailure + 2, "Deletion is not automatically retried")
        transport.respond(#"{"key":"fail","msg":"Cannot change language"}"#)
        await expect(.server(message: "Cannot change language", fields: [:])) {
            try await auth.changeLanguage("en", token: "merchant-token")
        }
        transport.respond(#"{"key":"unauthenticated","msg":"Login again"}"#)
        await expect(.unauthenticated("Login again")) { _ = try await notifications.count(token: "expired-token") }
        precondition(unauthorized == "expired-token")
        transport.respond("", status: 401)
        await expect(.unauthenticated(nil)) { try await auth.deleteAccount(token: "expired-account-token") }
        precondition(unauthorized == "expired-account-token")
        await expect(.unauthenticated(nil)) { try await auth.changeLanguage("en", token: "expired-language-token") }
        precondition(unauthorized == "expired-language-token")
        transport.failure = URLError(.notConnectedToInternet)
        await expect(.offline) { _ = try await notifications.notifications(token: "merchant-token") }
        transport.failure = CancellationError()
        do { try await notifications.deleteAll(token: "merchant-token"); preconditionFailure("Cancellation swallowed") }
        catch is CancellationError {}
        do { try await auth.changeLanguage("en", token: "merchant-token"); preconditionFailure("Cancellation swallowed") }
        catch is CancellationError {}

        print("Passed: Vendor Auth routes, shared change-lang route, both notification envelopes, pagination/empty pages, count, deletion, authentication headers, validation, failures, and cancellation.")
    }

    @MainActor private static func checkRequest(_ transport: VendorAuthTransport, path: String, method: String) {
        let request = transport.requests.last!
        precondition(request.url?.host == "upgrade.loh.com.sa" && request.url?.path == "/api/vendor/" + path)
        precondition(request.httpMethod == method && request.httpBody == nil)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer merchant-token")
    }

    @MainActor private static func query(_ transport: VendorAuthTransport) -> [URLQueryItem] {
        URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
    }

    @MainActor private static func expect(_ expected: APIError, operation: () async throws -> Void) async {
        do { try await operation(); preconditionFailure("Expected API failure") }
        catch { precondition(error as? APIError == expected, "Unexpected error: \(error)") }
    }
}

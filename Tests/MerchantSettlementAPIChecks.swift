import Foundation

@MainActor
private final class SettlementTransport: HTTPTransport {
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

@MainActor
private final class SettlementServiceStub: MerchantSettlementServicing {
    var tokens: [String] = []
    var action: () async throws -> MerchantReceiptPage = { throw APIError.offline }
    func receipts(token: String) async throws -> MerchantReceiptPage {
        tokens.append(token)
        return try await action()
    }
    func details(id: String, token: String) async throws -> MerchantSettlementFinancials {
        preconditionFailure("The settlements root must request receipts, not an invented detail ID")
    }
}

@main
struct MerchantSettlementAPIChecks {
    // The collection still supplies this summary for settlement-details.
    private static let savedResponse = #"{"key":"success","msg":"تم الإرسال بنجاح","data":{"deserved_amount":"192.0","marketer_percentage_amount":"0.0","marketer_percentage_from_loh":"0.0","app_percentage_type":"ratio","app_percentage":"0.0","app_percentage_amount":"0.0","currency":"ريال"}}"#

    private static let receiptsResponse = #"{"key":"success","msg":"تم الإرسال بنجاح","data":{"receipts":[],"pagination":{"count_items":0,"current_page":1,"next_page_url":"","per_page":10,"perv_page_url":"","prev_page_url":"","total_items":0,"total_pages":1}}}"#
    private static let populatedResponse = #"{"key":"success","msg":"تم الإرسال بنجاح","data":{"receipts":[{"amount":"-63.14","created_at":"2026-11-15","currency":"ريال","date_text":"الأحد 15 نوفمبر 2026","description":"تم تسليم مبلغ -63.14 ر.س المستحق بنجاح","id":53,"status":"completed","status_text":"تم التسوية","time_text":"12:56 م"}],"pagination":{"count_items":1,"current_page":1,"next_page_url":"","per_page":10,"perv_page_url":"","prev_page_url":"","total_items":1,"total_pages":1}}}"#

    @MainActor static func main() async throws {
        try await storeChecks()
        let transport = SettlementTransport()
        var language = "ar"
        var invalidated: String?
        let client = DefaultResponseHandler(transport: transport, language: { language }, logger: .init(output: { _ in }))
        client.onUnauthorized = { invalidated = $0 }
        let service = MerchantSettlementService(client: client)
        transport.respond(receiptsResponse)
        let receipts = try await service.receipts(token: "merchant-token")
        precondition(receipts.receipts.isEmpty && receipts.pagination.totalItems == 0)
        precondition(receipts.pagination.currentPage == 1 && receipts.pagination.totalPages == 1)
        precondition(receipts.pagination.perPage == 10 && receipts.pagination.countItems == 0)
        precondition(receipts.pagination.nextPageURL == "" && receipts.pagination.previousPageURL == "")
        checkRequest(transport, path: "my-receipts", language: "ar")
        transport.respond(populatedResponse)
        let populated = try await service.receipts(token: "merchant-token")
        precondition(populated.receipts.count == 1)
        let receipt = populated.receipts[0]
        precondition(receipt.id == 53 && receipt.amount == decimal("-63.14"), "Keep the signed amount exactly")
        precondition(receipt.createdAt == "2026-11-15" && receipt.dateText == "الأحد 15 نوفمبر 2026")
        precondition(receipt.timeText == "12:56 م" && receipt.currency == "ريال")
        precondition(receipt.status == "completed" && receipt.statusText == "تم التسوية")
        precondition(receipt.description.contains("-63.14"))
        transport.respond(populatedResponse.replacingOccurrences(of: #""amount":"-63.14""#, with: #""amount":-63.14"#))
        let numericAmount = try await service.receipts(token: "merchant-token")
        precondition(numericAmount.receipts[0].amount == decimal("-63.14"))
        for bad in [receiptsResponse.replacingOccurrences(of: "\"receipts\":[]", with: "\"receipts\":null"),
                    receiptsResponse.replacingOccurrences(of: "\"receipts\":[]", with: "\"receipts\":[1]"),
                    receiptsResponse.replacingOccurrences(of: "\"count_items\":0", with: "\"count_items\":1"),
                    receiptsResponse.replacingOccurrences(of: "\"total_items\":0", with: "\"total_items\":-1"),
                    receiptsResponse.replacingOccurrences(of: "\"current_page\":1", with: "\"current_page\":0"),
                    receiptsResponse.replacingOccurrences(of: "\"per_page\":10", with: "\"per_page\":0"),
                    populatedResponse.replacingOccurrences(of: #""amount":"-63.14""#, with: #""amount":"63oops""#),
                    populatedResponse.replacingOccurrences(of: #""id":53"#, with: #""id":0"#),
                    populatedResponse.replacingOccurrences(of: #""date_text":"الأحد 15 نوفمبر 2026""#, with: #""date_text":" ""#),
                    savedResponse] {
            transport.respond(bad)
            await expect(.invalidResponse) { _ = try await service.receipts(token: "merchant-token") }
        }
        language = "en"
        transport.respond(savedResponse)
        let detail = try await service.details(id: "1", token: "merchant-token")
        precondition(detail.deservedAmount == 192 && detail.appPercentageAmount == 0 && detail.currency == "ريال")
        checkRequest(transport, path: "settlement-details/1", language: "en")

        // Preserve each server field without deriving a fixed commission or transferred amount.
        transport.respond(#"{"key":"success","data":{"deserved_amount":90071992547409.93,"marketer_percentage_amount":"1.23","marketer_percentage_from_loh":2.34,"app_percentage_type":"fixed","app_percentage":"0.125","app_percentage_amount":4.56,"currency":"SAR"}}"#)
        let exact = try await service.details(id: "1", token: "merchant-token")
        precondition(exact.deservedAmount == decimal("90071992547409.93"), "Money must not pass through Double")
        precondition(exact.marketerPercentageAmount == decimal("1.23") && exact.marketerPercentageFromLOH == decimal("2.34"))
        precondition(exact.appPercentage == decimal("0.125") && exact.appPercentageAmount == decimal("4.56"))
        precondition(exact.appPercentageType == "fixed" && exact.currency == "SAR")
        transport.respond(savedResponse.replacingOccurrences(of: "192.0", with: "-0.01"))
        let adjustment = try await service.details(id: "2", token: "merchant-token")
        precondition(adjustment.deservedAmount == decimal("-0.01"), "Do not silently clamp server amounts")

        let requestCount = transport.requests.count
        for id in ["", "../profile", "1/2", "1?x=2", "1#x", "%2F", " 1", "1\n", "١"] {
            await expect(.configuration) { _ = try await service.details(id: id, token: "merchant-token") }
        }
        await expect(.invalidResponse) { _ = try await service.receipts(token: "") }
        precondition(transport.requests.count == requestCount, "Invalid arguments must not reach the network")

        for malformed in [#"{"key":"success"}"#, #"{"key":"success","data":null}"#,
                          #"{"key":"success","data":[]}"#, #"{"key":"success","data":{}}"#,
                          "not JSON"] {
            transport.respond(malformed)
            await expect(.invalidResponse) { _ = try await service.receipts(token: "merchant-token") }
            await expect(.invalidResponse) { _ = try await service.details(id: "1", token: "merchant-token") }
        }
        for field in ["deserved_amount", "marketer_percentage_amount", "marketer_percentage_from_loh", "app_percentage", "app_percentage_amount"] {
            for invalid: Any in ["", "12oops", "12\n", "NaN", "1,20", "1e999", true, NSNull()] {
                var envelope = try JSONSerialization.jsonObject(with: Data(savedResponse.utf8)) as! [String: Any]
                var data = envelope["data"] as! [String: Any]
                data[field] = invalid
                envelope["data"] = data
                transport.response = .init(statusCode: 200, data: try JSONSerialization.data(withJSONObject: envelope))
                await expect(.invalidResponse) { _ = try await service.details(id: "1", token: "merchant-token") }
            }
        }
        transport.respond(savedResponse.replacingOccurrences(of: #""currency":"ريال""#, with: #""currency":" ""#))
        await expect(.invalidResponse) { _ = try await service.details(id: "1", token: "merchant-token") }

        transport.respond(#"{"key":"fail","msg":"Unavailable"}"#)
        await expect(.server(message: "Unavailable", fields: [:])) { _ = try await service.receipts(token: "merchant-token") }
        transport.respond(#"{"key":"fail","msg":"Not found"}"#, status: 404)
        await expect(.http(status: 404, message: "Not found")) { _ = try await service.details(id: "404", token: "merchant-token") }
        transport.respond(#"{"key":"unauthenticated","msg":"Expired"}"#)
        await expect(.unauthenticated("Expired")) { _ = try await service.receipts(token: "expired-receipts") }
        precondition(invalidated == "expired-receipts")
        transport.respond("", status: 401)
        await expect(.unauthenticated(nil)) { _ = try await service.details(id: "1", token: "expired-detail") }
        precondition(invalidated == "expired-detail")
        transport.failure = URLError(.notConnectedToInternet)
        await expect(.offline) { _ = try await service.receipts(token: "merchant-token") }
        transport.failure = URLError(.timedOut)
        await expect(.timeout) { _ = try await service.details(id: "1", token: "merchant-token") }
        for failure: Error in [CancellationError(), URLError(.cancelled)] {
            transport.failure = failure
            do { _ = try await service.receipts(token: "merchant-token"); preconditionFailure("Cancellation swallowed") }
            catch is CancellationError {}
            do { _ = try await service.details(id: "1", token: "merchant-token"); preconditionFailure("Cancellation swallowed") }
            catch is CancellationError {}
        }
        transport.respond(savedResponse)
        let beforeCancellation = transport.requests.count
        let cancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.receipts(token: "merchant-token")
        }
        do { _ = try await cancelled.value; preconditionFailure("Pre-cancelled request sent") }
        catch is CancellationError {}
        precondition(transport.requests.count == beforeCancellation)
        print("Passed: settlement routes, auth/language headers, receipt envelope/pagination, detail summaries, store loading/refresh/retry, stale/account isolation, decimal formatting, invalid input/responses, failures, and cancellation.")
    }

    @MainActor private static func storeChecks() async throws {
        struct Envelope: Decodable { let data: MerchantReceiptPage }
        let summary = try JSONDecoder().decode(Envelope.self, from: Data(receiptsResponse.utf8)).data
        let zero = try JSONDecoder().decode(Envelope.self, from: Data(receiptsResponse.replacingOccurrences(of: "\"per_page\":10", with: "\"per_page\":20").utf8)).data
        let service = SettlementServiceStub()
        var token: String? = "first"
        let store = MerchantSettlementStore(service: service, token: { token })
        precondition(store.previewReceipts.isEmpty && store.receiptPage == nil && !store.isLoading && store.error == nil)
        #if DEBUG
        let preview = MerchantSettlementStore.preview()
        await preview.reload()
        precondition(preview.previewReceipts.count == 6 && !preview.isLoading && preview.error == nil)
        #endif

        var continuation: CheckedContinuation<MerchantReceiptPage, Error>?
        service.action = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let initial = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        precondition(store.isLoading && store.receiptPage == nil && service.tokens == ["first"])
        continuation!.resume(returning: summary)
        await initial.value
        precondition(store.receiptPage == summary && !store.isLoading && store.error == nil)
        service.action = { throw URLError(.notConnectedToInternet) }
        await store.reload()
        precondition(store.receiptPage == summary && store.error == .offline && !store.isLoading, "A failed refresh keeps the last successful page")
        service.action = { zero }
        await store.reload()
        precondition(store.receiptPage == zero && store.error == nil, "Retry must update the receipt pagination")

        continuation = nil
        service.action = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let stale = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        service.action = { summary }
        await store.reload()
        continuation!.resume(returning: zero)
        await stale.value
        precondition(store.receiptPage == summary && store.error == nil && !store.isLoading)

        continuation = nil
        service.action = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let cancelled = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        cancelled.cancel()
        continuation!.resume(returning: zero)
        await cancelled.value
        precondition(store.receiptPage == summary && store.error == nil && !store.isLoading)

        token = "second"
        service.action = { throw APIError.timeout }
        await store.reload()
        precondition(store.receiptPage == nil && store.error == .timeout && service.tokens.last == "second")
        service.action = { summary }
        await store.reload()
        continuation = nil
        service.action = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let signedOut = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        token = nil
        continuation!.resume(returning: summary)
        await signedOut.value
        precondition(store.receiptPage == nil && store.error == nil && !store.isLoading)
        let requestsBeforeMissingToken = service.tokens.count
        await store.reload()
        precondition(service.tokens.count == requestsBeforeMissingToken && store.error == .unauthenticated(nil))

        token = "third"
        service.action = { summary }
        await store.reload()
        service.action = { throw APIError.unauthenticated(nil) }
        await store.reload()
        precondition(store.receiptPage == nil && store.error == .unauthenticated(nil))
        precondition(MerchantSettlementFormat.amount(decimal("192"), arabic: false) == "192.00")
        precondition(MerchantSettlementFormat.receiptAmount(decimal("-63.14"), arabic: false) == "-63.14")
        precondition(MerchantSettlementFormat.receiptAmount(decimal("1248"), arabic: false) == "1,248")
        precondition(MerchantSettlementFormat.amount(decimal("0.125"), arabic: false) == "0.125")
        precondition(MerchantSettlementFormat.amount(decimal("90071992547409.93"), arabic: false) == "90,071,992,547,409.93")
        precondition(MerchantSettlementFormat.amount(decimal("192"), arabic: true) != "192.00")
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }
    @MainActor private static func checkRequest(_ transport: SettlementTransport, path: String, language: String) {
        let request = transport.requests.last!
        precondition(request.url?.absoluteString == "https://upgrade.loh.com.sa/api/vendor/" + path)
        precondition(request.httpMethod == "GET" && request.httpBody == nil)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer merchant-token")
        precondition(request.value(forHTTPHeaderField: "lang") == language)
        precondition(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }
    @MainActor private static func expect(_ expected: APIError, operation: () async throws -> Void) async {
        do { try await operation(); preconditionFailure("Expected API failure") }
        catch { precondition(error as? APIError == expected, "Unexpected error: \(error)") }
    }
}

import Foundation

@MainActor
private final class OfferTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var action: (URLRequest) async throws -> HTTPResponse = { _ in throw APIError.invalidResponse }
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        return try await action(request)
    }
    func respond(_ data: String, status: Int = 200, key: String = "success") {
        action = { _ in .init(statusCode: status, data: Data("{\"key\":\"\(key)\",\"data\":\(data)}".utf8)) }
    }
}

@MainActor
private final class OfferServiceStub: MerchantOfferServicing {
    var calls: [(String, MerchantOfferSort, Int)] = []
    var action: (String, Int) async throws -> MerchantOfferPage = { _, _ in throw APIError.offline }
    var customerRows: [MerchantOfferOrder] = []
    var detail: MerchantOfferOrder?
    var detailOrderID: String?
    func offers(query: String, sort: MerchantOfferSort, page: Int, token: String) async throws -> MerchantOfferPage {
        calls.append((query, sort, page))
        return try await action(query, page)
    }
    func customers(couponID: String, token: String) async throws -> [MerchantOfferOrder] { customerRows }
    func couponDetails(couponID: String, token: String) async throws -> MerchantCouponDetails { throw APIError.invalidResponse }
    func couponSales(id: String, token: String) async throws -> MerchantCouponSale { throw APIError.invalidResponse }
    func deliverCoupon(printCode: String, token: String) async throws -> String? { throw APIError.invalidResponse }
    func orderDetails(orderID: String, token: String) async throws -> MerchantOfferOrder {
        detailOrderID = orderID
        guard let detail else { throw APIError.invalidResponse }
        return detail
    }
}

@main
struct MerchantOfferAPIChecks {
    // Synthetic examples follow the collection's shapes; no real customer details are stored here.
    private static let coupon = #"{"id":6,"name":"Test offer","purchase_times":"131","stay":71,"total_price":"384.0","loh_total_amount":"1.92","created_at":"2022-11-10","currency":"SAR"}"#
    private static let customers = #"[{"id":848,"name":"Test customer","phone":"0500000000","purchase_code":"0012345678","deliver_status":"تم التسليم","used_status":"2023-05-21 12:20:14"},{"id":"848","name":"Test customer","phone":null,"purchase_code":"0012345679","deliver_status":"Unknown state","used_status":null}]"#
    private static let vendorJSON = #"{"id":42,"name":"API Merchant","greeting":"أهلاً بك،","image":"https://example.invalid/vendor.png"}"#
    private static let statsJSON = #"{"total_offers":120,"active_offers":47,"sales_count":398,"sales_total":"1248.29","currency":"ريال"}"#

    @MainActor static func main() async throws {
        try money()
        try await contract()
        try await homeMetadata()
        await pagination()
        await refreshSnapshot()
        await refreshLifetime()
        await staleRequests()
        await details()
        print("Passed: offer request contract, vendor/stats decoding and state, exact amounts, pagination/retry/deduplication, refresh preservation and lifetime, stale search/page protection, cancellation, customer identity, detail matching, and live verification isolation.")
    }

    private static func pageJSON(page: Int = 1, pages: Int = 2, total: Int = 3, coupons: String = coupon,
                                 vendor: String = "null", stats: String = "null") -> String {
        """
        {"pagination":{"total_items":\(total),"total_pages":\(pages),"current_page":\(page),"next_page_url":"https://untrusted.example/api?page=2"},"coupons":[\(coupons)],"vendor":\(vendor),"stats":\(stats)}
        """
    }

    private static func money() throws {
        for (raw, expected) in [(#""0.29""#, 29), ("0.29", 29), (#""384.0""#, 38400), (#""1.2300""#, 123), ("0", 0)] {
            let decoded = try JSONDecoder().decode(MerchantAPIMoney.self, from: Data(raw.utf8))
            precondition(decoded.halalas == expected)
        }
        for raw in [#""1.001""#, #""-1""#, #""12 SAR""#, #""nan""#, #""999999999999999999999999999999""#, "null"] {
            do {
                _ = try JSONDecoder().decode(MerchantAPIMoney.self, from: Data(raw.utf8))
                preconditionFailure("Invalid monetary value was accepted")
            } catch {}
        }
        precondition(MerchantOfferFormat.money(29, arabic: false) == "SAR 0.29")
        precondition(MerchantOfferFormat.money(Int.max, arabic: false) == "SAR 92233720368547758.07")
        precondition(MerchantOfferFormat.money(nil, arabic: false) == "—")
        precondition(MerchantOfferFormat.parseDate("2022-02-31") == nil)
        precondition(MerchantOfferFormat.date(MerchantOfferFormat.parseDate("2022-11-10"), arabic: false) == "10 Nov 2022")
    }

    @MainActor private static func contract() async throws {
        let transport = OfferTransport()
        var expiredToken: String?
        let client = DefaultResponseHandler(transport: transport, language: { "ar" })
        client.onUnauthorized = { expiredToken = $0 }
        let service = MerchantOfferService(client: client)
        transport.respond(pageJSON())
        let page = try await service.offers(query: "  عرض & name=other  ", sort: .lowPrice, page: 1, token: "test-token")
        let request = transport.requests.last!
        precondition(request.url?.host == "upgrade.loh.com.sa" && request.url?.path == "/api/vendor/home-page")
        precondition(request.httpMethod == "GET" && request.httpBody == nil)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        precondition(request.value(forHTTPHeaderField: "lang") == "ar")
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(query.first { $0.name == "name" }?.value == "عرض & name=other")
        precondition(query.first { $0.name == "sort_by" }?.value == "low_price")
        precondition(query.first { $0.name == "page" }?.value == "1")
        precondition(page.hasMore && page.totalItems == 3)
        precondition(page.vendor == nil && page.stats == nil)
        precondition(page.offers.first?.salesHalalas == 38400, "total_price is already a total")
        precondition(page.offers.first?.lohHalalas == 192 && page.offers.first?.salesCount == 131)
        precondition(page.offers.first?.priceHalalas == nil && page.offers.first?.artwork == "")

        for rawImage in [#""https://example.invalid/offer.png""#, "null", #""file:///private/offer.png""#, #""""#] {
            let item = coupon.replacingOccurrences(of: #""id":6"#, with: #""image":\#(rawImage),"id":6"#)
            transport.respond(pageJSON(coupons: item))
            let result = try await service.offers(query: "", sort: .recent, page: 1, token: "test-token")
            precondition(result.offers.first?.image?.absoluteString == (rawImage.contains("https") ? "https://example.invalid/offer.png" : nil))
        }
        transport.respond(pageJSON())

        for sort in MerchantOfferSort.allCases {
            _ = try await service.offers(query: "", sort: sort, page: 1, token: "test-token")
            let query = URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)!.queryItems!
            precondition(query.first { $0.name == "sort_by" }?.value == sort.rawValue)
            precondition(!query.contains { $0.name == "name" })
        }
        transport.respond(pageJSON(page: 2))
        _ = try await service.offers(query: "", sort: .recent, page: 2, token: "test-token")
        precondition(transport.requests.last?.url?.host == "upgrade.loh.com.sa", "Untrusted pagination URLs are ignored")

        transport.respond(customers)
        let rows = try await service.customers(couponID: "195", token: "test-token")
        precondition(transport.requests.last?.url?.path == "/api/vendor/coupon-users/195")
        precondition(rows.count == 2 && rows[0].id != rows[1].id && rows[0].customerID == rows[1].customerID)
        precondition(rows[0].code == "0012345678" && rows[0].deliveryStatus == "تم التسليم")
        precondition(rows[0].purchasedAt == nil && rows[0].expiresAt == nil && rows[0].method == nil)
        precondition(rows[1].deliveryStatus == "Unknown state" && rows[1].phone == nil)
        let fixture = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantOrderDetails.json"))
        transport.action = { _ in .init(statusCode: 200, data: fixture) }
        let order = try await service.orderDetails(orderID: "916", token: "test-token")
        precondition(transport.requests.last?.url?.path == "/api/vendor/order-details/916")
        precondition(order.serverOrderID == "916" && order.offerID == "197" && order.customerID == "4743")
        let couponNumberOrder = try await service.orderDetails(orderID: "2010109700000916", token: "test-token")
        precondition(transport.requests.last?.url?.path == "/api/vendor/order-details/2010109700000916")
        precondition(couponNumberOrder.serverOrderID == "916" && couponNumberOrder.details?.couponNumber == "2010109700000916")
        let previousCount = transport.requests.count
        do {
            _ = try await service.customers(couponID: "../profile", token: "test-token")
            preconditionFailure("Unsafe ID accepted")
        } catch { precondition(error as? APIError == .configuration) }
        precondition(previousCount == transport.requests.count)

        transport.respond(pageJSON(page: 1, pages: 0, total: 0, coupons: ""))
        let empty = try await service.offers(query: "", sort: .recent, page: 1, token: "test-token")
        precondition(empty.offers.isEmpty && !empty.hasMore)
        for invalid in [#"{"pagination":{},"coupons":[]}"#, pageJSON(page: 3), pageJSON(pages: 0), pageJSON(total: 0, coupons: ""), pageJSON(coupons: coupon.replacingOccurrences(of: "384.0", with: "1.001"))] {
            transport.respond(invalid)
            do {
                _ = try await service.offers(query: "", sort: .recent, page: 1, token: "test-token")
                preconditionFailure("Malformed response accepted")
            } catch { precondition(error as? APIError == .invalidResponse) }
        }
        transport.respond("null", key: "unauthenticated")
        do {
            _ = try await service.offers(query: "", sort: .recent, page: 1, token: "expired-token")
            preconditionFailure("Unauthenticated success")
        } catch { precondition((error as? APIError)?.invalidatesSession == true) }
        precondition(expiredToken == "expired-token")
    }

    private static func offer(_ id: String, sales: Int = 100) -> MerchantOffer {
        .init(id: id, nameAr: "عرض", nameEn: "Offer", salesCount: 2, lohHalalas: 10, salesHalalas: sales, createdAt: nil)
    }

    @MainActor private static func homeMetadata() async throws {
        let transport = OfferTransport()
        let client = DefaultResponseHandler(transport: transport, language: { "ar" }, logger: .init(output: { _ in }))
        let service = MerchantOfferService(client: client)
        let store = MerchantOfferStore(service: service, token: { "test-token" })
        precondition(store.vendor == nil && store.stats == nil)
        transport.respond(pageJSON(vendor: vendorJSON, stats: statsJSON))
        await store.reload(query: "one match", sort: .recent)
        precondition(store.error == nil && store.vendor?.id == "42" && store.vendor?.name == "API Merchant")
        precondition(store.vendor?.greeting == "أهلاً بك،" && store.vendor?.image?.absoluteString == "https://example.invalid/vendor.png")
        precondition(store.stats?.totalOffers == 120 && store.stats?.activeOffers == 47)
        precondition(store.stats?.salesCount == 398 && store.stats?.salesHalalas == 124829 && store.stats?.currency == "ريال")
        precondition(store.totalItems == 3 && store.offers.count == 1, "Account stats must stay independent of filtered/paginated coupons")
        let firstVendor = store.vendor
        let firstStats = store.stats
        transport.respond(pageJSON(page: 2).replacingOccurrences(of: #","vendor":null,"stats":null"#, with: ""))
        await store.loadMore()
        precondition(store.vendor == firstVendor && store.stats == firstStats, "Pages without metadata must retain the first-page snapshot")

        // The supplied live empty-home shape still carries the vendor and all four zero stats.
        let zeroStats = #"{"total_offers":0,"active_offers":0,"sales_count":0,"sales_total":"0.00","currency":"ريال"}"#
        transport.respond(pageJSON(pages: 1, total: 0, coupons: "", vendor: vendorJSON, stats: zeroStats))
        await store.reload(query: "", sort: .recent)
        precondition(store.error == nil && store.offers.isEmpty && store.vendor == firstVendor)
        precondition(store.stats == .init(totalOffers: 0, activeOffers: 0, salesCount: 0, salesHalalas: 0, currency: "ريال"))

        // Numeric/string counts and numeric money retain exact values; an unavailable image has a UI fallback.
        let noImage = #"{"id":"42","name":"API Merchant","greeting":null,"image":null}"#
        let numericStats = #"{"total_offers":"120","active_offers":"47","sales_count":"398","sales_total":0.29,"currency":"SAR"}"#
        transport.respond(pageJSON(vendor: noImage, stats: numericStats))
        let numeric = try await service.offers(query: "", sort: .recent, page: 1, token: "test-token")
        precondition(numeric.stats?.salesHalalas == 29 && numeric.stats?.totalOffers == 120 && numeric.stats?.currency == "SAR")
        precondition(numeric.vendor?.id == "42" && numeric.vendor?.image == nil && numeric.vendor?.greeting == nil)
        for image in ["", "not-a-url", "file:///tmp/private.png"] {
            transport.respond(pageJSON(vendor: vendorJSON.replacingOccurrences(of: "https://example.invalid/vendor.png", with: image), stats: statsJSON))
            let page = try await service.offers(query: "", sort: .recent, page: 1, token: "test-token")
            precondition(page.vendor?.image == nil && page.vendor?.name == "API Merchant")
        }
        for malformed in [statsJSON.replacingOccurrences(of: "1248.29", with: "1.001"),
                          statsJSON.replacingOccurrences(of: #""total_offers":120"#, with: #""total_offers":-1"#),
                          statsJSON.replacingOccurrences(of: #""active_offers":47"#, with: #""active_offers":2.5"#),
                          statsJSON.replacingOccurrences(of: #""sales_count":398"#, with: #""sales_count":null"#),
                          "{}"] {
            transport.respond(pageJSON(vendor: vendorJSON, stats: malformed))
            do {
                _ = try await service.offers(query: "", sort: .recent, page: 1, token: "test-token")
                preconditionFailure("Malformed stats accepted")
            } catch { precondition(error as? APIError == .invalidResponse) }
        }
        transport.respond(pageJSON().replacingOccurrences(of: #","vendor":null,"stats":null"#, with: ""))
        await store.reload(query: "legacy", sort: .recent)
        precondition(store.error == nil && store.vendor == nil && store.stats == nil, "An older first-page response must not retain old metadata")
    }

    private static func vendor(_ name: String) -> MerchantOfferVendor {
        .init(id: name, name: name, greeting: nil, image: nil)
    }
    private static func stats(_ count: Int) -> MerchantOfferStatistics {
        .init(totalOffers: count, activeOffers: count, salesCount: count, salesHalalas: count * 100, currency: "SAR")
    }

    @MainActor private static func pagination() async {
        let service = OfferServiceStub()
        let store = MerchantOfferStore(service: service, token: { "token" })
        precondition(store.offers.isEmpty && store.orders.isEmpty && !store.allowsLocalVerification)
        precondition(!store.verify("123456", method: .code) && !store.deliver("order-1"))
        service.action = { _, _ in .init(offers: [offer("1")], totalItems: 3, currentPage: 1, totalPages: 2) }
        await store.reload(query: "  offer  ", sort: .lowPrice)
        precondition(store.totalItems == 3 && store.offers.count == 1 && store.hasMore && !store.isLoading)
        precondition(service.calls.last?.0 == "offer" && service.calls.last?.1 == .lowPrice)
        service.action = { _, _ in throw URLError(.notConnectedToInternet) }
        await store.loadMore()
        precondition(store.pageError == .offline && store.offers.count == 1 && store.hasMore)

        var continuation: CheckedContinuation<MerchantOfferPage, Error>?
        service.action = { _, _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let first = Task { await store.loadMore() }
        while continuation == nil { await Task.yield() }
        let callCount = service.calls.count
        await store.loadMore()
        precondition(service.calls.count == callCount && store.isLoadingMore)
        continuation!.resume(returning: .init(offers: [offer("1", sales: 200), offer("2"), offer("2"), offer("3")], totalItems: 3, currentPage: 2, totalPages: 2))
        await first.value
        precondition(store.offers.map(\.id) == ["1", "2", "3"] && store.offers[0].salesHalalas == 200)
        precondition(!store.hasMore && !store.isLoadingMore && store.pageError == nil && service.calls.last?.2 == 2)
        service.action = { _, _ in .init(offers: [], totalItems: 0, currentPage: 1, totalPages: 0) }
        await store.reload(query: "absent", sort: .recent)
        precondition(store.offers.isEmpty && store.totalItems == 0 && store.error == nil)
        precondition(store.offer("1") != nil, "Navigation retains selected offers when the list reloads")
        service.action = { _, _ in throw APIError.timeout }
        await store.reload(query: "", sort: .recent)
        precondition(store.error == .timeout && !store.isLoading)
    }

    @MainActor private static func refreshSnapshot() async {
        let service = OfferServiceStub()
        let store = MerchantOfferStore(service: service, token: { "token" })
        service.action = { _, page in
            .init(offers: [offer(String(page))], totalItems: 3, currentPage: page, totalPages: 3,
                  vendor: vendor("loaded"), stats: stats(3))
        }
        await store.reload(query: "", sort: .recent)
        await store.loadMore()
        precondition(store.offers.map(\.id) == ["1", "2"] && store.hasMore)

        var continuation: CheckedContinuation<MerchantOfferPage, Error>?
        service.action = { _, _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let refresh = Task { await store.refresh(query: "  ", sort: .recent) }
        while continuation == nil { await Task.yield() }
        precondition(store.isLoading && store.offers.map(\.id) == ["1", "2"])
        precondition(store.vendor == vendor("loaded") && store.stats == stats(3) && store.totalItems == 3 && store.hasMore)
        let callCount = service.calls.count
        await store.loadMore()
        precondition(service.calls.count == callCount, "Pagination waits for the refresh")
        continuation!.resume(throwing: URLError(.notConnectedToInternet))
        await refresh.value
        precondition(store.error == .offline && !store.isLoading && store.hasMore)
        precondition(store.offers.map(\.id) == ["1", "2"] && store.vendor == vendor("loaded") && store.stats == stats(3))

        for cancellation: Error in [CancellationError(), URLError(.cancelled)] {
            service.action = { _, _ in throw cancellation }
            await store.reload(query: "", sort: .recent)
            precondition(store.error == nil && !store.isLoading && store.hasMore)
            precondition(store.offers.map(\.id) == ["1", "2"] && store.totalItems == 3)
            precondition(store.vendor == vendor("loaded") && store.stats == stats(3))
        }
        service.action = { _, page in
            precondition(page == 3, "A failed or cancelled refresh preserves the last loaded page")
            return .init(offers: [offer("3")], totalItems: 3, currentPage: page, totalPages: 3)
        }
        await store.loadMore()
        precondition(store.offers.map(\.id) == ["1", "2", "3"] && !store.hasMore)

        service.action = { _, page in
            precondition(page == 1)
            return .init(offers: [offer("new")], totalItems: 2, currentPage: 1, totalPages: 2,
                         vendor: vendor("updated"), stats: stats(2))
        }
        await store.refresh(query: "", sort: .recent)
        precondition(store.offers.map(\.id) == ["new"] && store.hasMore && store.totalItems == 2)
        precondition(store.vendor == vendor("updated") && store.stats == stats(2))
        service.action = { _, page in
            precondition(page == 2, "A successful refresh restarts pagination from page one")
            return .init(offers: [offer("next")], totalItems: 2, currentPage: 2, totalPages: 2)
        }
        await store.loadMore()
        precondition(store.offers.map(\.id) == ["new", "next"])

        service.action = { _, _ in
            .init(offers: [], totalItems: 0, currentPage: 1, totalPages: 1, vendor: vendor("updated"), stats: stats(0))
        }
        await store.refresh(query: "", sort: .recent)
        precondition(store.offers.isEmpty && store.totalItems == 0 && !store.hasMore && store.error == nil)
        precondition(store.vendor == vendor("updated") && store.stats == stats(0), "A successful empty response replaces the snapshot")
    }

    @MainActor private static func refreshLifetime() async {
        let service = OfferServiceStub()
        var token: String? = "token"
        let store = MerchantOfferStore(service: service, token: { token })
        service.action = { _, _ in
            .init(offers: [offer("loaded")], totalItems: 1, currentPage: 1, totalPages: 1,
                  vendor: vendor("loaded"), stats: stats(1))
        }
        await store.reload(query: "", sort: .recent)

        var continuation: CheckedContinuation<MerchantOfferPage, Error>?
        service.action = { _, _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let pull = Task { await store.refresh(query: "", sort: .recent) }
        while continuation == nil { await Task.yield() }
        pull.cancel()
        continuation!.resume(returning: .init(offers: [offer("fresh")], totalItems: 1, currentPage: 1, totalPages: 1))
        await pull.value
        precondition(store.offers.map(\.id) == ["fresh"] && !store.isLoading && store.error == nil,
                     "The pull gesture's task ending must not cancel the owned request")

        continuation = nil
        let leaving = Task { await store.refresh(query: "", sort: .recent) }
        while continuation == nil { await Task.yield() }
        store.cancelRefresh()
        continuation!.resume(returning: .init(offers: [offer("cancelled")], totalItems: 1, currentPage: 1, totalPages: 1))
        await leaving.value
        precondition(store.offers.map(\.id) == ["fresh"] && store.error == nil && !store.isLoading,
                     "Leaving the screen cancels the request without discarding loaded data")

        continuation = nil
        let superseded = Task { await store.refresh(query: "", sort: .recent) }
        while continuation == nil { await Task.yield() }
        service.action = { query, _ in
            .init(offers: [offer(query)], totalItems: 1, currentPage: 1, totalPages: 1)
        }
        await store.reload(query: "new-filter", sort: .oldest)
        continuation!.resume(returning: .init(offers: [offer("stale")], totalItems: 1, currentPage: 1, totalPages: 1))
        await superseded.value
        precondition(store.offers.map(\.id) == ["new-filter"] && !store.isLoading)

        continuation = nil
        service.action = { _, _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let logout = Task { await store.refresh(query: "new-filter", sort: .oldest) }
        while continuation == nil { await Task.yield() }
        token = nil
        continuation!.resume(throwing: APIError.offline)
        await logout.value
        precondition(store.offers.isEmpty && store.offer("fresh") == nil && store.totalItems == nil && !store.hasMore)
        precondition(store.vendor == nil && store.stats == nil && store.error == nil && !store.isLoading,
                     "An account change clears retained data even when its refresh fails")
    }

    @MainActor private static func staleRequests() async {
        let service = OfferServiceStub()
        var token: String? = "first-session"
        let store = MerchantOfferStore(service: service, token: { token })
        var continuation: CheckedContinuation<MerchantOfferPage, Error>?
        service.action = { _, _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let oldSearch = Task { await store.reload(query: "old", sort: .recent) }
        while continuation == nil { await Task.yield() }
        service.action = { _, _ in .init(offers: [offer("new")], totalItems: 2, currentPage: 1, totalPages: 2, vendor: vendor("new"), stats: stats(20)) }
        await store.reload(query: "new", sort: .recent)
        continuation!.resume(returning: .init(offers: [offer("old")], totalItems: 1, currentPage: 1, totalPages: 1, vendor: vendor("old"), stats: stats(10)))
        await oldSearch.value
        precondition(store.offers.map(\.id) == ["new"] && store.hasMore)
        precondition(store.vendor == vendor("new") && store.stats == stats(20))

        continuation = nil
        service.action = { _, _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let oldPage = Task { await store.loadMore() }
        while continuation == nil { await Task.yield() }
        service.action = { _, _ in .init(offers: [offer("latest")], totalItems: 1, currentPage: 1, totalPages: 1, vendor: vendor("latest"), stats: stats(30)) }
        await store.reload(query: "latest", sort: .oldest)
        continuation!.resume(returning: .init(offers: [offer("old-page")], totalItems: 2, currentPage: 2, totalPages: 2, vendor: vendor("old-page"), stats: stats(40)))
        await oldPage.value
        precondition(store.offers.map(\.id) == ["latest"] && !store.hasMore)
        precondition(store.vendor == vendor("latest") && store.stats == stats(30))

        continuation = nil
        service.action = { _, _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let cancelled = Task { await store.reload(query: "cancel", sort: .recent) }
        while continuation == nil { await Task.yield() }
        cancelled.cancel()
        continuation!.resume(returning: .init(offers: [offer("cancelled")], totalItems: 1, currentPage: 1, totalPages: 1, vendor: vendor("cancelled"), stats: stats(50)))
        await cancelled.value
        precondition(store.offers.isEmpty && store.error == nil && !store.isLoading)
        precondition(store.vendor == nil && store.stats == nil)

        continuation = nil
        let staleSession = Task { await store.reload(query: "session", sort: .recent) }
        while continuation == nil { await Task.yield() }
        token = nil
        continuation!.resume(returning: .init(offers: [offer("private")], totalItems: 1, currentPage: 1, totalPages: 1, vendor: vendor("private"), stats: stats(60)))
        await staleSession.value
        precondition(store.offers.isEmpty)
        precondition(store.vendor == nil && store.stats == nil)
    }

    @MainActor private static func details() async {
        let service = OfferServiceStub()
        let store = MerchantOfferStore(service: service, token: { "token" })
        let selected = MerchantOfferOrder(id: "195:0012345678", offerID: "195", code: "0012345678", customerAr: "عميل", customerEn: "Customer", customerID: "848", serverOrderID: "910")
        service.customerRows = [selected, selected]
        await store.loadCustomers(offerID: "195")
        precondition(store.orders.count == 1 && !store.loadingCustomers.contains("195"))
        var updated = selected
        updated.deliveryStatus = "Delivered"
        service.detail = updated
        await store.loadOrder(id: selected.id)
        precondition(service.detailOrderID == "910", "Lookup uses the server order ID")
        precondition(store.order(selected.id)?.deliveryStatus == "Delivered" && store.orderErrors[selected.id] == nil)
        precondition(!store.verify(selected.code, method: .barcode) && !store.deliver(selected.id))
        service.detail = nil
        await store.loadOrder(id: selected.id)
        precondition(store.orderErrors[selected.id] == .invalidResponse)
        precondition(store.order(selected.id)?.deliveryStatus == "Delivered", "A failed refresh preserves the last known purchase")

        let unresolvedService = OfferServiceStub()
        let unresolvedStore = MerchantOfferStore(service: unresolvedService, token: { "token" })
        var unresolved = selected
        unresolved.serverOrderID = nil
        unresolvedService.customerRows = [unresolved]
        await unresolvedStore.loadCustomers(offerID: "195")
        await unresolvedStore.loadOrder(id: selected.id)
        precondition(unresolvedService.detailOrderID == nil && unresolvedStore.orderErrors[selected.id] == .invalidResponse,
                     "A missing order ID must not fall back to a coupon, customer, or purchase code")
        unresolvedStore.beginVerification(for: selected.id)
        let verified = await unresolvedStore.verifyPurchase(selected.code, method: .code)
        precondition(!verified && unresolvedService.detailOrderID == nil && unresolvedStore.verificationAPIError == .invalidResponse)
    }
}

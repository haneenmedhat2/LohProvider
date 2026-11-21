import Foundation

@MainActor private final class FulfillmentTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var action: (URLRequest) async throws -> HTTPResponse = { _ in throw APIError.invalidResponse }
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        return try await action(request)
    }
    func respond(_ data: String) { action = { _ in Self.success(data) } }
    static func success(_ data: String) -> HTTPResponse {
        .init(statusCode: 200, data: Data("{\"key\":\"success\",\"data\":\(data)}".utf8))
    }
    static var delivered: HTTPResponse {
        .init(statusCode: 200, data: Data(#"{"key":"success","msg":"Delivery confirmed"}"#.utf8))
    }
}

@main struct MerchantCouponFulfillmentChecks {
    // Synthetic customer/code values with the exact collection shapes.
    static let code = "0012345678"
    static let orderID = "195:" + code
    static let serverOrderID = "910"
    static let customer = #"{"id":848,"name":"Test customer","phone":"0500000000","purchase_code":"0012345678","deliver_status":"Pending","used_status":null}"#
    static var rows: String { "[" + customer + "]" }
    static var recentOrder: String {
        #"{"id":910,"print_code":"0012345678","customer_name":"Test customer","coupon_name":"Test offer","status":"pending","status_text":"Pending"}"#
    }
    static var detail: String {
        #"{"coupon":{"id":195,"name":"Test offer","image":null,"price":"1.00","currency":"SAR","status":"active","status_text":"Active","published_at":"2026-10-25","published_at_text":"25 October 2026","updated_at":"2026-10-25","updated_at_text":"Last updated: 25 October 2026"},"orders":[\#(recentOrder)],"pagination":{"total_items":1,"count_items":1,"per_page":3,"current_page":1,"total_pages":1}}"#
    }
    static var sale: String {
        #"{"id":848,"qty":3,"purchase_code":"0012345678","price":"192.29","loh_amount":"1.92","currency":"ريال","user_details":\#(customer)}"#
    }
    // The live order-details shape, with synthetic customer name/phone and configurable identities.
    static func orderResponse(couponID: Int = 195, orderID: Int = 910, code: String = code,
                              customerID: Int = 848, status: String = "ready") -> String {
        let fixture = try! Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantOrderDetails.json"))
        var data = (try! JSONSerialization.jsonObject(with: fixture) as! [String: Any])["data"] as! [String: Any]
        var coupon = data["coupon"] as! [String: Any], customer = data["customer"] as! [String: Any]
        coupon["id"] = couponID; customer["id"] = customerID
        data["id"] = orderID; data["purchase_code"] = code; data["coupon"] = coupon; data["customer"] = customer
        data["status"] = status; data["status_text"] = status == "delivered" ? "تم التسليم" : "مفعل"
        return String(data: try! JSONSerialization.data(withJSONObject: data), encoding: .utf8)!
    }
    @MainActor private static func makeService(_ transport: FulfillmentTransport) -> MerchantOfferService {
        .init(client: .init(transport: transport, language: { "ar" }, logger: .init(output: { _ in })))
    }
    @MainActor static func main() async throws {
        try await contract()
        try await orderDetailsResponse()
        await readyAndUsedStates()
        await notificationOfferDetails()
        try await liveCouponDetails()
        try await populatedCouponDetails()
        try await couponDetailsRefresh()
        await deliveryFlow()
        await identityAndFailures()
        await cancellationAndAccounts()
        print("Passed: coupon/detail/sales contracts, full returned order lists, detail refresh lifetime and ordering, malformed/empty response retention, exact amounts, selected-purchase verification, confirmed delivery, duplicate suppression, failure re-verification, identity guards, cancellation, and account isolation.")
    }
    @MainActor static func notificationOfferDetails() async {
        let transport = FulfillmentTransport()
        let store = MerchantOfferStore(service: makeService(transport), token: { "test-token" })
        precondition(store.offer("195") == nil && store.offers.isEmpty)
        transport.respond(detail)
        await store.loadCouponDetails(offerID: "195")
        precondition(store.offers.isEmpty && store.offer("195")?.id == "195",
                     "A notification can open a coupon outside the currently loaded home page")
        precondition(store.offer("195")?.nameAr == store.couponDetails["195"]?.coupon.name)
        precondition(store.orders(for: "195").count == store.couponDetails["195"]?.orders.count)
    }
    @MainActor static func contract() async throws {
        let transport = FulfillmentTransport(), service = makeService(transport)
        transport.respond(detail)
        let details = try await service.couponDetails(couponID: "195", token: "test-token")
        precondition(details.orders.first?.id == orderID && details.orders.first?.code == code)
        precondition(transport.requests.last?.url?.path == "/api/vendor/coupon-details/195")
        transport.respond(rows)
        _ = try await service.customers(couponID: "195", token: "test-token")
        precondition(transport.requests.last?.url?.path == "/api/vendor/coupon-users/195")
        transport.respond(orderResponse())
        let refreshed = try await service.orderDetails(orderID: serverOrderID, token: "test-token")
        precondition(transport.requests.last?.url?.path == "/api/vendor/order-details/910")
        precondition(refreshed.id == orderID && refreshed.offerID == "195",
                     "The order ID in the URL must not replace the local coupon/purchase identity")
        for request in transport.requests {
            precondition(request.httpMethod == "GET" && request.httpBody == nil && request.url?.query == nil)
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            precondition(request.value(forHTTPHeaderField: "lang") == "ar")
        }
        transport.respond(sale)
        let value = try await service.couponSales(id: "693", token: "test-token")
        precondition(transport.requests.last?.url?.path == "/api/vendor/coupon-sales/693")
        precondition(value.quantity == 3 && value.priceHalalas == 19229 && value.lohHalalas == 192 && value.currency == "ريال")
        precondition(value.customerID == "848" && value.purchaseCode == code && value.usedStatus == nil)
        for malformed in [sale.replacingOccurrences(of: "192.29", with: "1.001"),
                          sale.replacingOccurrences(of: #""qty":3"#, with: #""qty":-1"#),
                          sale.replacingOccurrences(of: #""qty":3"#, with: #""qty":1.5"#),
                          sale.replacingOccurrences(of: #""price":"192.29""#, with: #""price":null"#),
                          sale.replacingOccurrences(of: #""user_details":\#(customer)"#, with: #""user_details":\#(customer.replacingOccurrences(of: code, with: "999"))"#)] {
            transport.respond(malformed)
            do { _ = try await service.couponSales(id: "693", token: "test-token"); preconditionFailure("Malformed sale accepted") }
            catch { precondition(error as? APIError == .invalidResponse) }
        }
        transport.action = { _ in FulfillmentTransport.delivered }
        let message = try await service.deliverCoupon(printCode: code, token: "test-token")
        let request = transport.requests.last!
        precondition(message == "Delivery confirmed")
        precondition(request.httpMethod == "POST" && request.httpBody == nil)
        precondition(request.url?.path == "/api/vendor/deliver-coupon/0012345678" && request.url?.query == "_method=put")
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        precondition(request.value(forHTTPHeaderField: "lang") == "ar")
        let count = transport.requests.count
        for invalid in ["", "../profile", "١٢٣", "12/3", " 123", "123?"] {
            do { _ = try await service.deliverCoupon(printCode: invalid, token: "test-token"); preconditionFailure("Invalid code accepted") }
            catch { precondition(error as? APIError == .configuration) }
            do { _ = try await service.couponSales(id: invalid, token: "test-token"); preconditionFailure("Invalid ID accepted") }
            catch { precondition(error as? APIError == .configuration) }
            do { _ = try await service.orderDetails(orderID: invalid, token: "test-token"); preconditionFailure("Invalid order ID accepted") }
            catch { precondition(error as? APIError == .configuration) }
        }
        precondition(transport.requests.count == count)
        transport.action = { _ in .init(statusCode: 200, data: Data(#"{"key":"fail","msg":"Already delivered"}"#.utf8)) }
        do { _ = try await service.deliverCoupon(printCode: code, token: "test-token"); preconditionFailure("Failed delivery reported success") }
        catch { precondition(error as? APIError != nil) }
    }
    @MainActor static func orderDetailsResponse() async throws {
        let fixture = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantOrderDetails.json"))
        let original = (try JSONSerialization.jsonObject(with: fixture) as! [String: Any])["data"] as! [String: Any]
        func json(_ value: Any) throws -> String {
            String(data: try JSONSerialization.data(withJSONObject: value), encoding: .utf8)!
        }
        let transport = FulfillmentTransport(), service = makeService(transport)
        transport.respond(try json(original))
        let order = try await service.orderDetails(orderID: "916", token: "test-token")
        precondition(order.serverOrderID == "916" && order.offerID == "197" && order.customerID == "4743")
        precondition(order.id == "197:20261027916" && order.code == "20261027916")
        precondition(order.customerAr == "Test customer" && order.customerEn == "Test customer" && order.phone == "0500000000")
        precondition(order.couponName == "Test Offer" && order.deliveryStatus == "ready" && order.statusText == "مفعل" && !order.isDelivered)
        let details = order.details!
        precondition(details.couponNumber == "2010109700000916" && details.priceHalalas == 100 && details.currency == "ريال")
        precondition(details.couponImage?.absoluteString == "https://upgrade.loh.com.sa/storage/images/coupons/1792915133_3973.png")
        precondition(order.purchasedAt == MerchantOfferFormat.parseDate("2026-10-27 16:02:57") && order.purchasedAt == details.purchasedAt.date)
        precondition(order.expiresAt == MerchantOfferFormat.parseDate("2026-12-26 16:02:57") && order.expiresAt == details.validUntil.date)
        precondition(details.purchasedAt.dateText == "27 أكتوبر 2026" && details.purchasedAt.timeText == "04:02 م")
        precondition(details.validUntil.dateText == "26 ديسمبر 2026" && details.validUntil.timeText == "04:02 م")
        precondition(!details.verification.isVerified && details.verification.method == nil && details.verification.verifiedAt == nil)
        precondition(details.verification.methodText == "لم يتم التحقق بعد" && order.method == nil)

        var verified = original, customer = original["customer"] as! [String: Any]
        customer["is_verified"] = true; customer["verification_method"] = "barcode"
        customer["verification_method_text"] = "مسح الباركود"; customer["verified_at"] = "2026-10-28 10:00:00"
        customer["phone"] = NSNull(); verified["customer"] = customer
        verified["id"] = "916"; verified["purchase_code"] = "000123"; verified["coupon_number"] = "000456"
        transport.respond(try json(verified))
        let checked = try await service.orderDetails(orderID: "916", token: "test-token")
        precondition(checked.phone == nil && checked.code == "000123" && checked.details?.couponNumber == "000456")
        precondition(checked.details?.verification.isVerified == true && checked.details?.verification.method == "barcode")
        precondition(checked.details?.verification.methodText == "مسح الباركود")
        precondition(checked.details?.verification.verifiedAt == MerchantOfferFormat.parseDate("2026-10-28 10:00:00"))
        precondition(!checked.isDelivered && checked.method == nil, "Server verification metadata must not manufacture a local verification or delivery")

        for value in [NSNull(), "", "file:///private/image.png", "invalid"] as [Any] {
            var data = original, coupon = original["coupon"] as! [String: Any]
            coupon["image"] = value; data["coupon"] = coupon
            transport.respond(try json(data))
            let result = try await service.orderDetails(orderID: "916", token: "test-token")
            precondition(result.details?.couponImage == nil)
        }
        var malformed: [Any] = [[:], [], original.merging(["id": 917]) { _, new in new },
                               original.merging(["price": "1.001"]) { _, new in new },
                               original.merging(["purchase_code": "../916"]) { _, new in new }]
        for field in ["customer", "coupon", "purchased_at", "valid_until"] {
            var data = original; data[field] = NSNull(); malformed.append(data)
        }
        for field in ["purchased_at", "valid_until"] {
            var data = original, date = original[field] as! [String: Any]
            date["datetime"] = "2026-02-31 16:02:57"; data[field] = date; malformed.append(data)
        }
        for body in malformed {
            transport.respond(try json(body))
            do { _ = try await service.orderDetails(orderID: "916", token: "test-token"); preconditionFailure("Invalid order detail accepted") }
            catch { precondition(error as? APIError == .invalidResponse) }
        }

        // Match both the route order ID and the selected purchase/coupon/customer before updating state.
        let store = MerchantOfferStore(service: service, token: { "token" })
        transport.respond(detail)
        await store.loadCouponDetails(offerID: "195")
        transport.respond(orderResponse())
        await store.loadOrder(id: orderID)
        precondition(store.orderErrors[orderID] == nil && store.order(orderID)?.details?.priceHalalas == 100)
        precondition(store.order(orderID)?.serverOrderID == "910" && store.order(orderID)?.customerID == "848")
        precondition(store.verifiedOrderID == nil && store.sales.isEmpty)
        for body in [orderResponse(orderID: 911), orderResponse(couponID: 196),
                     orderResponse(code: "999"), orderResponse(customerID: 849), "{}", "[]"] {
            transport.respond(body)
            await store.loadOrder(id: orderID)
            precondition(store.orderErrors[orderID] == .invalidResponse && store.loadingOrders.isEmpty)
            precondition(store.order(orderID)?.details?.priceHalalas == 100 && store.order(orderID)?.customerID == "848")
            store.beginVerification(for: orderID)
            let verified = await store.verifyPurchase(code, method: .code)
            precondition(!verified && store.verifiedOrderID == nil && store.verificationAPIError == .invalidResponse)
        }
    }

    @MainActor static func readyAndUsedStates() async {
        let transport = FulfillmentTransport(), service = makeService(transport)
        let store = MerchantOfferStore(service: service, token: { "token" })
        transport.respond(detail)
        await store.loadCouponDetails(offerID: "195")
        precondition(!store.canConfirmDelivery(id: orderID), "The order-list preview does not authorize delivery")
        transport.respond(orderResponse())
        await store.loadOrder(id: orderID)
        let offer = MerchantOffer(id: "195", nameAr: "Test offer", nameEn: "Test offer", salesCount: 1,
                                  lohHalalas: 0, salesHalalas: 100, createdAt: nil)
        let ready = MerchantOrderPresentation(order: store.order(orderID)!, offer: offer, coupon: store.couponDetails["195"]?.coupon)
        precondition(ready.showsReady && ready.showsResult && !ready.isComplete)
        precondition(ready.statusText == "Active" && ready.method == nil)
        precondition(ready.verificationText { $0 } == "لم يتم التحقق بعد", "An unverified response must not claim a barcode scan")
        precondition(store.canConfirmDelivery(id: orderID) && store.verifiedOrderID == nil,
                     "The explicit ready status allows the user to confirm without another code-entry step")
        var scanned = ready.order
        scanned.method = .barcode
        let barcode = MerchantOrderPresentation(order: scanned, offer: offer, coupon: nil)
        precondition(barcode.verificationText { $0 } == "nav_scan_barcode")
        precondition(barcode.verificationText(customerRow: true) { $0 } == "offers_verified_barcode")

        transport.action = { _ in throw URLError(.timedOut) }
        let failed = await store.confirmDelivery(id: orderID)
        precondition(!failed && !store.canConfirmDelivery(id: orderID))
        let failedCount = transport.requests.count
        let retry = await store.confirmDelivery(id: orderID)
        precondition(!retry && transport.requests.count == failedCount, "An uncertain delivery needs a fresh read before retry")
        transport.respond(orderResponse())
        await store.loadOrder(id: orderID)
        precondition(store.deliveryErrors[orderID] == nil && store.canConfirmDelivery(id: orderID))

        var pending: CheckedContinuation<HTTPResponse, Error>?
        transport.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let delivery = Task { await store.confirmDelivery(id: orderID) }
        while pending == nil { await Task.yield() }
        precondition(!store.canConfirmDelivery(id: orderID) && store.deliveringOrders.contains(orderID))
        let request = transport.requests.last!
        precondition(request.httpMethod == "POST" && request.url?.path == "/api/vendor/deliver-coupon/0012345678"
                     && request.url?.query == "_method=put" && request.httpBody == nil)
        let count = transport.requests.count
        let duplicate = await store.confirmDelivery(id: orderID)
        precondition(!duplicate && transport.requests.count == count)
        pending!.resume(returning: FulfillmentTransport.delivered)
        let success = await delivery.value
        precondition(success && !store.canConfirmDelivery(id: orderID))
        let complete = MerchantOrderPresentation(order: store.order(orderID)!, offer: offer, coupon: nil)
        precondition(complete.isComplete && complete.showsResult && !complete.showsReady)

        let usedStore = MerchantOfferStore(service: service, token: { "token" })
        transport.respond(detail)
        await usedStore.loadCouponDetails(offerID: "195")
        transport.respond(orderResponse(status: "used"))
        await usedStore.loadOrder(id: orderID)
        let used = MerchantOrderPresentation(order: usedStore.order(orderID)!, offer: offer, coupon: nil)
        precondition(used.isComplete && !used.showsReady && used.showsResult)
        precondition(!usedStore.canConfirmDelivery(id: orderID))
        let before = transport.requests.count
        let redelivery = await usedStore.confirmDelivery(id: orderID)
        precondition(!redelivery && transport.requests.count == before)
        usedStore.beginVerification(for: orderID)
        let verification = await usedStore.verifyPurchase(code, method: .code)
        precondition(!verification && usedStore.verificationError == .delivered)
    }

    @MainActor static func liveCouponDetails() async throws {
        let fixture = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantCouponDetailsEmpty.json"))
        let envelope = try JSONSerialization.jsonObject(with: fixture) as! [String: Any]
        let original = envelope["data"] as! [String: Any]
        func json(_ data: [String: Any]) throws -> String {
            String(data: try JSONSerialization.data(withJSONObject: data), encoding: .utf8)!
        }
        let transport = FulfillmentTransport(), service = makeService(transport)
        let body = try json(original)
        transport.respond(body)
        let details = try await service.couponDetails(couponID: "197", token: "test-token")
        precondition(details.orders.isEmpty && details.pagination == .init(totalItems: 0, countItems: 0, perPage: 3, totalPages: 1, currentPage: 1))
        let coupon = details.coupon
        precondition(coupon.id == "197" && coupon.name == "Test Offer" && coupon.priceHalalas == 100 && coupon.currency == "ريال")
        precondition(coupon.image?.absoluteString == "https://upgrade.loh.com.sa/storage/images/coupons/1792915133_3973.png")
        precondition(coupon.status == "active" && coupon.statusText == "مفعل")
        precondition(coupon.publishedAt == MerchantOfferFormat.parseDate("2026-10-25") && coupon.updatedAt == coupon.publishedAt)
        precondition(coupon.publishedAtText == "25 أكتوبر 2026" && coupon.updatedAtText == "آخر تحديث: 25 أكتوبر 2026")
        for image in [NSNull(), "", "file:///private/test.png", "bad-url"] as [Any] {
            var data = original, item = original["coupon"] as! [String: Any]
            item["image"] = image; data["coupon"] = item
            transport.respond(try json(data))
            let result = try await service.couponDetails(couponID: "197", token: "test-token")
            precondition(result.coupon.image == nil && result.coupon.name == "Test Offer")
        }
        for (field, value) in [("price", "1.001"), ("id", "198")] {
            var data = original, item = original["coupon"] as! [String: Any]
            item[field] = value; data["coupon"] = item
            transport.respond(try json(data))
            do { _ = try await service.couponDetails(couponID: "197", token: "test-token"); preconditionFailure("Invalid coupon accepted") }
            catch { precondition(error as? APIError == .invalidResponse) }
        }
        for (field, value) in [("count_items", 1), ("current_page", 2), ("per_page", 0), ("total_pages", 0), ("total_items", -1)] {
            var data = original, pagination = original["pagination"] as! [String: Any]
            pagination[field] = value; data["pagination"] = pagination
            transport.respond(try json(data))
            do { _ = try await service.couponDetails(couponID: "197", token: "test-token"); preconditionFailure("Invalid pagination accepted") }
            catch { precondition(error as? APIError == .invalidResponse) }
        }
        // Populated rows retain the previously documented purchase shape; pagination can advertise more rows.
        var paged = original
        paged["orders"] = [try JSONSerialization.jsonObject(with: Data(customer.utf8))]
        paged["pagination"] = ["total_items": 4, "count_items": 1, "per_page": 3, "current_page": 1, "total_pages": 2]
        transport.respond(try json(paged))
        let page = try await service.couponDetails(couponID: "197", token: "test-token")
        precondition(page.pagination.hasMore && page.orders.first?.id == "197:" + code)

        var token: String? = "first"
        let store = MerchantOfferStore(service: service, token: { token })
        transport.respond(#"{"pagination":{"total_items":1,"total_pages":1,"current_page":1},"coupons":[{"id":197,"name":"Home name","purchase_times":9,"total_price":"45.00","loh_total_amount":"4.00","created_at":"2026-10-01","currency":"SAR"}]}"#)
        await store.reload(query: "", sort: .recent)
        transport.respond(body)
        await store.loadCouponDetails(offerID: "197")
        precondition(store.customerErrors["197"] == nil && store.orders(for: "197").isEmpty)
        precondition(store.couponDetails["197"]?.coupon == coupon && store.loadingCustomers.isEmpty)
        precondition(store.offer("197")?.nameEn == "Test Offer" && store.offer("197")?.image == coupon.image && store.offer("197")?.priceHalalas == 100)
        precondition(store.offer("197")?.salesCount == 9 && store.offer("197")?.salesHalalas == 4500, "Coupon price and order pagination must not replace home sales aggregates")
        transport.action = { _ in throw URLError(.notConnectedToInternet) }
        await store.loadCouponDetails(offerID: "197")
        precondition(store.customerErrors["197"] == .offline && store.couponDetails["197"]?.coupon == coupon)
        var pending: CheckedContinuation<HTTPResponse, Error>?
        transport.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let old = Task { await store.loadCouponDetails(offerID: "197") }
        while pending == nil { await Task.yield() }
        transport.respond(body.replacingOccurrences(of: "Test Offer", with: "Latest offer"))
        await store.loadCouponDetails(offerID: "197")
        pending!.resume(returning: FulfillmentTransport.success(body))
        await old.value
        precondition(store.couponDetails["197"]?.coupon.name == "Latest offer")
        pending = nil
        transport.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let cancelled = Task { await store.loadCouponDetails(offerID: "197") }
        while pending == nil { await Task.yield() }
        cancelled.cancel()
        pending!.resume(returning: FulfillmentTransport.success(body))
        await cancelled.value
        precondition(store.couponDetails["197"]?.coupon.name == "Latest offer" && store.loadingCustomers.isEmpty)
        pending = nil
        let stale = Task { await store.loadCouponDetails(offerID: "197") }
        while pending == nil { await Task.yield() }
        token = nil
        pending!.resume(returning: FulfillmentTransport.success(body))
        await stale.value
        precondition(store.couponDetails.isEmpty && store.offers.isEmpty && store.orders.isEmpty)
    }
    @MainActor static func populatedCouponDetails() async throws {
        let fixture = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantCouponDetails.json"))
        let envelope = try JSONSerialization.jsonObject(with: fixture) as! [String: Any]
        let original = envelope["data"] as! [String: Any]
        func json(_ data: [String: Any]) throws -> String {
            String(data: try JSONSerialization.data(withJSONObject: data), encoding: .utf8)!
        }
        let transport = FulfillmentTransport(), service = makeService(transport)
        transport.respond(try json(original))
        let details = try await service.couponDetails(couponID: "197", token: "test-token")
        precondition(details.orders.count == 3 && details.pagination.totalItems == 7 && details.pagination.hasMore)
        precondition(details.pagination.currentPage == 1 && details.pagination.totalPages == 3)
        precondition(details.orders.map(\.serverOrderID) == ["910", "909", "908"])
        precondition(details.orders.allSatisfy { $0.customerID == nil && $0.couponName == "Test Offer" && $0.customerAr == "test userr" })
        precondition(details.orders.map(\.isDelivered) == [false, true, false])
        precondition(details.orders.map(\.statusText) == ["بانتظار التسليم", "تم التسليم", "بانتظار التسليم"])
        let selected = details.orders[0]
        precondition(selected.id == "197:20261026910" && selected.code == "20261026910")
        precondition(selected.createdAtText == "اليوم • 01:18 م")
        precondition(selected.purchasedAt == MerchantOfferFormat.parseDate("2026-10-26 13:18:16"))
        precondition(details.coupon.updatedAtText == "آخر تحديث: 26 أكتوبر 2026")

        for (key, invalid) in [("id", "-1"), ("print_code", "../deliver"), ("print_code", "")] {
            var payload = original, rows = original["orders"] as! [[String: Any]]
            rows[0][key] = invalid; payload["orders"] = rows
            transport.respond(try json(payload))
            do { _ = try await service.couponDetails(couponID: "197", token: "token"); preconditionFailure("Malformed order identity accepted") }
            catch { precondition(error as? APIError == .invalidResponse) }
        }
        var leadingZero = original, rows = original["orders"] as! [[String: Any]]
        rows[0]["print_code"] = "000123"; rows[0]["id"] = "910"; leadingZero["orders"] = rows
        transport.respond(try json(leadingZero))
        let zero = try await service.couponDetails(couponID: "197", token: "token")
        precondition(zero.orders[0].code == "000123" && zero.orders[0].serverOrderID == "910")

        let store = MerchantOfferStore(service: service, token: { "token" })
        transport.respond(try json(original))
        await store.loadCouponDetails(offerID: "197")
        precondition(store.orders(for: "197").count == 3 && store.customerErrors["197"] == nil)
        let refreshed = orderResponse(couponID: 197, code: selected.code)
        transport.respond(refreshed)
        await store.loadOrder(id: selected.id)
        precondition(transport.requests.last?.url?.path == "/api/vendor/order-details/910")
        precondition(store.orderErrors[selected.id] == nil, "Order details must resolve a recent order without inventing a customer ID")
        precondition(store.order(selected.id)?.customerID == "848" && store.order(selected.id)?.serverOrderID == "910")
        precondition(store.order(selected.id)?.createdAtText == selected.createdAtText && store.order(selected.id)?.couponName == "Test Offer")
        store.beginVerification(for: selected.id)
        let verified = await store.verifyPurchase(selected.code, method: .code)
        precondition(verified && store.verifiedOrderID == selected.id)
        precondition(transport.requests.last?.url?.path == "/api/vendor/order-details/910",
                     "Verification must use the selected order's API ID too")
        store.cancelVerification()
        transport.respond(orderResponse(couponID: 197, code: selected.code, customerID: 999))
        await store.loadOrder(id: selected.id)
        precondition(store.orderErrors[selected.id] == .invalidResponse, "Known customer identity must still be checked")
        precondition(store.order(selected.id)?.customerID == "848")

        transport.respond("[" + customer.replacingOccurrences(of: code, with: selected.code) + "]")
        await store.loadCustomers(offerID: "197")
        precondition(store.order(selected.id)?.createdAtText == selected.createdAtText && store.order(selected.id)?.serverOrderID == "910")
        precondition(store.order(selected.id)?.details?.priceHalalas == 100 && store.order(selected.id)?.expiresAt != nil,
                     "Refreshing a customer list must preserve the richer order-detail fields")
        transport.respond(orderResponse(couponID: 197, code: selected.code, status: "delivered"))
        await store.loadOrder(id: selected.id)
        precondition(store.order(selected.id)?.isDelivered == true && store.order(selected.id)?.statusText == "تم التسليم", "A refreshed delivery cannot keep a stale pending label")
    }

    @MainActor static func couponDetailsRefresh() async throws {
        let fixture = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantCouponDetails.json"))
        let envelope = try JSONSerialization.jsonObject(with: fixture) as! [String: Any]
        let original = envelope["data"] as! [String: Any]
        let template = (original["orders"] as! [[String: Any]])[0]
        func payload(_ ids: [Int], name: String = "Refreshed offer") throws -> String {
            var data = original, coupon = original["coupon"] as! [String: Any]
            coupon["name"] = name; data["coupon"] = coupon
            data["orders"] = ids.map { id -> [String: Any] in
                var row = template
                row["id"] = id; row["print_code"] = "100\(id)"
                row["customer_name"] = "Test customer \(id)"
                return row
            }
            data["pagination"] = ["total_items": ids.count, "count_items": ids.count,
                                  "per_page": max(1, ids.count), "current_page": 1, "total_pages": 1]
            return String(data: try JSONSerialization.data(withJSONObject: data), encoding: .utf8)!
        }
        let initialIDs = [5, 4, 3, 2, 1], refreshedIDs = [6, 5, 4, 3, 2, 1]
        let initial = try payload(initialIDs, name: "Initial offer")
        let refreshed = try payload(refreshedIDs)
        let transport = FulfillmentTransport()
        var token: String? = "token"
        let store = MerchantOfferStore(service: makeService(transport), token: { token })
        transport.respond(initial)
        await store.loadCouponDetails(offerID: "197")
        precondition(store.orders(for: "197").map(\.serverOrderID) == initialIDs.map { String($0) })
        let request = transport.requests.last!
        precondition(request.httpMethod == "GET" && request.httpBody == nil && request.url?.query == nil)
        precondition(request.url?.path == "/api/vendor/coupon-details/197")

        var continuation: CheckedContinuation<HTTPResponse, Error>?
        var requestWasCancelled = false
        transport.action = { _ in
            let response = try await withCheckedThrowingContinuation { continuation = $0 }
            requestWasCancelled = Task.isCancelled
            return response
        }
        let before = transport.requests.count
        let pull = Task { await store.refreshCouponDetails(offerID: "197") }
        while continuation == nil { await Task.yield() }
        precondition(store.loadingCustomers.contains("197") && store.orders(for: "197").count == 5)
        pull.cancel()
        continuation!.resume(returning: FulfillmentTransport.success(refreshed))
        await pull.value
        precondition(!requestWasCancelled && store.loadingCustomers.isEmpty && store.customerErrors["197"] == nil)
        precondition(store.orders(for: "197").map(\.serverOrderID) == refreshedIDs.map { String($0) },
                     "Show every returned order, with new orders first as returned by the API")
        precondition(store.couponDetails["197"]?.orders.count == 6 && store.couponDetails["197"]?.coupon.name == "Refreshed offer")
        precondition(transport.requests.count == before + 1 && transport.requests.last?.url == request.url,
                     "Refresh sends one request to coupon-details without switching to coupon-users")

        for body in ["", "{}", #"{"key":"success","data":{}}"#] {
            transport.action = { _ in .init(statusCode: 200, data: Data(body.utf8)) }
            await store.refreshCouponDetails(offerID: "197")
            precondition(store.customerErrors["197"] == .invalidResponse && store.loadingCustomers.isEmpty)
            precondition(store.orders(for: "197").count == 6 && store.couponDetails["197"]?.coupon.name == "Refreshed offer",
                         "A missing or malformed response must not become an empty order list")
        }
        transport.action = { _ in throw URLError(.timedOut) }
        await store.refreshCouponDetails(offerID: "197")
        precondition(store.customerErrors["197"] == .timeout && store.orders(for: "197").count == 6)

        continuation = nil; requestWasCancelled = false
        transport.action = { _ in
            let response = try await withCheckedThrowingContinuation { continuation = $0 }
            requestWasCancelled = Task.isCancelled
            return response
        }
        let leaving = Task { await store.refreshCouponDetails(offerID: "197") }
        while continuation == nil { await Task.yield() }
        store.cancelCouponRefresh(offerID: "197")
        continuation!.resume(returning: FulfillmentTransport.success(initial))
        await leaving.value
        precondition(requestWasCancelled && store.orders(for: "197").count == 6)
        precondition(store.customerErrors["197"] == nil && store.loadingCustomers.isEmpty)

        continuation = nil
        let stale = Task { await store.refreshCouponDetails(offerID: "197") }
        while continuation == nil { await Task.yield() }
        transport.respond(try payload([7, 6]))
        await store.loadCouponDetails(offerID: "197")
        continuation!.resume(returning: FulfillmentTransport.success(initial))
        await stale.value
        precondition(store.orders(for: "197").map(\.serverOrderID) == ["7", "6"] && store.loadingCustomers.isEmpty)

        transport.respond(try payload([]))
        await store.refreshCouponDetails(offerID: "197")
        precondition(store.orders(for: "197").isEmpty && store.customerErrors["197"] == nil,
                     "A valid orders: [] response must still clear the list")
        transport.respond(refreshed)
        await store.loadCouponDetails(offerID: "197")
        continuation = nil
        transport.action = { _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let logout = Task { await store.refreshCouponDetails(offerID: "197") }
        while continuation == nil { await Task.yield() }
        token = nil
        continuation!.resume(throwing: URLError(.timedOut))
        await logout.value
        precondition(store.orders.isEmpty && store.couponDetails.isEmpty && store.loadingCustomers.isEmpty && store.customerErrors.isEmpty)
    }

    @MainActor static func deliveryFlow() async {
        let transport = FulfillmentTransport()
        let store = MerchantOfferStore(service: makeService(transport), token: { "token" })
        transport.respond(detail)
        await store.loadCouponDetails(offerID: "195")
        precondition(transport.requests.last?.url?.path.hasSuffix("coupon-details/195") == true)
        transport.respond(rows)
        await store.loadCustomers(offerID: "195")
        precondition(transport.requests.last?.url?.path.hasSuffix("coupon-users/195") == true)
        transport.respond(orderResponse(status: "pending"))
        await store.loadOrder(id: orderID)
        precondition(transport.requests.last?.url?.path.hasSuffix("order-details/910") == true)
        transport.respond(sale)
        await store.loadSale(id: orderID)
        precondition(store.sales[orderID]?.priceHalalas == 19229)
        precondition(transport.requests.last?.url?.path.hasSuffix("coupon-sales/195") == true, "Provisional coupon-ID lookup must still match the selected purchase")
        let before = transport.requests.count
        let unverified = await store.confirmDelivery(id: orderID)
        precondition(!unverified && transport.requests.count == before)
        store.beginVerification(for: orderID)
        let wrong = await store.verifyPurchase("999999", method: .code)
        precondition(!wrong && store.verificationError == .invalid && transport.requests.count == before)
        transport.respond(orderResponse())
        let verified = await store.verifyPurchase(" ٠٠١٢٣٤٥٦٧٨ ", method: .barcode)
        precondition(verified && store.verifiedOrderID == orderID && store.order(orderID)?.method == .barcode)
        precondition(transport.requests.last?.url?.path == "/api/vendor/order-details/910")
        precondition(store.order(orderID)?.isDelivered == false && !transport.requests.contains { $0.httpMethod == "POST" })
        var pending: CheckedContinuation<HTTPResponse, Error>?
        transport.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let delivery = Task { await store.confirmDelivery(id: orderID) }
        while pending == nil { await Task.yield() }
        precondition(store.deliveringOrders.contains(orderID) && store.verifiedOrderID == nil)
        let count = transport.requests.count
        let duplicate = await store.confirmDelivery(id: orderID)
        precondition(!duplicate && transport.requests.count == count)
        pending!.resume(returning: FulfillmentTransport.delivered)
        let delivered = await delivery.value
        precondition(delivered && store.order(orderID)?.isDelivered == true && store.deliveryMessages[orderID] == "Delivery confirmed")
        precondition(store.deliveringOrders.isEmpty)
        transport.respond(orderResponse()) // A stale server/list response must not undo acknowledged delivery.
        await store.loadOrder(id: orderID)
        transport.respond(rows)
        await store.loadCustomers(offerID: "195")
        precondition(store.order(orderID)?.isDelivered == true)
        store.beginVerification(for: orderID)
        transport.respond(orderResponse())
        let repeatVerification = await store.verifyPurchase(code, method: .code)
        precondition(!repeatVerification && store.verificationError == .delivered)
        let repeatDelivery = await store.confirmDelivery(id: orderID)
        precondition(!repeatDelivery && transport.requests.filter { $0.httpMethod == "POST" }.count == 1)
    }
    @MainActor static func identityAndFailures() async {
        let transport = FulfillmentTransport()
        let store = MerchantOfferStore(service: makeService(transport), token: { "token" })
        transport.respond(detail)
        await store.loadCouponDetails(offerID: "195")
        transport.respond(rows)
        await store.loadCustomers(offerID: "195")
        for wrongSale in [sale.replacingOccurrences(of: code, with: "9999999999"), sale.replacingOccurrences(of: "848", with: "849")] {
            transport.respond(wrongSale)
            await store.loadSale(id: orderID)
            precondition(store.sales[orderID] == nil && store.saleErrors[orderID] == .invalidResponse)
        }
        store.beginVerification(for: orderID)
        transport.respond(orderResponse(customerID: 849))
        let wrongCustomer = await store.verifyPurchase(code, method: .code)
        precondition(!wrongCustomer && store.verificationAPIError == .invalidResponse)
        transport.respond(orderResponse(status: "delivered"))
        let alreadyDelivered = await store.verifyPurchase(code, method: .code)
        precondition(!alreadyDelivered && store.verificationError == .delivered && store.order(orderID)?.isDelivered == true)
        transport.respond(orderResponse())
        await store.loadOrder(id: orderID)
        store.beginVerification(for: orderID)
        let verified = await store.verifyPurchase(code, method: .code)
        precondition(verified)
        transport.action = { _ in throw URLError(.timedOut) }
        let failed = await store.confirmDelivery(id: orderID)
        precondition(!failed && store.deliveryErrors[orderID] == .timeout && store.verifiedOrderID == nil && store.order(orderID)?.isDelivered == false)
        let count = transport.requests.count
        let retry = await store.confirmDelivery(id: orderID)
        precondition(!retry && transport.requests.count == count, "An uncertain delivery must never retry automatically")
        store.beginVerification(for: orderID)
        transport.respond(orderResponse(status: "delivered"))
        let recovered = await store.verifyPurchase(code, method: .code)
        precondition(!recovered && store.order(orderID)?.isDelivered == true && store.deliveryErrors[orderID] == nil)
        precondition(transport.requests.filter { $0.httpMethod == "POST" }.count == 1)
    }
    @MainActor static func cancellationAndAccounts() async {
        let transport = FulfillmentTransport()
        var token: String? = "first"
        let store = MerchantOfferStore(service: makeService(transport), token: { token })
        transport.respond(detail)
        await store.loadCouponDetails(offerID: "195")
        transport.respond(rows)
        await store.loadCustomers(offerID: "195")
        var pending: CheckedContinuation<HTTPResponse, Error>?
        transport.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        store.beginVerification(for: orderID)
        let verification = Task { await store.verifyPurchase(code, method: .code) }
        while pending == nil { await Task.yield() }
        store.cancelVerification()
        pending!.resume(returning: FulfillmentTransport.success(orderResponse()))
        let cancelled = await verification.value
        precondition(!cancelled && store.verifiedOrderID == nil && !store.isVerifying)
        pending = nil
        store.beginVerification(for: orderID)
        let oldSession = Task { await store.verifyPurchase(code, method: .code) }
        while pending == nil { await Task.yield() }
        token = "second"
        pending!.resume(returning: FulfillmentTransport.success(orderResponse()))
        let stale = await oldSession.value
        precondition(!stale && store.orders.isEmpty && store.sales.isEmpty && store.verifiedOrderID == nil)
        transport.respond(detail)
        await store.loadCouponDetails(offerID: "195")
        transport.respond(rows)
        await store.loadCustomers(offerID: "195")
        store.beginVerification(for: orderID)
        transport.respond(orderResponse())
        let verified = await store.verifyPurchase(code, method: .code)
        precondition(verified)
        pending = nil
        transport.action = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let delivery = Task { await store.confirmDelivery(id: orderID) }
        while pending == nil { await Task.yield() }
        token = nil
        pending!.resume(returning: FulfillmentTransport.delivered)
        let staleDelivery = await delivery.value
        precondition(!staleDelivery && store.orders.isEmpty && store.deliveryMessages.isEmpty && store.deliveringOrders.isEmpty)
        precondition(MerchantOfferStore.normalizedPurchaseCode("۱۲۳۴۵۶۷۸۹۰") == "1234567890")
        precondition(MerchantOfferStore.normalizedPurchaseCode("12x34") == nil && MerchantOfferStore.normalizedPurchaseCode(" ") == nil)
    }
}

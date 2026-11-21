import Foundation

struct OfferEndpoints {
    private init() {}
}

extension OfferEndpoints {
    static func list(query: String, sort: String, page: Int, token: String) -> Endpoint<APIEnvelope<OfferPageData>> {
        var queries: APIParameters = ["sort_by": sort, "page": page]
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { queries["name"] = name }
        return Endpoint(path: "vendor/home-page", queries: queries, headerType: .authorized(token: token))
    }

    static func customers(couponID: String, token: String) -> Endpoint<APIEnvelope<[PurchaseData]>> {
        return Endpoint(path: "vendor/coupon-users/" + couponID, headerType: .authorized(token: token))
    }

    static func couponDetails(id: String, token: String) -> Endpoint<APIEnvelope<CouponDetailsData>> {
        return Endpoint(path: "vendor/coupon-details/" + id, headerType: .authorized(token: token))
    }

    static func orderDetails(id: String, token: String) -> Endpoint<APIEnvelope<OrderDetailsData>> {
        return Endpoint(path: "vendor/order-details/" + id, headerType: .authorized(token: token))
    }

    static func sales(id: String, token: String) -> Endpoint<APIEnvelope<CouponSaleData>> {
        return Endpoint(path: "vendor/coupon-sales/" + id, headerType: .authorized(token: token))
    }

    static func deliver(printCode: String, token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(
            method: .post,
            path: "vendor/deliver-coupon/" + printCode,
            queries: ["_method": "put"],
            headerType: .authorized(token: token)
        )
    }
}

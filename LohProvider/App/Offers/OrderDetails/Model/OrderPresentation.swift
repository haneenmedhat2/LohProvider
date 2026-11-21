import Foundation

struct MerchantOrderPresentation {
    let order: MerchantOfferOrder
    let offer: MerchantOffer
    let coupon: MerchantCoupon?
    var locallyVerified = false

    var isComplete: Bool { order.isDelivered }
    var showsReady: Bool { !isComplete && (order.isReadyForDelivery || locallyVerified) }
    var showsResult: Bool { isComplete || showsReady }
    var statusText: String? { coupon?.statusText ?? order.statusText }
    var method: MerchantVerificationMethod? {
        order.method ?? order.details?.verification.method.flatMap(MerchantVerificationMethod.init(rawValue:))
    }
    var artwork: MerchantOffer {
        var result = offer
        if let details = order.details { result.image = details.couponImage; result.artwork = "" }
        return result
    }
    func verificationText(customerRow: Bool = false, localize: (String) -> String) -> String {
        if !customerRow, let method {
            return localize(method == .barcode ? "nav_scan_barcode" : "nav_order_code")
        }
        if let method = order.method {
            return localize(method == .barcode ? "offers_verified_barcode" : "offers_verified_code")
        }
        if let text = order.details?.verification.methodText, !text.isEmpty { return text }
        return localize("offers_not_verified")
    }
}

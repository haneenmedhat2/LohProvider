import Foundation

struct MerchantOfferVendor: Equatable {
    let id: String
    let name: String
    let greeting: String?
    let image: URL?
}

struct MerchantOfferStatistics: Equatable {
    let totalOffers: Int
    let activeOffers: Int
    let salesCount: Int
    let salesHalalas: Int
    let currency: String
}

struct MerchantOffer: Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    var artwork = ""
    var priceHalalas: Int?
    let salesCount: Int
    let lohHalalas: Int
    let salesHalalas: Int
    let createdAt: Date?
    var currency: String?
    var image: URL?
    func name(arabic: Bool) -> String { arabic ? nameAr : nameEn }
}

struct MerchantCouponDetails {
    let coupon: MerchantCoupon
    let orders: [MerchantOfferOrder]
    let pagination: MerchantCouponPagination
}

struct MerchantCoupon: Equatable {
    let id: String
    let name: String
    let image: URL?
    let priceHalalas: Int
    let currency: String
    let status: String
    let statusText: String
    let publishedAt: Date?
    let publishedAtText: String?
    let updatedAt: Date?
    let updatedAtText: String?

    func applying(to offer: MerchantOffer) -> MerchantOffer {
        .init(id: id, nameAr: name, nameEn: name, artwork: offer.artwork, priceHalalas: priceHalalas,
              salesCount: offer.salesCount, lohHalalas: offer.lohHalalas, salesHalalas: offer.salesHalalas,
              createdAt: publishedAt, currency: currency, image: image)
    }
}

struct MerchantCouponPagination: Equatable {
    let totalItems: Int
    let countItems: Int
    let perPage: Int
    let totalPages: Int
    let currentPage: Int
    var hasMore: Bool { currentPage < totalPages }
}

enum MerchantVerificationMethod: String { case code, barcode }
enum MerchantVerificationError: String, Identifiable {
    case invalid, expired, delivered
    var id: String { rawValue }
    var titleKey: String { "offers_error_" + rawValue }
    var messageKey: String { titleKey + "_message" }
}

struct MerchantOfferOrder: Identifiable {
    let id: String
    let offerID: String
    let code: String
    let customerAr: String
    let customerEn: String
    var purchasedAt: Date?
    var expiresAt: Date?
    var delivered = false // Set after a confirmed delivery, or by the explicit design preview.
    var method: MerchantVerificationMethod?
    var customerID: String?
    var phone: String?
    var deliveryStatus: String?
    var usedStatus: String?
    // Coupon-details exposes an order ID, not a customer ID. Keep both identities separate.
    var serverOrderID: String?
    var couponName: String?
    var createdAtText: String?
    var statusText: String?
    var details: MerchantOrderDetails?
    var isDelivered: Bool {
        delivered || ["تم التسليم", "delivered", "used"].contains(normalizedStatus)
    }
    var isReadyForDelivery: Bool { normalizedStatus == "ready" && !isDelivered }
    private var normalizedStatus: String { deliveryStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "" }
    func customer(arabic: Bool) -> String { arabic ? customerAr : customerEn }

    func matchesPurchase(_ other: MerchantOfferOrder) -> Bool {
        offerID == other.offerID && code == other.code
            && (customerID == nil || customerID == other.customerID)
            && (serverOrderID == nil || other.serverOrderID == nil || serverOrderID == other.serverOrderID)
    }
}

struct MerchantCouponSale: Equatable {
    let id: String
    let quantity: Int
    let purchaseCode: String
    let priceHalalas: Int
    let lohHalalas: Int
    let currency: String
    let customerID: String
    let customerName: String
    let phone: String?
    let deliveryStatus: String?
    let usedStatus: String?
}

enum MerchantOfferFormat {
    nonisolated static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        return calendar
    }
    static func money(_ halalas: Int?, arabic: Bool, currency: String? = nil) -> String {
        guard let halalas else { return "—" }
        let fraction = halalas.magnitude % 100
        let number = (halalas < 0 ? "-" : "") + String(halalas.magnitude / 100)
            + "." + (fraction < 10 ? "0" : "") + String(fraction)
        let symbol = currency ?? (arabic ? "رس" : "SAR")
        return arabic ? number + " " + symbol : symbol + " " + number
    }
    nonisolated static func date(_ date: Date?, arabic: Bool, time: Bool = false) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_GB")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = time ? "hh:mm a" : "dd MMM yyyy"
        return formatter.string(from: date)
    }
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false
        for format in ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw), formatter.string(from: date) == raw { return date }
        }
        return ISO8601DateFormatter().date(from: raw)
    }
}

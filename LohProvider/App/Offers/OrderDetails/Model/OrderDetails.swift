import Foundation

/// Fields supplied by the single-order response, separate from the purchase-list preview.
struct MerchantOrderDetails {
    let couponNumber: String
    let couponImage: URL?
    let priceHalalas: Int
    let currency: String
    let purchasedAt: Timestamp
    let validUntil: Timestamp
    let verification: Verification

    struct Timestamp {
        let date: Date
        let dateText: String
        let timeText: String
    }

    struct Verification {
        let isVerified: Bool
        let method: String?
        let methodText: String
        let verifiedAt: Date?
    }
}

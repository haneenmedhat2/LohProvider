import Foundation

/// Only the values documented by the home-page query description are sent to the server.
enum MerchantOfferSort: String, CaseIterable, Identifiable {
    case recent = "newest", oldest, highPrice = "high_price", lowPrice = "low_price"
    var id: String { rawValue }
    var key: String { self == .recent ? "offers_sort_recent" : "offers_sort_" + rawValue }
}

struct MerchantOfferPage {
    let offers: [MerchantOffer]
    let totalItems: Int
    let currentPage: Int
    let totalPages: Int
    var vendor: MerchantOfferVendor? = nil
    var stats: MerchantOfferStatistics? = nil
    var hasMore: Bool { currentPage < totalPages }
}

/// The live order-details response contains one order with nested coupon/customer/date objects.
struct OrderDetailsData: Decodable {
    let order: MerchantOfferOrder

    enum CodingKeys: String, CodingKey {
        case id, coupon, customer, price, currency, status
        case couponNumber = "coupon_number", purchaseCode = "purchase_code", statusText = "status_text"
        case purchasedAt = "purchased_at", validUntil = "valid_until"
    }
    enum CouponKeys: String, CodingKey { case id, name, image }
    enum CustomerKeys: String, CodingKey {
        case id, name, phone, isVerified = "is_verified", verificationMethod = "verification_method"
        case verificationMethodText = "verification_method_text", verifiedAt = "verified_at"
    }
    enum DateKeys: String, CodingKey { case datetime, dateText = "date_text", timeText = "time_text" }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let coupon = try values.nestedContainer(keyedBy: CouponKeys.self, forKey: .coupon)
        let customer = try values.nestedContainer(keyedBy: CustomerKeys.self, forKey: .customer)
        let couponID = try coupon.identifier(.id)
        let code = try values.identifier(.purchaseCode)
        let name = try customer.decode(String.self, forKey: .name)
        let purchasedAt = try Self.timestamp(values.nestedContainer(keyedBy: DateKeys.self, forKey: .purchasedAt))
        let validUntil = try Self.timestamp(values.nestedContainer(keyedBy: DateKeys.self, forKey: .validUntil))
        let image = try coupon.decodeIfPresent(String.self, forKey: .image).flatMap { raw -> URL? in
            guard let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.isEmpty == false else { return nil }
            return url
        }
        let verifiedAt: Date?
        if let raw = try customer.decodeIfPresent(String.self, forKey: .verifiedAt) {
            guard let date = MerchantOfferFormat.parseDate(raw) else { throw APIError.invalidResponse }
            verifiedAt = date
        } else { verifiedAt = nil }
        order = .init(
            id: couponID + ":" + code, offerID: couponID, code: code, customerAr: name, customerEn: name,
            purchasedAt: purchasedAt.date, expiresAt: validUntil.date,
            customerID: try customer.identifier(.id), phone: try customer.decodeIfPresent(String.self, forKey: .phone),
            deliveryStatus: try values.decode(String.self, forKey: .status), serverOrderID: try values.identifier(.id),
            couponName: try coupon.decode(String.self, forKey: .name), statusText: try values.decode(String.self, forKey: .statusText),
            details: .init(couponNumber: try values.identifier(.couponNumber), couponImage: image,
                           priceHalalas: try values.decode(MerchantAPIMoney.self, forKey: .price).halalas,
                           currency: try values.decode(String.self, forKey: .currency),
                           purchasedAt: purchasedAt, validUntil: validUntil,
                           verification: .init(isVerified: try customer.decode(Bool.self, forKey: .isVerified),
                                               method: try customer.decodeIfPresent(String.self, forKey: .verificationMethod),
                                               methodText: try customer.decode(String.self, forKey: .verificationMethodText),
                                               verifiedAt: verifiedAt)))
    }

    private static func timestamp(_ values: KeyedDecodingContainer<DateKeys>) throws -> MerchantOrderDetails.Timestamp {
        guard let date = MerchantOfferFormat.parseDate(try values.decode(String.self, forKey: .datetime)) else {
            throw APIError.invalidResponse
        }
        return .init(date: date, dateText: try values.decode(String.self, forKey: .dateText),
                     timeText: try values.decode(String.self, forKey: .timeText))
    }
}

/// The live response supersedes the collection's older customer-array example.
struct CouponDetailsData: Decodable {
    let coupon: MerchantCoupon
    let orders: [CouponOrderDTO]
    let pagination: MerchantCouponPagination
    enum CodingKeys: String, CodingKey { case coupon, orders, pagination }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        coupon = try values.decode(CouponDetailsInfoDTO.self, forKey: .coupon).coupon
        orders = try values.decode([CouponOrderDTO].self, forKey: .orders)
        pagination = try values.decode(CouponDetailsPaginationDTO.self, forKey: .pagination).pagination
        guard pagination.currentPage == 1, pagination.totalPages >= 1, pagination.perPage > 0,
              pagination.countItems == orders.count, pagination.countItems <= pagination.perPage,
              pagination.totalItems >= orders.count,
              pagination.totalItems > 0 || pagination.totalPages == 1 else { throw APIError.invalidResponse }
    }
}

/// Recent orders have their own response shape; `id` here identifies an order.
struct CouponOrderDTO: Decodable {
    let purchase: PurchaseData?
    let serverOrderID: String?
    let name: String?
    let couponName: String?
    let code: String?
    let createdAt: Date?
    let createdAtText: String?
    let status: String?
    let statusText: String?

    enum CodingKeys: String, CodingKey {
        case id, name = "customer_name", couponName = "coupon_name", code = "print_code"
        case createdAt = "created_at", createdAtText = "created_at_text", status, statusText = "status_text"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if values.contains(.name) || values.contains(.code) {
            purchase = nil
            serverOrderID = try values.identifier(.id)
            name = try values.decode(String.self, forKey: .name)
            couponName = try values.decode(String.self, forKey: .couponName)
            code = try values.identifier(.code)
            createdAt = MerchantOfferFormat.parseDate(try values.decodeIfPresent(String.self, forKey: .createdAt))
            createdAtText = try values.decodeIfPresent(String.self, forKey: .createdAtText)
            status = try values.decode(String.self, forKey: .status)
            statusText = try values.decode(String.self, forKey: .statusText)
        } else {
            // Preserve the collection's older customer-array examples.
            purchase = try PurchaseData(from: decoder)
            serverOrderID = nil; name = nil; couponName = nil; code = nil
            createdAt = nil; createdAtText = nil; status = nil; statusText = nil
        }
    }

    func order(couponID: String) -> MerchantOfferOrder {
        if let purchase { return purchase.order(couponID: couponID) }
        return .init(id: couponID + ":" + (code ?? ""), offerID: couponID, code: code ?? "",
                     customerAr: name ?? "", customerEn: name ?? "", purchasedAt: createdAt,
                     deliveryStatus: status, serverOrderID: serverOrderID, couponName: couponName,
                     createdAtText: createdAtText, statusText: statusText)
    }
}

struct CouponDetailsInfoDTO: Decodable {
    let coupon: MerchantCoupon
    enum CodingKeys: String, CodingKey {
        case id, name, image, price, currency, status, statusText = "status_text"
        case publishedAt = "published_at", publishedAtText = "published_at_text"
        case updatedAt = "updated_at", updatedAtText = "updated_at_text"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let image = try values.decodeIfPresent(String.self, forKey: .image).flatMap { raw -> URL? in
            guard let url = URL(string: raw), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.isEmpty == false else { return nil }
            return url
        }
        coupon = .init(id: try values.identifier(.id), name: try values.decode(String.self, forKey: .name), image: image,
                       priceHalalas: try values.decode(MerchantAPIMoney.self, forKey: .price).halalas,
                       currency: try values.decode(String.self, forKey: .currency), status: try values.decode(String.self, forKey: .status),
                       statusText: try values.decode(String.self, forKey: .statusText),
                       publishedAt: MerchantOfferFormat.parseDate(try values.decodeIfPresent(String.self, forKey: .publishedAt)),
                       publishedAtText: try values.decodeIfPresent(String.self, forKey: .publishedAtText),
                       updatedAt: MerchantOfferFormat.parseDate(try values.decodeIfPresent(String.self, forKey: .updatedAt)),
                       updatedAtText: try values.decodeIfPresent(String.self, forKey: .updatedAtText))
    }
}

struct CouponDetailsPaginationDTO: Decodable {
    let pagination: MerchantCouponPagination
    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items", countItems = "count_items", perPage = "per_page"
        case totalPages = "total_pages", currentPage = "current_page"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pagination = .init(totalItems: try values.nonnegativeInteger(.totalItems), countItems: try values.nonnegativeInteger(.countItems),
                           perPage: try values.nonnegativeInteger(.perPage), totalPages: try values.nonnegativeInteger(.totalPages),
                           currentPage: try values.nonnegativeInteger(.currentPage))
    }
    // The customer preview uses the first page; View All loads coupon-users on the configured API origin.
}

struct CouponSaleData: Decodable {
    let sale: MerchantCouponSale
    enum CodingKeys: String, CodingKey {
        case id, quantity = "qty", purchaseCode = "purchase_code", price, lohAmount = "loh_amount", currency, customer = "user_details"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let customer = try values.decode(PurchaseData.self, forKey: .customer)
        let code = try values.decode(String.self, forKey: .purchaseCode)
        guard code == customer.code else { throw APIError.invalidResponse }
        sale = MerchantCouponSale(id: try values.identifier(.id), quantity: try values.nonnegativeInteger(.quantity),
                                  purchaseCode: code, priceHalalas: try values.decode(MerchantAPIMoney.self, forKey: .price).halalas,
                                  lohHalalas: try values.decode(MerchantAPIMoney.self, forKey: .lohAmount).halalas,
                                  currency: try values.decode(String.self, forKey: .currency),
                                  customerID: customer.customerID, customerName: customer.name, phone: customer.phone,
                                  deliveryStatus: customer.deliveryStatus, usedStatus: customer.usedStatus)
    }
}

struct OfferPageData: Decodable {
    let pagination: PaginationDTO
    let coupons: [CouponDTO]
    let vendor: VendorDTO?
    let stats: StatisticsDTO?
}

struct VendorDTO: Decodable {
    let vendor: MerchantOfferVendor
    enum CodingKeys: String, CodingKey { case id, name, greeting, image }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let image = try values.decodeIfPresent(String.self, forKey: .image).flatMap { raw -> URL? in
            guard let url = URL(string: raw), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else { return nil }
            return url
        }
        vendor = MerchantOfferVendor(id: try values.identifier(.id), name: try values.decode(String.self, forKey: .name),
                                     greeting: try values.decodeIfPresent(String.self, forKey: .greeting), image: image)
    }
}

struct StatisticsDTO: Decodable {
    let statistics: MerchantOfferStatistics
    enum CodingKeys: String, CodingKey {
        case totalOffers = "total_offers", activeOffers = "active_offers", salesCount = "sales_count"
        case salesTotal = "sales_total", currency
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        statistics = MerchantOfferStatistics(totalOffers: try values.nonnegativeInteger(.totalOffers),
                                             activeOffers: try values.nonnegativeInteger(.activeOffers),
                                             salesCount: try values.nonnegativeInteger(.salesCount),
                                             salesHalalas: try values.decode(MerchantAPIMoney.self, forKey: .salesTotal).halalas,
                                             currency: try values.decode(String.self, forKey: .currency))
    }
}

struct PaginationDTO: Decodable {
    let totalItems: Int
    let totalPages: Int
    let currentPage: Int
    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items", totalPages = "total_pages", currentPage = "current_page"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalItems = try values.nonnegativeInteger(.totalItems)
        totalPages = try values.nonnegativeInteger(.totalPages)
        currentPage = try values.nonnegativeInteger(.currentPage)
    }
    // Deliberately ignore next_page_url: every page stays on the configured API origin.
}

struct CouponDTO: Decodable {
    let offer: MerchantOffer
    enum CodingKeys: String, CodingKey {
        case id, name, currency, image, purchaseTimes = "purchase_times", totalPrice = "total_price"
        case lohTotalAmount = "loh_total_amount", createdAt = "created_at"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let image = try values.decodeIfPresent(String.self, forKey: .image).flatMap { raw -> URL? in
            guard let url = URL(string: raw), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.isEmpty == false else { return nil }
            return url
        }
        offer = MerchantOffer(id: try values.identifier(.id), nameAr: try values.decode(String.self, forKey: .name),
                              nameEn: try values.decode(String.self, forKey: .name),
                              salesCount: try values.nonnegativeInteger(.purchaseTimes),
                              lohHalalas: try values.decode(MerchantAPIMoney.self, forKey: .lohTotalAmount).halalas,
                              salesHalalas: try values.decode(MerchantAPIMoney.self, forKey: .totalPrice).halalas,
                              createdAt: MerchantOfferFormat.parseDate(try values.decodeIfPresent(String.self, forKey: .createdAt)),
                              currency: try values.decode(String.self, forKey: .currency), image: image)
    }
}

struct PurchaseData: Decodable {
    let customerID: String
    let name: String
    let phone: String?
    let code: String
    let deliveryStatus: String?
    let usedStatus: String?
    enum CodingKeys: String, CodingKey {
        case id, name, phone, code = "purchase_code", deliveryStatus = "deliver_status", usedStatus = "used_status"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        customerID = try values.identifier(.id)
        name = try values.decode(String.self, forKey: .name)
        phone = try values.decodeIfPresent(String.self, forKey: .phone)
        code = try values.decode(String.self, forKey: .code)
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidResponse }
        deliveryStatus = try values.decodeIfPresent(String.self, forKey: .deliveryStatus)
        usedStatus = try values.decodeIfPresent(String.self, forKey: .usedStatus)
    }
    func order(couponID: String) -> MerchantOfferOrder {
        .init(id: couponID + ":" + code, offerID: couponID, code: code, customerAr: name, customerEn: name,
              customerID: customerID, phone: phone, deliveryStatus: deliveryStatus, usedStatus: usedStatus)
    }
}

/// Monetary API values are riyals. Convert with Decimal, rejecting fractional halalas and overflow.
struct MerchantAPIMoney: Decodable {
    let halalas: Int
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        let amount: Decimal
        if let string = try? value.decode(String.self) {
            guard string.range(of: "^[0-9]+(?:\\.[0-9]+)?$", options: .regularExpression) != nil,
                  let decimal = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
                throw APIError.invalidResponse
            }
            amount = decimal
        } else { amount = try value.decode(Decimal.self) }
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard !scaled.isNaN, amount >= 0, rounded == scaled, scaled <= Decimal(Int.max) else { throw APIError.invalidResponse }
        halalas = NSDecimalNumber(decimal: scaled).intValue
    }
}

private extension KeyedDecodingContainer {
    func nonnegativeInteger(_ key: Key) throws -> Int {
        let result: Int
        if let number = try? decode(Int.self, forKey: key) { result = number }
        else {
            guard let number = Int(try decode(String.self, forKey: key)) else { throw APIError.invalidResponse }
            result = number
        }
        guard result >= 0 else { throw APIError.invalidResponse }
        return result
    }
    func identifier(_ key: Key) throws -> String {
        if let number = try? decode(Int.self, forKey: key), number >= 0 { return String(number) }
        let value = try decode(String.self, forKey: key)
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw APIError.invalidResponse }
        return value
    }
}


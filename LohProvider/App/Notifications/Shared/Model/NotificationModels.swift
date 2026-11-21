import Foundation

enum MerchantNotificationDestination: Equatable {
    case order(String), settlements, offer(String), notifications

    static func resolve(type: String?, orderID: String?, couponID: String?) -> Self {
        switch type {
        case "new_order":
            return orderID.map(Self.order) ?? .notifications
        case "settlement_request":
            return .settlements
        default:
            return couponID.map(Self.offer) ?? .notifications
        }
    }

    /// FCM data fields are strings; APNs also supplies unrelated nested dictionaries.
    static func fromPush(_ userInfo: [AnyHashable: Any]) -> Self {
        let data = userInfo["data"] as? [String: Any]
        func value(_ key: String) -> Any? { data?[key] ?? userInfo[key] }
        return resolve(type: value("type") as? String,
                       orderID: identifier(value("order_id")),
                       couponID: identifier(value("coupon_id")))
    }

    fileprivate static func identifier(_ value: Any?) -> String? {
        if let string = value as? String, let number = Int(string), number > 0 { return String(number) }
        if let number = value as? Int, number > 0 { return String(number) }
        return nil
    }
}

struct MerchantNotification: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let type: String?
    let isClickable: Bool
    let couponID: String?
    let orderID: String?
    var destination: MerchantNotificationDestination {
        // Vendor inbox rows can omit or misreport is_clickable for typed actions.
        if type == "new_order" || type == "settlement_request" {
            return .resolve(type: type, orderID: orderID, couponID: couponID)
        }
        guard isClickable else { return .notifications }
        return .resolve(type: type, orderID: orderID, couponID: couponID)
    }
    /// Older responses omit read state; a tap still asks the server to mark those notifications read.
    var isRead: Bool?
    /// The API supplies localized relative text, not a timestamp (for example, "منذ شهر").
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id, title, body, key, type, data, dataType = "data_type"
        case isClickable = "is_clickable", couponID = "coupon_id", orderID = "order_id", createdAt = "created_at"
        case isRead = "is_read", readAt = "read_at"
    }
    private struct Payload: Decodable {
        let type: String?
        let orderID: String?
        let couponID: String?

        private enum CodingKeys: String, CodingKey {
            case type, orderID = "order_id", couponID = "coupon_id"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            type = try values.decodeIfPresent(String.self, forKey: .type)
            orderID = try values.positiveIdentifierIfPresent(.orderID)
            couponID = try values.positiveIdentifierIfPresent(.couponID)
        }
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidResponse }
        title = try values.decode(String.self, forKey: .title)
        body = try values.decode(String.self, forKey: .body)
        let payload = try values.decodeIfPresent(Payload.self, forKey: .data)
        let key = try values.decodeIfPresent(String.self, forKey: .key)
        // Vendor inbox entries use `key` for these two provider actions.
        if key == "new_order" || key == "settlement_request" {
            type = key
        } else {
            type = try payload?.type
                ?? values.decodeIfPresent(String.self, forKey: .type)
                ?? values.decodeIfPresent(String.self, forKey: .dataType)
                ?? key
        }
        isClickable = try values.decodeIfPresent(Bool.self, forKey: .isClickable) ?? false
        couponID = try values.positiveIdentifierIfPresent(.couponID) ?? payload?.couponID
        orderID = try values.positiveIdentifierIfPresent(.orderID) ?? payload?.orderID
        createdAt = try values.decode(String.self, forKey: .createdAt)
        if let flag = try? values.decode(Bool.self, forKey: .isRead) {
            isRead = flag
        } else if let flag = try? values.decode(Int.self, forKey: .isRead), [0, 1].contains(flag) {
            isRead = flag == 1
        } else if let flag = try? values.decode(String.self, forKey: .isRead),
                  ["true", "false", "0", "1"].contains(flag.lowercased()) {
            isRead = flag == "1" || flag.lowercased() == "true"
        } else if values.contains(.readAt) {
            isRead = !(try values.decodeIfPresent(String.self, forKey: .readAt) ?? "").isEmpty
        } else {
            isRead = nil
        }
    }
}

struct MerchantNotificationPagination: Decodable, Equatable {
    let totalItems: Int
    let countItems: Int
    let perPage: Int
    let totalPages: Int
    let currentPage: Int
    var hasMore: Bool { currentPage < totalPages }

    private enum CodingKeys: String, CodingKey {
        case totalItems = "total_items", countItems = "count_items", perPage = "per_page"
        case totalPages = "total_pages", currentPage = "current_page"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalItems = try values.nonnegativeInteger(.totalItems)
        countItems = try values.nonnegativeInteger(.countItems)
        perPage = try values.nonnegativeInteger(.perPage)
        totalPages = try values.nonnegativeInteger(.totalPages)
        currentPage = try values.nonnegativeInteger(.currentPage)
        guard perPage > 0, currentPage > 0 else { throw APIError.invalidResponse }
    }
    // Pagination URLs in the examples reference localhost. Always request pages on our configured origin.
}

struct MerchantNotificationPage: Decodable, Equatable {
    let notifications: [MerchantNotification]
    let pagination: MerchantNotificationPagination
    var hasMore: Bool { pagination.hasMore }

    private enum CodingKeys: String, CodingKey { case notifications, pagination, data }
    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: CodingKeys.self)
        // The saved examples include both data.{pagination,data} and data.notifications.{pagination,data}.
        let values = try root.contains(.notifications)
            ? root.nestedContainer(keyedBy: CodingKeys.self, forKey: .notifications) : root
        pagination = try values.decode(MerchantNotificationPagination.self, forKey: .pagination)
        notifications = try values.decode([MerchantNotification].self, forKey: .data)
        guard pagination.countItems == notifications.count, pagination.totalItems >= notifications.count,
              notifications.count <= pagination.perPage,
              notifications.isEmpty || pagination.currentPage <= pagination.totalPages else {
            throw APIError.invalidResponse
        }
        // An empty page beyond totalPages is valid: the collection explicitly includes that response.
    }
}

struct MerchantNotificationCount: Decodable {
    let count: Int
    enum CodingKeys: String, CodingKey { case count }
    init(from decoder: Decoder) throws {
        count = try decoder.container(keyedBy: CodingKeys.self).nonnegativeInteger(.count)
    }
}

private extension KeyedDecodingContainer {
    func positiveIdentifierIfPresent(_ key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        let number = try nonnegativeInteger(key)
        return number > 0 ? String(number) : nil
    }

    func nonnegativeInteger(_ key: Key) throws -> Int {
        let number: Int
        if let value = try? decode(Int.self, forKey: key) { number = value }
        else {
            guard let value = Int(try decode(String.self, forKey: key)) else { throw APIError.invalidResponse }
            number = value
        }
        guard number >= 0 else { throw APIError.invalidResponse }
        return number
    }
}

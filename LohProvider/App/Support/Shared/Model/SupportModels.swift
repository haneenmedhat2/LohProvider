import Foundation

struct MerchantSupportText {
    let english: String
    let arabic: String
    init(_ english: String, _ arabic: String) { self.english = english; self.arabic = arabic }
    init(verbatim: String) { self.init(verbatim, verbatim) }
    func value(arabic: Bool) -> String { arabic ? self.arabic : english }
}

struct MerchantTicketMessage: Identifiable {
    let id = UUID()
    let fromSupport: Bool
    let text: MerchantSupportText
    let date: Date
}

struct MerchantSupportTicket: Identifiable {
    let id: String
    let name: String
    let phone: String
    let title: MerchantSupportText
    let detail: MerchantSupportText
    let created: Date?
    var createdText: String? = nil
    let isOpen: Bool?
    var status: String? = nil
    var statusText: String? = nil
    let messages: [MerchantTicketMessage]
    var typeName: String? = nil
    var orderID: String? = nil

    func createdLabel(arabic: Bool) -> String? {
        created.map { merchantTicketDate($0, arabic: arabic) } ?? createdText
    }

    func statusLabel(arabic: Bool) -> String? {
        if let statusText, !statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return statusText }
        guard let isOpen else { return nil }
        return isOpen ? (arabic ? "مفتوح" : "Open") : (arabic ? "مغلق" : "Closed")
    }
}

struct MerchantTicketDraft {
    var typeID = ""
    var orderID: String? = nil
    var title = ""
    var detail = ""
    enum Field: String, CaseIterable { case type, order, title, detail }
    func error(for field: Field) -> String? {
        switch field {
        case .type: return MerchantTicketType.validID(typeID) ? nil : "support_required"
        case .order: return (orderID.map(MerchantTicketType.validID) ?? true) ? nil : "support_order_invalid"
        case .title:
            let length = title.trimmingCharacters(in: .whitespacesAndNewlines).count
            return length == 0 ? "support_required" : length > 191 ? "support_title_limit" : nil
        case .detail:
            let length = detail.trimmingCharacters(in: .whitespacesAndNewlines).count
            return length == 0 ? "support_required" : length < 2 ? "support_detail_min" : length > 1000 ? "support_detail_limit" : nil
        }
    }
    var isValid: Bool { Field.allCases.allSatisfy { error(for: $0) == nil } }
}


extension MerchantSupportTicket {
    /// Accept a direct list or common resource/paginator wrappers.
    /// Unknown structures fail visibly instead of masquerading as an empty list.
    static func list(from response: MerchantSupportResponse) throws -> [Self] {
        func rows(_ data: MerchantSupportJSON?, depth: Int = 0) throws -> [MerchantSupportJSON] {
            guard let data, depth < 4 else { throw APIError.invalidResponse }
            if case .array(let values) = data { return values }
            for key in ["tickets", "support_tickets", "data"] {
                if let nested = data[key] { return try rows(nested, depth: depth + 1) }
            }
            throw APIError.invalidResponse
        }
        let tickets = try rows(response.data).map { row -> Self in
            guard let id = row["id"]?.supportString, !id.isEmpty,
                  id.allSatisfy({ $0.isASCII && $0.isNumber }), id.contains(where: { $0 != "0" }),
                  case .string(let title) = row["title"] ?? row["name"] else { throw APIError.invalidResponse }
            let createdText = row["created_at"]?.supportString
            let created = createdText.flatMap { value -> Date? in
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso.date(from: value) { return date }
                iso.formatOptions = [.withInternetDateTime]
                if let date = iso.date(from: value) { return date }
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.isLenient = false
                guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
                return date
            }
            let isOpen: Bool?
            if case .bool(let value) = row["is_closed"] { isOpen = !value }
            else if case .bool(let value) = row["is_open"] { isOpen = value }
            else {
                switch row["status"]?.supportString?.lowercased() {
                case "open": isOpen = true
                case "closed": isOpen = false
                default: isOpen = nil // Numeric status meanings are not documented.
                }
            }
            return Self(id: id, name: row["user_name"]?.supportString ?? "", phone: row["phone"]?.supportString ?? "",
                        title: .init(verbatim: title), detail: .init(verbatim: row["description"]?.supportString ?? row["complaint"]?.supportString ?? ""),
                        created: created, createdText: createdText, isOpen: isOpen,
                        status: row["status"]?.supportString, statusText: row["status_text"]?.supportString, messages: [],
                        typeName: row["ticket_type"]?["name"]?.supportString,
                        orderID: row["order_id"]?.supportString)
        }
        guard Set(tickets.map(\.id)).count == tickets.count else { throw APIError.invalidResponse }
        return tickets
    }
}

private extension MerchantSupportJSON {
    var supportString: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return NSDecimalNumber(decimal: value).stringValue
        default: return nil
        }
    }
}

func merchantTicketDate(_ date: Date, arabic: Bool) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_GB")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
    formatter.dateFormat = "d MMMM yyyy - hh:mm a"
    return formatter.string(from: date)
}

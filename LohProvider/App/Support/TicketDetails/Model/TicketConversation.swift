import Foundation

/// Vendor ticket detail supplied on 29 October 2026. The outer permission and
/// message page take precedence over the ticket's legacy message preview.
struct MerchantTicketConversation {
    let ticket: MerchantSupportTicket
    let reference: String
    let roomID: String?
    let canReply: Bool
    let messages: [MerchantChatMessage]
    let currentPage: Int
    let totalPages: Int

    init(response: MerchantSupportResponse, ticketID: String) throws {
        guard let data = response.data, let item = data["ticket"],
              item["id"]?.chatID == ticketID, let title = item["title"]?.chatString,
              let description = item["description"]?.chatString,
              let status = item["status"]?.chatString else { throw APIError.invalidResponse }
        let closed = item["is_closed"]?.chatBool == true || status == "closed"
        let created = item["created_at"]?.chatString
        ticket = .init(id: ticketID, name: item["user_name"]?.chatString ?? "",
                       phone: item["phone"]?.chatString ?? "", title: .init(verbatim: title),
                       detail: .init(verbatim: description), created: created.flatMap(merchantChatDate),
                       createdText: created, isOpen: !closed, status: status,
                       statusText: item["status_text"]?.chatString, messages: [],
                       typeName: item["ticket_type"]?["name"]?.chatString,
                       orderID: item["order_id"]?.chatString)
        reference = item["ticket_code"]?.chatString ?? item["ticket_num"]?.chatString ?? "#" + ticketID
        let rooms = [data["room"]?["id"], item["room"]?["id"], item["room_id"]]
            .filter { $0 != nil && $0 != .null }
        let ids = try rooms.map { value -> String in
            guard let id = value?.chatID else { throw APIError.invalidResponse }
            return id
        }
        guard Set(ids).count <= 1 else { throw APIError.invalidResponse }
        roomID = ids.first
        canReply = !closed && (data["can_reply"]?.chatBool ?? item["can_user_reply"]?.chatBool ?? false)

        if let page = data["messages"] {
            guard case .array(let rows) = page["data"], let pagination = page["pagination"],
                  let current = pagination["current_page"]?.chatInt,
                  let total = pagination["total_pages"]?.chatInt,
                  current > 0, total >= current else { throw APIError.invalidResponse }
            messages = try rows.map { try MerchantChatMessage(json: $0) }
            currentPage = current; totalPages = total
        } else if case .array(let rows) = item["messages"] {
            messages = try rows.map { try MerchantChatMessage(json: $0, allowsDescriptionID: true) }
            currentPage = 1; totalPages = 1
        } else {
            throw APIError.invalidResponse
        }
        guard Set(messages.map(\.id)).count == messages.count else { throw APIError.invalidResponse }
    }
}

struct MerchantChatMessage: Identifiable, Equatable {
    let id: String
    let body: String
    let isSender: Bool
    let type: String
    let createdAt: String?
    let relativeDate: String?
    var date: Date? { createdAt.flatMap(merchantChatDate) }

    init(json: MerchantSupportJSON, allowsDescriptionID: Bool = false) throws {
        guard let id = json["id"]?.chatID ?? (allowsDescriptionID && json["id"]?.chatString == "0" ? "description" : nil),
              let body = json["body"]?.chatString else { throw APIError.invalidResponse }
        self.id = id; self.body = body
        if let sender = json["is_sender"]?.chatBool { isSender = sender }
        else if let sender = json["sender"]?.chatString, ["user", "admin", "support"].contains(sender) {
            isSender = sender == "user"
        } else { throw APIError.invalidResponse }
        type = json["type"]?.chatString ?? "text"
        createdAt = json["created_at"]?.chatString
        relativeDate = json["created_dt"]?.chatString
    }

    init(sent: MerchantSupportSentMessage) {
        // History IDs identify the recipient record, not original_message.id.
        id = sent.id; body = sent.originalMessage.body; isSender = sent.isSender
        type = sent.originalMessage.type; createdAt = sent.originalMessage.createdAt; relativeDate = nil
    }

    func dateLabel(arabic: Bool) -> String {
        date.map { merchantTicketDate($0, arabic: arabic) } ?? relativeDate ?? createdAt ?? ""
    }

    static func ordered(_ messages: [Self]) -> [Self] {
        var unique: [String: Self] = [:]
        for message in messages { unique[message.id] = message }
        return unique.values.sorted {
            let left = $0.date ?? .distantPast, right = $1.date ?? .distantPast
            if left != right { return left < right }
            return $0.id.compare($1.id, options: .numeric) == .orderedAscending
        }
    }
}

extension MerchantSupportJSON {
    var chatString: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return NSDecimalNumber(decimal: value).stringValue
        default: return nil
        }
    }
    var chatID: String? {
        guard let value = chatString, !value.isEmpty,
              value.allSatisfy({ $0.isASCII && $0.isNumber }), value.contains(where: { $0 != "0" }) else { return nil }
        return value
    }
    var chatInt: Int? { chatString.flatMap(Int.init) }
    var chatBool: Bool? {
        if case .bool(let value) = self { return value }
        switch chatString { case "1": return true; case "0": return false; default: return nil }
    }
}

func merchantChatDate(_ value: String) -> Date? {
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
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
    return date
}

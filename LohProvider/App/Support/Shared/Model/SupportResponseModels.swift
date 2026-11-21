import Foundation

/// Preserves support envelopes for the list and feature-specific detail decoders.
enum MerchantSupportJSON: Decodable, Equatable {
    case object([String: MerchantSupportJSON]), array([MerchantSupportJSON])
    case string(String), number(Decimal), bool(Bool), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Decimal.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let array = try? value.decode([MerchantSupportJSON].self) { self = .array(array) }
        else { self = .object(try value.decode([String: MerchantSupportJSON].self)) }
    }

    subscript(key: String) -> MerchantSupportJSON? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }
}

/// Creation returns a message without data in the supplied Postman screenshot.
/// Ticket details are interpreted by MerchantTicketConversation; creation and
/// the legacy start-chat service can still return only a success message.
struct MerchantSupportResponse: Decodable, Equatable {
    let message: String?
    let data: MerchantSupportJSON?

    private enum CodingKeys: String, CodingKey { case msg, message, data }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        message = try values.decodeIfPresent(String.self, forKey: .msg)
            ?? values.decodeIfPresent(String.self, forKey: .message)
        data = try values.decodeIfPresent(MerchantSupportJSON.self, forKey: .data)
    }
}

struct MerchantTicketType: Decodable, Identifiable, Equatable {
    let id: String
    let name: String

    private enum CodingKeys: String, CodingKey { case id, name }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? values.decode(UInt64.self, forKey: .id) { id = String(number) }
        else { id = try values.decode(String.self, forKey: .id) }
        name = try values.decode(String.self, forKey: .name)
        guard Self.validID(id), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidResponse
        }
    }

    init(id: String, name: String) { self.id = id; self.name = name }

    static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy({ $0.isASCII && $0.isNumber }) && value.contains(where: { $0 != "0" })
    }
}

struct MerchantTicketOrder: Decodable, Identifiable, Equatable {
    let id: String
    let orderNumber: String

    private enum CodingKeys: String, CodingKey { case id, orderNumber = "order_num" }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? values.decode(UInt64.self, forKey: .id) { id = String(number) }
        else { id = try values.decode(String.self, forKey: .id) }
        orderNumber = try values.decode(String.self, forKey: .orderNumber)
        guard MerchantTicketType.validID(id),
              !orderNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidResponse
        }
    }

    init(id: String, orderNumber: String) { self.id = id; self.orderNumber = orderNumber }
}

enum MerchantSupportPhone {
    static func digits(_ value: String) -> String {
        value.compactMap { $0.wholeNumberValue }.map(String.init).joined()
    }

    static func isValid(_ value: String) -> Bool {
        let digits = digits(value)
        guard value.allSatisfy({ $0.wholeNumberValue != nil || $0.isWhitespace }) else { return false }
        return digits.count == MerchantPhoneInput.maxDigits && digits.hasPrefix("5")
    }
}

struct MerchantSupportRequest {
    let typeID: String
    let orderID: String?
    let title: String
    let description: String

    func formFields() throws -> [String: String] {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MerchantTicketType.validID(typeID), (1...191).contains(title.count),
              (2...1_000).contains(description.count),
              orderID.map(MerchantTicketType.validID) ?? true else { throw APIError.configuration }
        var fields = ["ticket_type_id": typeID, "title": title, "description": description]
        if let orderID { fields["order_id"] = orderID }
        return fields
    }
}

/// Matches the saved Send Message success response, including its nested original_message.
struct MerchantSupportSentMessage: Decodable, Equatable, Identifiable {
    let id: String
    let messageID: String
    let roomID: String
    let isSender: Bool
    let isSeen: Bool
    let originalMessage: MerchantSupportMessage

    private enum CodingKeys: String, CodingKey {
        case id, messageID = "message_id", roomID = "room_id"
        case isSender = "is_sender", isSeen = "is_seen", originalMessage = "original_message"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.supportID(.id)
        messageID = try values.supportID(.messageID)
        roomID = try values.supportID(.roomID)
        isSender = try values.supportFlag(.isSender)
        isSeen = try values.supportFlag(.isSeen)
        originalMessage = try values.decode(MerchantSupportMessage.self, forKey: .originalMessage)
        guard messageID == originalMessage.id, roomID == originalMessage.roomID else {
            throw APIError.invalidResponse
        }
    }
}

struct MerchantSupportMessage: Decodable, Equatable, Identifiable {
    let id: String
    let roomID: String
    let senderID: String
    let senderType: String
    let body: String
    let type: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id, roomID = "room_id", senderID = "senderable_id", senderType = "senderable_type"
        case body, type, createdAt = "created_at"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.supportID(.id)
        roomID = try values.supportID(.roomID)
        senderID = try values.supportID(.senderID)
        senderType = try values.decode(String.self, forKey: .senderType)
        body = try values.decode(String.self, forKey: .body)
        type = try values.decode(String.self, forKey: .type)
        createdAt = try values.decode(String.self, forKey: .createdAt)
    }
}

private extension KeyedDecodingContainer {
    func supportID(_ key: Key) throws -> String {
        let id: String
        if let number = try? decode(UInt64.self, forKey: key) { id = String(number) }
        else { id = try decode(String.self, forKey: key) }
        guard !id.isEmpty, id.allSatisfy({ $0.isASCII && $0.isNumber }), id.contains(where: { $0 != "0" }) else {
            throw APIError.invalidResponse
        }
        return id
    }

    func supportFlag(_ key: Key) throws -> Bool {
        if let flag = try? decode(Bool.self, forKey: key) { return flag }
        let flag = try decode(Int.self, forKey: key)
        guard flag == 0 || flag == 1 else { throw APIError.invalidResponse }
        return flag == 1
    }
}

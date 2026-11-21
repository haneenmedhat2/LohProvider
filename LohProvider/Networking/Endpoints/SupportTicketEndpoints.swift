import Foundation

struct SupportTicketEndpoints {
    private init() {}
}

extension SupportTicketEndpoints {
    static func types(token: String) -> Endpoint<APIEnvelope<[MerchantTicketType]>> {
        return Endpoint(path: "vendor/ticket-types", headerType: .authorized(token: token))
    }

    static func orders(token: String) -> Endpoint<APIEnvelope<[MerchantTicketOrder]>> {
        return Endpoint(path: "vendor/orders", headerType: .authorized(token: token))
    }

    static func create(fields: [String: String], token: String) -> Endpoint<MerchantSupportResponse> {
        return Endpoint(
            method: .post,
            path: "vendor/send-ticket",
            body: fields.mapValues { $0 as Sendable? },
            bodyEncoding: .multipart,
            headerType: .authorized(token: token)
        )
    }

    static func tickets(token: String) -> Endpoint<MerchantSupportResponse> {
        return Endpoint(path: "vendor/my-tickets", queries: ["status": "all"], headerType: .authorized(token: token))
    }

    static func ticket(id: String, page: Int, pageSize: Int = 20, token: String) -> Endpoint<MerchantSupportResponse> {
        return Endpoint(
            path: "vendor/my-tickets/" + id,
            queries: ["page": page, "paginate": pageSize],
            headerType: .authorized(token: token)
        )
    }

    static func startChat(ticketID: String, token: String) -> Endpoint<MerchantSupportResponse> {
        return Endpoint(
            method: .post,
            path: "vendor/support-tickets/" + ticketID + "/start-chat",
            body: [:],
            bodyEncoding: .multipart,
            headerType: .authorized(token: token)
        )
    }

    static func sendMessage(roomID: String, message: String, token: String) -> Endpoint<APIEnvelope<MerchantSupportSentMessage>> {
        return Endpoint(
            method: .post,
            path: "vendor/send-message/" + roomID,
            body: ["message": message],
            bodyEncoding: .multipart,
            headerType: .authorized(token: token)
        )
    }
}

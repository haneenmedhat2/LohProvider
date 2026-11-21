import Foundation

@MainActor private final class SupportTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var response = HTTPResponse(statusCode: 200, data: Data())
    var failure: Error?
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        if let failure { throw failure }
        return response
    }
    func respond(_ json: String, status: Int = 200) {
        failure = nil
        response = .init(statusCode: status, data: Data(json.utf8))
    }
}

@main struct MerchantSupportAPIChecks {
    // Synthetic values follow the collection's saved Send Message response.
    private static let sentMessage = #"{"key":"success","msg":"Sent","data":{"id":21,"message_id":15,"room_id":3,"userable_id":64,"userable_type":"App\\Models\\User","is_flagged":0,"is_seen":1,"is_sender":1,"created_at":"2025-02-17T00:27:25.000000Z","original_message":{"id":15,"room_id":3,"senderable_id":64,"senderable_type":"App\\Models\\User","body":"Hello","type":"text","name":null,"duration":0,"created_at":"2025-02-17T00:27:25.000000Z"}}}"#

    @MainActor static func main() async throws {
        let transport = SupportTransport()
        var language = "ar"
        var unauthorized: String?
        let client = DefaultResponseHandler(transport: transport, language: { language }, logger: .init(output: { _ in }))
        client.onUnauthorized = { unauthorized = $0 }
        let service = MerchantSupportService(client: client)

        transport.respond(#"{"key":"success","data":[{"id":3,"name":"General issue"},{"id":"4","name":"Order issue"}]}"#)
        let types = try await service.ticketTypes(token: "support-token")
        precondition(types.map(\.id) == ["3", "4"] && types[1].name == "Order issue")
        checkRequest(transport, path: "ticket-types", method: "GET", language: "ar")
        precondition(transport.requests.last!.httpBody == nil)

        transport.respond(##"{"key":"success","data":[{"id":921,"order_num":"#LOH-2026921"},{"id":"920","order_num":"#LOH-2026920"}]}"##)
        let orders = try await service.ticketOrders(token: "support-token")
        precondition(orders.map(\.id) == ["921", "920"] && orders[0].orderNumber == "#LOH-2026921")
        checkRequest(transport, path: "orders", method: "GET", language: "ar")
        precondition(transport.requests.last!.httpBody == nil)

        transport.respond(#"{"key":"success","msg":"تم ارسال \"الشكوى / المقترح\" بنجاح"}"#)
        let request = MerchantSupportRequest(typeID: "3", orderID: "17", title: "  Offer issue  ", description: "  Cannot redeem & retry\nتفاصيل  ")
        let created = try await service.createTicket(request, token: "support-token")
        precondition(created.message == "تم ارسال \"الشكوى / المقترح\" بنجاح" && created.data == nil, "Do not invent a ticket ID when none was returned")
        checkRequest(transport, path: "send-ticket", method: "POST", language: "ar")
        let form = String(data: transport.requests.last!.httpBody!, encoding: .utf8)!
        for (key, value) in ["ticket_type_id": "3", "order_id": "17", "title": "Offer issue", "description": "Cannot redeem & retry\nتفاصيل"] {
            precondition(form.contains("name=\"\(key)\"\r\n\r\n\(value)\r\n"))
        }
        precondition(form.components(separatedBy: "Content-Disposition:").count == 5)
        _ = try await service.createTicket(.init(typeID: "3", orderID: nil, title: "Title", description: "Details"), token: "support-token")
        let noOrderForm = String(data: transport.requests.last!.httpBody!, encoding: .utf8)!
        precondition(!noOrderForm.contains("name=\"order_id\""))

        // Preserve the my-tickets counts and ticket payload for the list decoder.
        language = "en"
        transport.respond(#"{"key":"success","data":{"counts":{"all":0,"open":0,"closed":0},"tickets":[]}}"#)
        let empty = try await service.tickets(token: "support-token")
        precondition(empty.data?["tickets"] == .array([]))
        checkRequest(transport, path: "my-tickets?status=all", method: "GET", language: "en")
        precondition(transport.requests.last!.httpBody == nil)
        transport.respond(#"{"key":"success","data":{"tickets":[{"id":9007199254740993,"extra":null}],"enabled":true,"label":"Open","value":1.25}}"#)
        let list = try await service.tickets(token: "support-token")
        precondition(list.data?["enabled"] == .bool(true) && list.data?["label"] == .string("Open"))
        precondition(list.data?["value"] == .number(Decimal(string: "1.25")!))
        precondition(list.data?["tickets"] == .array([.object(["id": .number(Decimal(string: "9007199254740993")!), "extra": .null])]))
        let detail = try await service.ticket(id: "7", token: "support-token")
        precondition(detail == list)
        checkRequest(transport, path: "my-tickets/7?page=1&paginate=20", method: "GET", language: "en")

        transport.respond(#"{"key":"success","msg":"Chat started","data":{"unconfirmed_room_field":{"id":3}}}"#)
        let chat = try await service.startChat(ticketID: "7", token: "support-token")
        precondition(chat.data?["unconfirmed_room_field"] == .object(["id": .number(3)]))
        checkRequest(transport, path: "support-tickets/7/start-chat", method: "POST", language: "en")
        let start = transport.requests.last!
        precondition(start.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
        precondition(!String(data: start.httpBody!, encoding: .utf8)!.contains("Content-Disposition:"))
        transport.respond(#"{"key":"success","msg":"Chat started","data":null}"#)
        let noChatData = try await service.startChat(ticketID: "7", token: "support-token")
        precondition(noChatData.data == nil && noChatData.message == "Chat started")

        transport.respond(sentMessage)
        let sent = try await service.sendMessage(conversationID: "3", message: "  Hello\nمرحبا  ", token: "support-token")
        checkRequest(transport, path: "send-message/3", method: "POST", language: "en")
        precondition(String(data: transport.requests.last!.httpBody!, encoding: .utf8)!.contains("name=\"message\"\r\n\r\n  Hello\nمرحبا  \r\n"))
        precondition(sent.id == "21" && sent.messageID == "15" && sent.roomID == "3" && sent.isSender && sent.isSeen)
        precondition(sent.originalMessage.body == "Hello" && sent.originalMessage.senderID == "64")
        precondition(sent.originalMessage.createdAt == "2025-02-17T00:27:25.000000Z")
        transport.respond(sentMessage.replacingOccurrences(of: "\"id\":21", with: "\"id\":\"21\"")
            .replacingOccurrences(of: "\"is_seen\":1", with: "\"is_seen\":false"))
        let variants = try await service.sendMessage(conversationID: "3", message: "Hello", token: "support-token")
        precondition(variants.id == "21" && !variants.isSeen)

        let count = transport.requests.count
        for invalid in ["", "0", "-1", "1/2", "../3", "3?x=1", "3#x", "%31", "٣", "3\n"] {
            await expect(.configuration) { _ = try await service.ticket(id: invalid, token: "support-token") }
            await expect(.configuration) { _ = try await service.startChat(ticketID: invalid, token: "support-token") }
            await expect(.configuration) { _ = try await service.sendMessage(conversationID: invalid, message: "Hi", token: "support-token") }
        }
        for invalid in ["", "  \n"] {
            await expect(.configuration) { _ = try await service.sendMessage(conversationID: "3", message: invalid, token: "support-token") }
        }
        for invalid in [MerchantSupportRequest(typeID: "", orderID: nil, title: "Title", description: "Details"),
                        .init(typeID: "0", orderID: nil, title: "Title", description: "Details"),
                        .init(typeID: "٣", orderID: nil, title: "Title", description: "Details"),
                        .init(typeID: "3", orderID: "0", title: "Title", description: "Details"),
                        .init(typeID: "3", orderID: "1/2", title: "Title", description: "Details"),
                        .init(typeID: "3", orderID: nil, title: String(repeating: "a", count: 192), description: "Details"),
                        .init(typeID: "3", orderID: nil, title: "Title", description: String(repeating: "a", count: 1001)),
                        .init(typeID: "3", orderID: nil, title: " ", description: "Details"),
                        .init(typeID: "3", orderID: nil, title: "Title", description: "x")] {
            await expect(.configuration) { _ = try await service.createTicket(invalid, token: "support-token") }
        }
        precondition(transport.requests.count == count, "Invalid inputs must fail before transport")

        for invalid in [#"{"key":"success"}"#, #"{"key":"success","data":null}"#, "<html>bad gateway</html>"] {
            transport.respond(invalid)
            await expect(.invalidResponse) { _ = try await service.tickets(token: "support-token") }
        }
        transport.respond(sentMessage.replacingOccurrences(of: "\"message_id\":15", with: "\"message_id\":16"))
        await expect(.invalidResponse) { _ = try await service.sendMessage(conversationID: "3", message: "Hi", token: "support-token") }
        transport.respond(#"{"key":"fail","msg":"Ticket closed"}"#)
        let beforeFailure = transport.requests.count
        await expect(.server(message: "Ticket closed", fields: [:])) { _ = try await service.startChat(ticketID: "7", token: "support-token") }
        precondition(transport.requests.count == beforeFailure + 1, "Mutations must not be automatically retried")
        transport.respond(#"{"message":"Invalid type","errors":{"ticket_type_id":["Invalid"]}}"#, status: 422)
        await expect(.server(message: "Invalid type", fields: ["ticket_type_id": ["Invalid"]])) { _ = try await service.createTicket(request, token: "support-token") }
        transport.respond("", status: 401)
        await expect(.unauthenticated(nil)) { _ = try await service.tickets(token: "expired-token") }
        precondition(unauthorized == "expired-token")
        transport.respond(#"{"key":"blocked","msg":"Account blocked"}"#)
        await expect(.unauthenticated("Account blocked")) { _ = try await service.startChat(ticketID: "7", token: "blocked-token") }
        precondition(unauthorized == "blocked-token")
        transport.failure = URLError(.notConnectedToInternet)
        await expect(.offline) { _ = try await service.tickets(token: "support-token") }
        transport.failure = URLError(.cancelled)
        do { _ = try await service.createTicket(request, token: "support-token"); preconditionFailure("Cancellation swallowed") }
        catch is CancellationError {}
        print("Passed: ticket types, vendor/send-ticket fields, support reads/chat, authentication, validation, failures, and cancellation.")
    }

    @MainActor private static func checkRequest(_ transport: SupportTransport, path: String, method: String, language: String) {
        let request = transport.requests.last!
        precondition(request.url?.absoluteString == "https://upgrade.loh.com.sa/api/vendor/" + path)
        precondition(request.httpMethod == method)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer support-token")
        precondition(request.value(forHTTPHeaderField: "lang") == language)
    }
    @MainActor private static func expect(_ expected: APIError, operation: () async throws -> Void) async {
        do { try await operation(); preconditionFailure("Expected API failure") }
        catch { precondition(error as? APIError == expected, "Unexpected error: \(error)") }
    }
}

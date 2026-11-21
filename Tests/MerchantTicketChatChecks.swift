import Foundation

@MainActor private final class TicketChatTransport: HTTPTransport {
    var detail: String
    var pageTwo: String?
    var sent = #"{"key":"success","data":{"id":8,"message_id":5,"room_id":3,"is_sender":1,"is_seen":0,"original_message":{"id":5,"room_id":3,"senderable_id":78,"senderable_type":"App\\Models\\Provider","body":"Reply","type":"text","created_at":"2026-10-29T10:00:00.000000Z"}}}"#
    var requests: [URLRequest] = []
    var holdNext = false
    var gates: [CheckedContinuation<Void, Never>] = []
    var failure: Error?
    init(_ detail: String) { self.detail = detail }
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        let body = request.url!.path.contains("send-message") ? sent :
            (request.url!.query == "page=2&paginate=20" ? pageTwo ?? detail : detail)
        let failure = self.failure; self.failure = nil
        if holdNext {
            holdNext = false
            await withCheckedContinuation { gates.append($0) }
        }
        if let failure { throw failure }
        return .init(statusCode: 200, data: Data(body.utf8))
    }
    func release() { gates.removeFirst().resume() }
}

@main struct MerchantTicketChatChecks {
    @MainActor static func main() async throws {
        let fixture = try String(contentsOfFile: "Tests/Fixtures/MerchantTicketDetail.json", encoding: .utf8)
        let decoded = try decode(fixture)
        precondition(decoded.ticket.id == "51" && decoded.roomID == "3" && decoded.canReply)
        precondition(decoded.messages.count == 1 && decoded.messages[0].id == "7", "Outer history replaces legacy description ID 0")
        precondition(decoded.messages[0].isSender && decoded.messages[0].date != nil)
        precondition(decoded.reference == "#LOH-2610292610292610290003")
        precondition(!decoded.messages[0].dateLabel(arabic: true).isEmpty)

        let closed = try edit(fixture) { data in
            var ticket = data["ticket"] as! [String: Any]
            ticket["is_closed"] = true; data["ticket"] = ticket
        }
        let closedResult = try decode(closed)
        precondition(!closedResult.canReply, "Closed overrides can_reply true")
        let readOnly = try edit(fixture) { $0["can_reply"] = false }
        let readOnlyResult = try decode(readOnly)
        precondition(!readOnlyResult.canReply)
        let missingRoom = try edit(fixture) { data in
            data["room"] = NSNull()
            var ticket = data["ticket"] as! [String: Any]
            ticket["room"] = NSNull(); ticket["room_id"] = NSNull(); data["ticket"] = ticket
        }
        let missingRoomResult = try decode(missingRoom)
        precondition(missingRoomResult.roomID == nil, "Never use the ticket ID as the room ID")
        let conflictingRoom = try edit(fixture) { $0["room"] = ["id": 99] }
        do { _ = try decode(conflictingRoom); preconditionFailure("Mixed rooms accepted") }
        catch { precondition(error as? APIError == .invalidResponse) }

        let transport = TicketChatTransport(fixture)
        var token: String? = "test-ticket-token"
        let client = DefaultResponseHandler(transport: transport, language: { "ar" }, logger: .init(output: { _ in }))
        let service = MerchantSupportService(client: client)
        let model = MerchantTicketDetailViewModel(ticketID: "51", ticket: nil, service: service, token: { token })
        await model.reload()
        precondition(model.hasLoaded && model.canReply && model.messages.count == 1 && !model.isLoading)
        let request = transport.requests.last!
        precondition(request.url!.path == "/api/vendor/my-tickets/51" && request.url!.query == "page=1&paginate=20" && request.httpBody == nil)
        precondition(request.url!.scheme == "https" && (request.url!.port ?? 443) == 443)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-ticket-token")

        model.draft = "  Reply  "
        transport.holdNext = true
        let sending = Task { await model.send() }
        await wait { !transport.gates.isEmpty }
        precondition(model.isSending && !model.canSend)
        let posts = transport.requests.filter { $0.httpMethod == "POST" }.count
        await model.send()
        precondition(transport.requests.filter { $0.httpMethod == "POST" }.count == posts)
        let sendRequest = transport.requests.last!
        precondition(sendRequest.url!.path == "/api/vendor/send-message/3")
        precondition(String(data: sendRequest.httpBody!, encoding: .utf8)!.contains("name=\"message\"\r\n\r\nReply\r\n"))
        model.draft = "Next reply"
        transport.release(); await sending.value
        precondition(model.draft == "Next reply", "An in-flight send cannot erase newly typed text")
        precondition(model.messages.map(\.id) == ["7", "8"] && model.sendError == nil)

        transport.failure = URLError(.notConnectedToInternet)
        await model.send()
        precondition(model.sendError == .offline && model.draft == "Next reply")
        precondition(!model.isSending && model.messages.count == 2)
        transport.detail = try edit(fixture) { data in
            var messages = data["messages"] as! [String: Any]
            var rows = messages["data"] as! [[String: Any]]
            rows.append(["id":8,"body":"Reply","is_sender":true,"type":"text","created_at":"2026-10-29 13:00:00"])
            messages["data"] = rows; data["messages"] = messages
        }
        await model.reload()
        precondition(model.messages.map(\.id) == ["7", "8"], "HTTP send and history must not duplicate a message")

        // Pull-to-refresh cancellation does not cancel the owned HTTP request.
        transport.holdNext = true
        let refresh = Task { await model.reload() }
        await wait { !transport.gates.isEmpty }
        refresh.cancel()
        precondition(model.isLoading && model.messages.count == 2)
        transport.release(); await refresh.value
        precondition(model.messages.count == 2 && model.error == nil && !model.isLoading)

        transport.detail = "{}"
        await model.reload()
        precondition(model.error == .invalidResponse && model.messages.count == 2)
        transport.detail = closed
        await model.reload()
        precondition(!model.canReply && !model.canSend)
        let count = transport.requests.count
        await model.send()
        precondition(transport.requests.count == count, "Closed tickets cannot send")
        transport.detail = missingRoom
        await model.reload()
        precondition(!model.canReply)

        transport.detail = try page(fixture, current: 1, total: 2, id: 7)
        transport.pageTwo = try page(fixture, current: 2, total: 2, id: 9)
        await model.reload()
        precondition(model.hasMore)
        transport.failure = URLError(.timedOut)
        await model.loadMore()
        precondition(model.pageError != nil && model.hasMore && model.messages.count == 1)
        await model.loadMore()
        precondition(!model.hasMore && model.messages.map(\.id) == ["7", "9"])
        precondition(transport.requests.last!.url!.query == "page=2&paginate=20")

        // Screen exit rejects responses even when the transport ignores cancellation.
        transport.holdNext = true
        let exiting = Task { await model.reload() }
        await wait { !transport.gates.isEmpty }
        model.stop(); transport.release(); await exiting.value
        precondition(!model.isLoading && model.messages.map(\.id) == ["7", "9"])
        model.activate(); transport.detail = fixture
        await model.reload()

        transport.holdNext = true
        let oldAccount = Task { await model.reload() }
        await wait { !transport.gates.isEmpty }
        token = "different-account"
        transport.detail = readOnly
        await model.reload()
        precondition(!model.canReply && model.draft.isEmpty)
        transport.release(); await oldAccount.value
        precondition(model.hasLoaded && !model.canReply, "Late old-account replies must not erase new state")

        token = "third-account"
        let beforeNewAccountSend = transport.requests.count
        model.draft = "Do not send an old ticket under a new account"
        await model.send()
        precondition(transport.requests.count == beforeNewAccountSend && model.messages.isEmpty && model.draft.isEmpty)
        token = nil
        await model.reload()
        precondition(model.ticket == nil && !model.hasLoaded && model.error == .unauthenticated(nil))
        print("Passed: supplied ticket schema, reply permission, room ID, HTTPS 443, message send, history deduplication, pagination, refresh cancellation, errors, drafts, screen exit and account isolation.")
    }

    private static func decode(_ json: String) throws -> MerchantTicketConversation {
        try .init(response: JSONDecoder().decode(MerchantSupportResponse.self, from: Data(json.utf8)), ticketID: "51")
    }
    private static func edit(_ json: String, _ update: (inout [String: Any]) -> Void) throws -> String {
        var envelope = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        var data = envelope["data"] as! [String: Any]; update(&data); envelope["data"] = data
        return String(data: try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]), encoding: .utf8)!
    }
    private static func page(_ json: String, current: Int, total: Int, id: Int) throws -> String {
        try edit(json) { data in
            data["messages"] = ["pagination":["current_page":current,"total_pages":total],
                                "data":[["id":id,"body":"Message", "is_sender":false,"created_at":"2026-10-29 12:25:03"]]]
        }
    }
    @MainActor private static func wait(_ condition: () -> Bool) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        preconditionFailure("Timed out waiting for request")
    }
}

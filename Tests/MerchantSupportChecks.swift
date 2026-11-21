import Foundation

@main
struct MerchantSupportChecks {
    @MainActor static func main() async throws {
        let store = MerchantSupportStore(tickets: [])
        var draft = MerchantTicketDraft()
        precondition(!draft.isValid)
        do { _ = try await store.submit(draft); preconditionFailure("Invalid draft accepted") }
        catch { precondition(error as? APIError == .configuration) }
        draft.typeID = "1"
        draft.orderID = "17"
        draft.title = "Test ticket"
        draft.detail = "My offer cannot be redeemed."
        precondition(draft.isValid)
        draft.typeID = "0"
        precondition(draft.error(for: .type) == "support_required")
        draft.typeID = "1"
        draft.orderID = "bad"
        precondition(draft.error(for: .order) == "support_order_invalid")
        draft.orderID = nil
        precondition(draft.isValid, "Related order must be optional")
        draft.orderID = "17"
        draft.title = String(repeating: "a", count: 192)
        precondition(!draft.isValid)
        draft.title = String(repeating: "a", count: 191)
        draft.detail = "x"
        precondition(draft.error(for: .detail) == "support_detail_min")
        draft.detail = String(repeating: "ب", count: 1001)
        precondition(!draft.isValid)
        draft.detail = String(repeating: "ب", count: 1000)
        precondition(draft.isValid)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ticket = try await store.submit(draft, now: now)
        precondition(ticket.name.isEmpty && ticket.phone.isEmpty && ticket.typeName == "General issue" && ticket.orderID == "17")
        precondition(ticket.isOpen == true && ticket.created == now && ticket.messages.count == 1)
        precondition(!ticket.messages[0].fromSupport, "New tickets must not contain fabricated support replies")
        precondition(ticket.title.value(arabic: true) == draft.title)
        precondition(store.ticket(ticket.id)?.detail.value(arabic: false) == draft.detail)
        let next = try await store.submit(draft)
        precondition(next.id != ticket.id && store.tickets.first?.id == next.id)
        let navigation = MerchantTabsCoordinator()
        navigation.account.path = [.support, .createTicket]
        navigation.account.path = navigation.account.path.filter { $0 != .createTicket } + [.supportSent(ticket.id)]
        precondition(navigation.account.path == [.support, .supportSent(ticket.id)])
        navigation.account.replace(with: .support)
        precondition(navigation.account.path == [.support])
        navigation.account.push(.ticketDetails(ticket.id))
        navigation.reset()
        precondition(navigation.account.path.isEmpty)
        try await checkLiveListAndSubmission(draft)
        try await checkCurrentResponse()
        print("Passed: support validation, list decoding, loading/retry/empty states, stale and cancelled requests, authenticated submission, and navigation.")
    }

    @MainActor static func checkCurrentResponse() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantSupportTickets.json"))
        let response = try JSONDecoder().decode(MerchantSupportResponse.self, from: data)
        let service = SupportStub()
        service.list = { _ in response }
        let store = MerchantSupportStore(service: service, token: { "session" })
        await store.reload()
        precondition(store.error == nil && store.hasLoaded && store.tickets.count == 4)
        precondition(store.tickets.map(\.id) == ["1", "2", "3", "4"])
        precondition(store.tickets.map(\.isOpen) == [true, false, false, false])
        let first = store.tickets[0]
        precondition(first.title.arabic == "مشكلة في استخدام العرض")
        precondition(first.detail.arabic == "عند محاولة استخدام العرض يظهر لي خطأ...")
        precondition(first.name.isEmpty, "Ticket name must not be interpreted as the sender's name")
        precondition(first.status == "open" && first.statusLabel(arabic: true) == "مفتوح")
        precondition(store.ticket("2")?.statusLabel(arabic: true) == "مغلق")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: first.created!)
        precondition(components.year == 2024 && components.month == 7 && components.day == 30)
        precondition(components.hour == 9 && components.minute == 41)
        let explicit = try MerchantSupportTicket.list(from: Self.response(#"[{"id":5,"name":"New title","title":"Legacy title","description":"New detail","complaint":"Legacy detail","is_open":false,"status":"open","status_text":"Resolved","created_at":"2024-02-30 09:41:00"}]"#))[0]
        precondition(explicit.title.english == "Legacy title" && explicit.detail.english == "New detail")
        precondition(explicit.isOpen == false && explicit.statusLabel(arabic: false) == "Resolved")
        precondition(explicit.created == nil && explicit.createdText == "2024-02-30 09:41:00")
        let myTickets = try MerchantSupportTicket.list(from: Self.response(##"{"counts":{"all":1,"open":1,"closed":0},"tickets":[{"id":64,"ticket_num":"LOH-2611032611032611030021","ticket_code":"#LOH-2611032611032611030021","title":"title","description":"new complaint","status":"open","status_text":"مفتوحة","is_closed":false,"can_user_reply":false,"order_id":null,"ticket_type_id":1,"ticket_type":{"id":1,"name":"مشكلة في استخدام العرض"},"room":{"id":25,"type":"support_ticket"},"room_id":25,"last_updated":"2026-11-03 16:08:57","created_at":"2026-11-03 16:08:57"}]}"##))
        precondition(myTickets.count == 1 && myTickets[0].id == "64")
        precondition(myTickets[0].title.english == "title" && myTickets[0].detail.english == "new complaint")
        precondition(myTickets[0].isOpen == true && myTickets[0].statusLabel(arabic: true) == "مفتوحة")
        precondition(myTickets[0].typeName == "مشكلة في استخدام العرض" && myTickets[0].orderID == nil)
        precondition(myTickets[0].created != nil)
        let closed = try MerchantSupportTicket.list(from: Self.response(#"{"tickets":[{"id":65,"title":"Closed ticket","is_closed":true,"status":"open"}]}"#))
        precondition(closed[0].isOpen == false && closed[0].statusLabel(arabic: false) == "Closed")
    }

    @MainActor static func checkLiveListAndSubmission(_ draft: MerchantTicketDraft) async throws {
        let service = SupportStub()
        var token: String? = "support-session"
        let store = MerchantSupportStore(service: service, token: { token })
        precondition(store.tickets.isEmpty && !store.hasLoaded)
        service.list = { token in
            precondition(token == "support-session" && store.isLoading && store.error == nil)
            return try response(#"[{"id":12,"title":"Offer problem","complaint":"Please help","user_name":"Merchant","phone":"0512345678","created_at":"2026-10-21T12:00:00.000Z","status":"open"}]"#)
        }
        await store.reload()
        precondition(store.hasLoaded && !store.isLoading && store.error == nil)
        precondition(store.tickets.count == 1 && store.tickets[0].id == "12")
        precondition(store.tickets[0].created != nil && store.tickets[0].isOpen == true)
        precondition(store.tickets[0].messages.isEmpty && store.ticket("12")?.detail.english == "Please help")

        for wrapper in [#"{"data":[]}"#, #"{"tickets":[]}"#, #"{"support_tickets":{"data":[]}}"#] {
            let rows = try MerchantSupportTicket.list(from: response(wrapper))
            precondition(rows.isEmpty)
        }
        let minimal = try MerchantSupportTicket.list(from: response(#"[{"id":"14","title":"Question","status":1,"created_at":"منذ ساعة"}]"#))[0]
        precondition(minimal.isOpen == nil && minimal.created == nil && minimal.createdLabel(arabic: true) == "منذ ساعة")
        for malformed in [#"{}"#, #"[{"title":"No ID"}]"#, #"[{"id":1}]"#,
                          #"[{"id":1,"title":"One"},{"id":"1","title":"Duplicate"}]"#] {
            do { _ = try MerchantSupportTicket.list(from: response(malformed)); preconditionFailure("Malformed list accepted") }
            catch { precondition(error as? APIError == .invalidResponse) }
        }
        service.list = { _ in throw APIError.offline }
        await store.reload()
        precondition(store.error == .offline && store.tickets.count == 1 && !store.isLoading)
        service.list = { _ in try response("[]") }
        await store.reload()
        precondition(store.hasLoaded && store.tickets.isEmpty && store.error == nil)

        var pending: CheckedContinuation<MerchantSupportResponse, Error>?
        service.list = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let old = Task { await store.reload() }
        while pending == nil { await Task.yield() }
        precondition(store.isLoading)
        service.list = { _ in try response(#"[{"id":2,"title":"Newest"}]"#) }
        await store.reload()
        pending!.resume(returning: try response(#"[{"id":1,"title":"Stale"}]"#))
        await old.value
        precondition(store.tickets.map(\.id) == ["2"] && !store.isLoading)

        pending = nil
        service.list = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let cancelled = Task { await store.reload() }
        while pending == nil { await Task.yield() }
        cancelled.cancel()
        pending!.resume(returning: try response("[]"))
        await cancelled.value
        precondition(store.tickets.map(\.id) == ["2"] && store.error == nil && !store.isLoading)

        pending = nil
        let changingAccount = Task { await store.reload() }
        while pending == nil { await Task.yield() }
        token = "new-session"
        pending!.resume(returning: try response(#"[{"id":3,"title":"Old account"}]"#))
        await changingAccount.value
        precondition(store.tickets.isEmpty && !store.hasLoaded && store.error == nil)
        token = nil
        let calls = service.listCalls
        await store.reload()
        precondition(service.listCalls == calls && store.error == .unauthenticated(nil))

        token = "new-session"
        await store.loadTicketTypes()
        await store.loadTicketOrders()
        precondition(store.ticketTypes.map(\.id) == ["1"] && !store.isLoadingTicketTypes)
        precondition(store.ticketOrders.map(\.id) == ["17"] && !store.isLoadingTicketOrders)
        service.creation = { request, token in
            precondition(token == "new-session" && request.typeID == draft.typeID && request.orderID == draft.orderID && request.description == draft.detail)
            precondition(store.isSubmitting)
            return try JSONDecoder().decode(MerchantSupportResponse.self, from: Data(#"{"key":"success","msg":"تم ارسال الشكوى بنجاح"}"#.utf8))
        }
        let receipt = try await store.submit(draft)
        precondition(!store.isSubmitting && store.ticket(receipt.id) != nil)
        precondition(store.tickets.isEmpty, "A message-only creation response must not invent a server ticket ID")
        service.creation = { _, _ in throw APIError.offline }
        do { _ = try await store.submit(draft); preconditionFailure("Failed creation accepted") }
        catch { precondition(error as? APIError == .offline && !store.isSubmitting) }
    }

    static func response(_ data: String) throws -> MerchantSupportResponse {
        try JSONDecoder().decode(MerchantSupportResponse.self, from: Data("{\"key\":\"success\",\"data\":\(data)}".utf8))
    }
}

@MainActor private final class SupportStub: MerchantSupportServicing {
    var listCalls = 0
    var list: (String) async throws -> MerchantSupportResponse = { _ in fatalError("Unexpected list request") }
    var creation: (MerchantSupportRequest, String) async throws -> MerchantSupportResponse = { _, _ in fatalError("Unexpected creation") }
    var types: (String) async throws -> [MerchantTicketType] = { _ in [.init(id: "1", name: "General issue")] }
    var orders: (String) async throws -> [MerchantTicketOrder] = { _ in [.init(id: "17", orderNumber: "#LOH-202617")] }
    func ticketTypes(token: String) async throws -> [MerchantTicketType] { try await types(token) }
    func ticketOrders(token: String) async throws -> [MerchantTicketOrder] { try await orders(token) }
    func tickets(token: String) async throws -> MerchantSupportResponse {
        listCalls += 1
        return try await list(token)
    }
    func createTicket(_ request: MerchantSupportRequest, token: String) async throws -> MerchantSupportResponse {
        try await creation(request, token)
    }
    func ticket(id: String, token: String) async throws -> MerchantSupportResponse { fatalError("Unexpected details request") }
    func startChat(ticketID: String, token: String) async throws -> MerchantSupportResponse { fatalError("Unexpected chat request") }
    func sendMessage(conversationID: String, message: String, token: String) async throws -> MerchantSupportSentMessage { fatalError("Unexpected message") }
}

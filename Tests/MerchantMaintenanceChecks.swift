import Foundation

@MainActor
private final class MaintenanceTransport: HTTPTransport {
    var responses: [HTTPResponse]
    var requests: [URLRequest] = []

    init(_ responses: [HTTPResponse]) { self.responses = responses }

    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw APIError.offline }
        return responses.removeFirst()
    }
}

@main
struct MerchantMaintenanceChecks {
    struct Value: Decodable { let count: Int }

    @MainActor static func main() async throws {
        for data in ["missing", "null", "[]", "{}"] {
            let maintenanceJSON: Data
            if data == "missing" {
                maintenanceJSON = Data(#"{"key":"maintenance_mode","msg":"maintenance"}"#.utf8)
            } else {
                maintenanceJSON = Data("{\"key\":\"maintenance_mode\",\"msg\":\"maintenance\",\"data\":".utf8)
                    + Data(data.utf8) + Data("}".utf8)
            }
            let maintenance = MerchantMaintenanceViewModel()
            let transport = MaintenanceTransport([
                .init(statusCode: 200, data: maintenanceJSON),
                .init(statusCode: 200, data: Data(#"{"key":"success","data":{}}"#.utf8)),
                .init(statusCode: 200, data: Data(#"{"key":"success","data":{"count":7}}"#.utf8))
            ])
            let client = DefaultResponseHandler(transport: transport, language: { "ar" }, maintenance: maintenance)
            let request = APIRequest(path: "vendor/home-page")
            let pending = Task { try await client.send(request, token: "token") as Value }
            while !maintenance.isPresented { await Task.yield() }
            precondition(transport.requests.count == 1, "Only the original GET should run before retry")
            await maintenance.retry()
            let value = try await pending.value
            precondition(value.count == 7)
            precondition(transport.requests.count == 3)
        }

        let maintenance = MerchantMaintenanceViewModel()
        let transport = MaintenanceTransport([
            .init(statusCode: 200, data: Data(#"{"key":"maintenance_mode","data":null}"#.utf8))
        ])
        let client = DefaultResponseHandler(transport: transport, language: { "en" }, maintenance: maintenance)
        let write = APIRequest(path: "vendor/deliver-coupon", method: .post)
        do {
            try await client.sendWithoutData(write, token: "token")
            preconditionFailure("Maintenance must not replay writes")
        } catch { precondition(error as? APIError == .maintenanceInterrupted) }
        precondition(maintenance.isPresented)
        precondition(transport.requests.count == 1)
        print("Passed: maintenance envelopes with missing/null/empty-array data, safe GET recovery, and no automatic write replay.")
    }
}

import Foundation

@MainActor
private final class LoggingTransport: HTTPTransport {
    var request: URLRequest?
    var response = HTTPResponse(statusCode: 200, data: Data())
    var failure: Error?
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        self.request = request
        if let failure { throw failure }
        return response
    }
}

@main
struct MerchantAPILoggingChecks {
    struct Value: Decodable { let count: Int }

    @MainActor static func main() async throws {
        var logs: [String] = []
        let logger = APILogger(output: { logs.append($0) })
        let endpoint = APIRequest(path: "vendor/login", method: .post,
            query: [.init(name: "access_token", value: "query-secret"), .init(name: "page", value: "2")],
            body: .multipart(["phone": "0501112233", "password": "test-password", "device_type": "ios"]))
        let request = try endpoint.urlRequest(configuration: .live, language: "ar", token: "bearer-secret")
        logger.request(endpoint, request: request, id: "request-123")
        let response = Data(#"{"key":"success","data":{"count":3,"token":"response-secret","customers":[{"phone":"0504445566","email":"test@example.invalid","purchase_code":"0012345678","status":"delivered"}]}}"#.utf8)
        logger.response(.init(statusCode: 200, data: response), request: request, id: "request-123")
        #if DEBUG
        precondition(logs.count == 2 && logs.allSatisfy { $0.contains("request-123") })
        let text = logs.joined()
        for value in ["query-secret", "Bearer bearer-secret", "test-password", "0501112233", "response-secret", "0504445566", "test@example.invalid", "0012345678"] {
            precondition(text.contains(value), "Actual field value missing from logs")
        }
        precondition(!text.contains("[REDACTED]") && text.contains(request.url!.absoluteString))
        for field in ["URL::", "Method:: POST", "Header::", "Queries::", "Body::", "Status:: 200", "ios", "delivered", "success"] {
            precondition(text.contains(field), "Expected diagnostic missing")
        }
        #else
        precondition(logs.isEmpty, "Release logging must be disabled")
        #endif

        logs = []
        let json = Data(#"{"payload":[{"refreshToken":"json-secret","PASSWORD_confirmation":"json-password","quantity":2}]}"#.utf8)
        let jsonEndpoint = APIRequest(path: "vendor/example", method: .post, body: .json(json))
        let jsonRequest = try jsonEndpoint.urlRequest(configuration: .live, language: "en", token: nil)
        logger.request(jsonEndpoint, request: jsonRequest, id: "json")
        logger.response(.init(statusCode: 502, data: Data("<html>private-proxy-output</html>".utf8)), request: request, id: "html")
        logger.response(.init(statusCode: 204, data: Data()), request: request, id: "empty")
        #if DEBUG
        precondition(logs[0].contains("json-secret") && logs[0].contains("json-password"))
        precondition(logs[0].contains("quantity") && logs[1].contains("<html>private-proxy-output</html>") && logs[2].contains("empty body"))
        #else
        precondition(logs.isEmpty)
        #endif
        precondition(jsonRequest.httpBody == json, "Logging must not alter the wire payload")

        logs = []
        let transport = LoggingTransport()
        let client = DefaultResponseHandler(transport: transport, language: { "ar" }, logger: logger)
        transport.response = .init(statusCode: 200, data: response)
        let value: Value = try await client.send(endpoint, token: "bearer-secret")
        precondition(value.count == 3)
        precondition(transport.request?.value(forHTTPHeaderField: "Authorization") == "Bearer bearer-secret")
        precondition(String(data: transport.request!.httpBody!, encoding: .utf8)!.contains("test-password"))
        #if DEBUG
        precondition(logs.count == 2 && logs[1].contains("Status:: 200"))
        #else
        precondition(logs.isEmpty)
        #endif

        logs = []
        transport.response = .init(statusCode: 422, data: Data(#"{"key":"fail","msg":"Required field","errors":{"password":["required"]}}"#.utf8))
        do {
            let _: Value = try await client.send(endpoint)
            preconditionFailure("Expected validation failure")
        } catch { precondition(error is APIError) }
        #if DEBUG
        precondition(logs.count == 2 && logs[1].contains("Status:: 422") && logs[1].contains("Required field"))
        #else
        precondition(logs.isEmpty)
        #endif

        logs = []
        for failure: Error in [CancellationError(), URLError(.cancelled)] {
            for document in [false, true] {
                logs = []
                transport.failure = failure
                do {
                    if document { _ = try await client.downloadPDF(at: URL(string: "https://example.invalid/report.pdf")!) }
                    else { let _: Value = try await client.send(endpoint) }
                    preconditionFailure("Cancellation must propagate")
                } catch { precondition(error is CancellationError) }
                #if DEBUG
                precondition(logs.count == 1 && logs[0].contains("FULL REQUEST COMPONENTS"))
                precondition(!logs.joined().contains("REQUEST FAILED"), "Expected cancellation is not a network failure")
                #else
                precondition(logs.isEmpty)
                #endif
            }
        }

        logs = []
        transport.failure = URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "failure-secret", NSURLErrorFailingURLErrorKey: URL(string: "https://example.invalid/?token=failure-secret")!])
        do {
            let _: Value = try await client.send(endpoint)
            preconditionFailure("Expected timeout")
        } catch { precondition(error as? APIError == .timeout) }
        #if DEBUG
        precondition(logs.count == 2 && logs[1].contains("REQUEST FAILED") && logs[1].contains("-1001"))
        precondition(logs[1].contains("failure-secret") && logs[1].contains("query-secret"))
        print("Passed: Debug request/response/error logging, quiet cancellation, correlation, and unchanged wire payloads.")
        #else
        precondition(logs.isEmpty)
        print("Passed: API logging is silent without DEBUG.")
        #endif
    }
}

import Foundation

protocol ResponseHandler {
    func get<T: Decodable>(
        _ endpoint: Endpoint<T>, language: String?, progress: ((_ progress: Int) -> Void)?
    ) async throws -> T
    func perform(_ endpoint: Endpoint<APIEnvelope<APIEmpty>>, language: String?) async throws
    func downloadPDF(at url: URL) async throws -> Data
}

extension ResponseHandler {
    func get<T: Decodable>(_ endpoint: Endpoint<T>, progress: ((_ progress: Int) -> Void)? = nil) async throws -> T {
        try await get(endpoint, language: nil, progress: progress)
    }

    func send<Value: Decodable>(
        _ endpoint: Endpoint<APIEnvelope<Value>>, language: String? = nil
    ) async throws -> APIEnvelope<Value> {
        let response = try await get(endpoint, language: language, progress: nil)
        guard response.key == "success" else {
            throw APIError.server(message: response.explanation ?? "", fields: response.errors ?? [:])
        }
        return response
    }

    func data<Value: Decodable>(
        from endpoint: Endpoint<APIEnvelope<Value>>, language: String? = nil
    ) async throws -> Value {
        let response = try await send(endpoint, language: language)
        guard let data = response.data else { throw APIError.invalidResponse }
        return data
    }

    func perform(_ endpoint: Endpoint<APIEnvelope<APIEmpty>>) async throws {
        try await perform(endpoint, language: nil)
    }
}

@MainActor
final class DefaultResponseHandler: ResponseHandler {
    let configuration: APIConfiguration
    private let networkExecuter: NetworkExecuter
    private let language: () -> String
    private let logger: APILogger
    private let maintenance: MerchantMaintenanceViewModel

    init(configuration: APIConfiguration = .live, networkExecuter: NetworkExecuter = DefaultNetworkExecuter(),
         language: @escaping () -> String = { AppLanguageManager.shared.apiLanguage },
         logger: APILogger = APILogger(), maintenance: MerchantMaintenanceViewModel? = nil) {
        self.configuration = configuration
        self.networkExecuter = networkExecuter
        self.language = language
        self.logger = logger
        self.maintenance = maintenance ?? .shared
    }

    func get<T: Decodable>(
        _ endpoint: Endpoint<T>, language: String? = nil, progress: ((_ progress: Int) -> Void)? = nil
    ) async throws -> T {
        let configured = configuredEndpoint(endpoint, language: language)
        let response = try await validatedResponse(configured, token: configured.headerType.token, progress: progress)
        return try configured.decoder.decode(data: response.data)
    }

    func perform(_ endpoint: Endpoint<APIEnvelope<APIEmpty>>, language: String? = nil) async throws {
        let configured = configuredEndpoint(endpoint, language: language)
        _ = try await validatedResponse(configured, token: configured.headerType.token, acceptsEmpty: true)
    }

    /// Fetch a server-provided document URL without forwarding merchant credentials or cookies.
    func downloadPDF(at url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil else { throw APIError.invalidResponse }
        try Task.checkCancellation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")
        logger.request(request, queries: nil, body: nil)

        let response: NetworkResponse
        do { response = try await networkExecuter.execute(request) }
        catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            logger.failure(error, request: request)
            throw APIError.map(error)
        }
        logger.response(response.data, for: url.absoluteString, statusCode: response.statusCode)
        try Task.checkCancellation()
        if Self.status(from: response.data)?.key == "maintenance_mode" {
            let probe = Endpoint<APIEmpty>(path: "vendor/home-page")
            try await maintenance.waitForRecovery { [weak self] in
                guard let self else { return false }
                return try await self.probeAvailability(for: probe)
            }
            return try await downloadPDF(at: url)
        }
        guard (200..<300).contains(response.statusCode) else { throw APIError.http(status: response.statusCode, message: nil) }
        guard response.data.starts(with: Data("%PDF-".utf8)) else { throw APIError.invalidResponse }
        return response.data
    }

    private func validatedResponse<T: Decodable>(_ endpoint: Endpoint<T>, token: String?, acceptsEmpty: Bool = false,
                                                 progress: ((_ progress: Int) -> Void)? = nil) async throws -> NetworkResponse {
        try Task.checkCancellation()
        let request = try endpoint.asURLRequest()
        logger.request(request, queries: endpoint.queries, body: endpoint.body)

        let response: NetworkResponse
        do { response = try await networkExecuter.execute(endpoint, progress: progress) }
        catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            logger.failure(error, request: request)
            throw APIError.map(error)
        }
        logger.response(response.data, for: request.url?.absoluteString ?? "No URL Found", statusCode: response.statusCode)
        try Task.checkCancellation()

        let status = Self.status(from: response.data)
        if status?.key == "maintenance_mode" {
            let checkAvailability = { [weak self] in
                guard let self else { return false }
                return try await self.probeAvailability(for: endpoint)
            }
            if endpoint.method == .get {
                try await maintenance.waitForRecovery(checkAvailability: checkAvailability)
                return try await validatedResponse(endpoint, token: token, acceptsEmpty: acceptsEmpty, progress: progress)
            }
            maintenance.present(checkAvailability: checkAvailability)
            throw APIError.maintenanceInterrupted
        }
        if response.statusCode == 401 || status?.key == "unauthenticated" || status?.key == "blocked" {
            if let token { NotificationCenter.default.post(name: .sessionExpired, object: token) }
            throw APIError.unauthenticated(status?.explanation)
        }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 422, let status {
                throw APIError.server(message: status.explanation ?? "", fields: status.errors ?? [:])
            }
            throw APIError.http(status: response.statusCode, message: status?.explanation)
        }
        if acceptsEmpty, response.statusCode == 204, response.data.isEmpty { return response }
        guard let status, let key = status.key else { throw APIError.invalidResponse }
        guard key == "success" else {
            throw APIError.server(message: status.explanation ?? "", fields: status.errors ?? [:])
        }
        return response
    }

    private func configuredEndpoint<T: Decodable>(_ endpoint: Endpoint<T>, language: String? = nil) -> Endpoint<T> {
        let server = endpoint.server == NetworkConstants.server ? configuration.baseURL.absoluteString : endpoint.server
        return Endpoint(server: server, method: endpoint.method, path: endpoint.path,
                        queries: endpoint.queries, body: endpoint.body, bodyEncoding: endpoint.bodyEncoding,
                        headerType: endpoint.headerType, uploads: endpoint.uploads, decoder: endpoint.decoder,
                        language: language ?? endpoint.language ?? self.language(), timeoutInterval: configuration.timeout)
    }

    private func probeAvailability<T: Decodable>(for endpoint: Endpoint<T>) async throws -> Bool {
        let path = endpoint.method == .get ? endpoint.path : "vendor/home-page"
        let probe = Endpoint<APIEmpty>(server: endpoint.server, path: path,
                                       queries: endpoint.method == .get ? endpoint.queries : nil, headerType: endpoint.headerType, language: endpoint.language)
        let configuredProbe = configuredEndpoint(probe)
        let response: NetworkResponse
        do { response = try await networkExecuter.execute(configuredProbe, progress: nil) }
        catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw APIError.map(error)
        }
        guard (200..<300).contains(response.statusCode),
              let status = Self.status(from: response.data), let key = status.key, !key.isEmpty else { return false }
        return key != "maintenance_mode"
    }

    private static func status(from data: Data) -> APIResponseStatus? {
        try? JSONDecoder().decode(APIResponseStatus.self, from: data)
    }
}

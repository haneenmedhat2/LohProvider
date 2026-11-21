import Foundation
import Alamofire

struct DefaultNetworkExecuter: NetworkExecuter {
    func execute(_ endpoint: any Requestable, progress progressHandler: ((_ progress: Int) -> Void)? = nil) async throws -> NetworkResponse {
        guard let uploads = endpoint.uploads, !uploads.isEmpty else {
            return try await execute(endpoint.asURLRequest())
        }

        var request = try endpoint.asURLRequest()
        request.httpShouldHandleCookies = false
        request.httpBody = nil
        let result = await AF.upload(multipartFormData: { form in
            if let fields = endpoint.body?.compactMapValues({ $0 }) {
                for (key, value) in fields { Self.append(value: value, withName: key, to: form) }
            }
            for item in uploads {
                form.append(item.data, withName: item.key, fileName: item.filenameWithExtension,
                            mimeType: item.mimeType.rawValue)
            }
        }, with: request)
        .redirect(using: Redirector(behavior: .doNotFollow))
        .uploadProgress(queue: .main) { progress in
            let value = Int(progress.fractionCompleted * 100)
            progressHandler?(value)
            #if DEBUG
            print("Upload progress: \(value)%")
            #endif
        }
        .serializingData(automaticallyCancelling: true, emptyResponseCodes: Set(100...599)).response
        return try response(from: result)
    }

    func execute(_ request: URLRequest) async throws -> NetworkResponse {
        var request = request
        request.httpShouldHandleCookies = false
        let result = await AF.request(request)
            .redirect(using: Redirector(behavior: .doNotFollow))
            .serializingData(automaticallyCancelling: true, emptyResponseCodes: Set(100...599)).response
        return try response(from: result)
    }

    private func response(from result: AFDataResponse<Data>) throws -> NetworkResponse {
        if let error = result.error {
            if Task.isCancelled || error.isExplicitlyCancelledError { throw CancellationError() }
            throw error
        }
        guard let httpResponse = result.response else { throw APIError.invalidResponse }
        return NetworkResponse(statusCode: httpResponse.statusCode, data: result.data ?? Data())
    }

    private static func append(value: Any, withName name: String, to form: MultipartFormData) {
        if let array = value as? [Any] {
            for (index, item) in array.enumerated() {
                if let dictionary = item as? [String: Any] {
                    for (key, nestedValue) in dictionary {
                        append(value: nestedValue, withName: "\(name)[\(index)][\(key)]", to: form)
                    }
                } else if let data = "\(item)".data(using: .utf8) {
                    form.append(data, withName: "\(name)[]")
                }
            }
        } else if let dictionary = value as? [String: Any] {
            for (key, nestedValue) in dictionary {
                append(value: nestedValue, withName: "\(name)[\(key)]", to: form)
            }
        } else if let data = "\(value)".data(using: .utf8) {
            form.append(data, withName: name)
        }
    }
}

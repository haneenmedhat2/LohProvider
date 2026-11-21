//
//  Requestable.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 21/12/2023.
//

import Foundation

protocol Requestable: RequestConvertible {
    
    associatedtype Response: Decodable
    
    var server: String {get}
    var method: RequestMethod {get}
    var path: String {get}
    var headerType: RequestHeaderType {get}
    var queries: APIParameters? {get}
    var body: APIParameters? {get}
    var bodyEncoding: RequestBodyEncoding {get}
    var uploads: [UploadData]? {get}
    var decoder: ResponseDecoder {get}
    var language: String? {get}
    var timeoutInterval: TimeInterval {get}
    
}
extension Requestable {
    func asURLRequest() throws -> URLRequest {
        
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("://"),
              !path.contains("?"), !path.contains("#"), !path.split(separator: "/").contains(".."),
              let baseURL = URL(string: server), baseURL.scheme?.lowercased() == "https", baseURL.host != nil,
              let url = URL(string: server + path) else { throw APIError.configuration }
        var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                    timeoutInterval: timeoutInterval)
        
        //MARK: - HTTTP Method -
        urlRequest.httpMethod = method.rawValue
        
        //MARK: - Common Headers -
        for header in headerType.headers(language: language ?? AppLanguageManager.shared.apiLanguage) {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }

        if let token = headerType.token,
           token.isEmpty || token.unicodeScalars.contains(where: CharacterSet.newlines.contains) {
            throw APIError.invalidResponse
        }
        
        //MARK: - Parameters -
        if let queries = queries?.compactMapValues({$0}) {
            urlRequest = try URLRequestEncoding.default.encode(urlRequest, with: queries)
        }
        if let body = body?.compactMapValues({$0}) {
            switch bodyEncoding {
            case .json:
                urlRequest = try JSONRequestEncoding.default.encode(urlRequest, with: body)
            case .multipart:
                try encodeMultipart(body, into: &urlRequest)
            }
        }
        
        return urlRequest
    }

    private func encodeMultipart(_ fields: [String: Any], into request: inout URLRequest) throws {
        let boundary = "LOH-\(UUID().uuidString)"
        var data = Data()
        for key in fields.keys.sorted() {
            guard !key.contains("\""), !key.unicodeScalars.contains(where: CharacterSet.newlines.contains) else {
                throw APIError.configuration
            }
            let value = String(describing: fields[key] ?? "")
            data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            data.append(Data(value.utf8))
            data.append(Data("\r\n".utf8))
        }
        data.append(Data("--\(boundary)--\r\n".utf8))
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
    }
}

enum RequestBodyEncoding { case json, multipart }

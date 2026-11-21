//
//  Endpoint.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 22/12/2023.
//

import Foundation

struct Endpoint<T: Decodable>: Requestable{
    
    typealias Response = T
    
    let server: String
    
    let method: RequestMethod
    
    let path: String
    
    let queries: APIParameters?
    
    let body: APIParameters?

    let bodyEncoding: RequestBodyEncoding
    
    let headerType: RequestHeaderType
    
    let uploads: [UploadData]?
    
    let decoder: ResponseDecoder

    let language: String?

    let timeoutInterval: TimeInterval
    
    
    init(
        server: String = NetworkConstants.server,
        method: RequestMethod = .get,
        path: String,
        queries: APIParameters? = nil,
        body: APIParameters? = nil,
        bodyEncoding: RequestBodyEncoding = .json,
        headerType: RequestHeaderType = .unauthorized,
        uploads: [UploadData]? = nil,
        decoder: ResponseDecoder = DefaultJSONDecoder(),
        language: String? = nil,
        timeoutInterval: TimeInterval = APIConfiguration.live.timeout
    ) {
        self.server = server
        self.method = method
        self.path = path
        self.queries = queries
        self.body = body
        self.bodyEncoding = bodyEncoding
        self.headerType = headerType
        self.uploads = uploads
        self.decoder = decoder
        self.language = language
        self.timeoutInterval = timeoutInterval
    }
}


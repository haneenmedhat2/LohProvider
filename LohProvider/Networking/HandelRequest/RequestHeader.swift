//
//  RequestHeader.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 22/12/2023.
//

import Foundation

enum RequestHeaderType {
    case authorized(token: String)
    case unauthorized
    case ifAuthourized(token: String?)

    var token: String? {
        switch self {
        case .authorized(let token): return token
        case .unauthorized: return nil
        case .ifAuthourized(let token): return token
        }
    }

    func headers(language: String) -> [String: String] {
        var headers = ["Accept": "application/json", "lang": language == "ar" ? "ar" : "en"]
        if let token, !token.isEmpty { headers["Authorization"] = "Bearer \(token)" }
        return headers
    }
}

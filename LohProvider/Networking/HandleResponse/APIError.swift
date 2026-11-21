import Foundation
import Alamofire

enum APIError: Error, Equatable {
    case configuration, invalidResponse, offline, timeout, transport, credentialStorage, requestInProgress
    case maintenanceInterrupted
    case unauthenticated(String?)
    case server(message: String, fields: [String: [String]])
    case http(status: Int, message: String?)

    var invalidatesSession: Bool {
        if case .unauthenticated = self { return true }
        return false
    }

    func message(localize: (String) -> String) -> String {
        switch self {
        case .unauthenticated: return localize("auth_session_expired")
        case .server(let message, _): return message.isEmpty ? localize("api_error_server") : message
        case .http(_, let message): return message?.isEmpty == false ? message! : localize("api_error_server")
        case .configuration: return localize("api_error_configuration")
        case .invalidResponse: return localize("api_error_response")
        case .offline: return localize("api_error_offline")
        case .timeout: return localize("api_error_timeout")
        case .credentialStorage: return localize("auth_storage_error")
        case .requestInProgress: return localize("auth_in_progress")
        case .transport: return localize("api_error_connection")
        case .maintenanceInterrupted: return localize("maintenance_request_not_completed")
        }
    }

    static func map(_ error: Error) -> APIError {
        if let error = error as? APIError { return error }
        let underlying = (error as? AFError)?.underlyingError ?? error
        let code = (underlying as? URLError)?.code
        if code == .timedOut { return .timeout }
        if code == .notConnectedToInternet || code == .networkConnectionLost { return .offline }
        return .transport
    }
}


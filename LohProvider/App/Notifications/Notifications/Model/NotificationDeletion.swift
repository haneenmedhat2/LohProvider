import Foundation

enum MerchantNotificationDeletion: Equatable, Identifiable {
    case one(String)
    case all

    var id: String {
        switch self {
        case .one(let id): return id
        case .all: return "all"
        }
    }
    var titleKey: String {
        self == .all ? "notifications_delete_all_confirm" : "notifications_delete_confirm"
    }
}

import Foundation

struct NotificationEndpoints {
    private init() {}
}

extension NotificationEndpoints {
    static func list(page: Int, perPage: Int?, token: String) -> Endpoint<APIEnvelope<MerchantNotificationPage>> {
        var queries: APIParameters = ["page": page]
        if let perPage { queries["paginate"] = perPage }
        return Endpoint(path: "vendor/notifications", queries: queries, headerType: .authorized(token: token))
    }

    static func count(token: String) -> Endpoint<APIEnvelope<MerchantNotificationCount>> {
        return Endpoint(path: "vendor/count-notifications", headerType: .authorized(token: token))
    }

    static func markAllAsRead(token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(method: .patch, path: "vendor/read-notifications", headerType: .authorized(token: token))
    }

    static func markAsRead(id: String, token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(method: .patch, path: "vendor/read-notification/" + id, headerType: .authorized(token: token))
    }

    static func delete(id: String, token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(method: .delete, path: "vendor/delete-notification/" + id, headerType: .authorized(token: token))
    }

    static func deleteAll(token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(method: .delete, path: "vendor/delete-notifications", headerType: .authorized(token: token))
    }
}

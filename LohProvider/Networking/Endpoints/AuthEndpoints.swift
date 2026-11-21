import Foundation

struct AuthEndpoints {
    private init() {}
}

extension AuthEndpoints {
    static func login(phone: String, password: String, deviceID: String) -> Endpoint<APIEnvelope<MerchantLoginToken>> {
        return Endpoint(
            method: .post,
            path: "vendor/login",
            body: ["phone": phone, "password": password, "device_type": "ios", "device_id": deviceID],
            bodyEncoding: .multipart
        )
    }

    static func profile(token: String) -> Endpoint<APIEnvelope<MerchantProfile>> {
        return Endpoint(path: "vendor/profile", headerType: .authorized(token: token))
    }

    static func logout(token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(method: .delete, path: "vendor/sign-out", headerType: .authorized(token: token))
    }

    static func deleteAccount(token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(method: .delete, path: "vendor/delete-account", headerType: .authorized(token: token))
    }

    static func changeLanguage(_ language: String, token: String) -> Endpoint<APIEnvelope<APIEmpty>> {
        return Endpoint(
            method: .patch,
            path: "change-lang",
            queries: ["lang": language],
            headerType: .authorized(token: token)
        )
    }
}

import Foundation
import Combine

// Host-only boundaries: these checks never access the app's Keychain, preferences, or API.
enum APIError: Error, Equatable {
    case offline, invalidResponse, credentialStorage, requestInProgress, unauthenticated(String?)
    var invalidatesSession: Bool { if case .unauthenticated = self { return true }; return false }
    static func map(_ error: Error) -> APIError { error as? APIError ?? .offline }
}
struct AuthTokenStore {
    static var token: String?
    static var failWrites = false
    static var failDeletes = false
    func write(_ token: String) throws {
        if Self.failWrites { throw APIError.credentialStorage }
        Self.token = token
    }
    func delete() throws {
        if Self.failDeletes { throw APIError.credentialStorage }
        Self.token = nil
    }
}
extension UserDefaults {
    static var accessToken: String? {
        get { AuthTokenStore.token }
        set { AuthTokenStore.token = newValue }
    }
    static var user: MerchantProfile?
    static var isLogin = false
    static func save(_ profile: MerchantProfile) {
        user = profile
        NotificationCenter.default.post(name: .profileUpdated, object: nil)
    }
    static func clearAuthentication() throws {
        try AuthTokenStore().delete()
        user = nil; isLogin = false
        NotificationCenter.default.post(name: .profileUpdated, object: nil)
    }
}
struct APIEnvelope<Value: Decodable> {}
struct APIEmpty: Decodable {}
struct Endpoint<Response> { let token: String }
enum AuthEndpoints {
    static func profile(token: String) -> Endpoint<APIEnvelope<MerchantProfile>> { .init(token: token) }
    static func logout(token: String) -> Endpoint<APIEnvelope<APIEmpty>> { .init(token: token) }
}
@MainActor protocol ResponseHandler {
    func data<Value: Decodable>(from endpoint: Endpoint<APIEnvelope<Value>>, language: String?) async throws -> Value
    func perform(_ endpoint: Endpoint<APIEnvelope<APIEmpty>>, language: String?) async throws
}
@MainActor final class DefaultResponseHandler: ResponseHandler {
    var profileCalls = 0
    var logoutCalls = 0
    var load: (String) async throws -> MerchantProfile = { _ in
        MerchantProfile(id: "1", name: "Store", phone: nil, email: nil)
    }
    var logout: (String) async throws -> Void = { _ in }
    func data<Value: Decodable>(from endpoint: Endpoint<APIEnvelope<Value>>, language: String?) async throws -> Value {
        profileCalls += 1
        guard let value = try await load(endpoint.token) as? Value else { throw APIError.invalidResponse }
        return value
    }
    func perform(_ endpoint: Endpoint<APIEnvelope<APIEmpty>>, language: String?) async throws {
        logoutCalls += 1
        try await logout(endpoint.token)
    }
}
struct AppLanguageManager {
    static let shared = AppLanguageManager()
    let apiLanguage = "en"
}
enum MerchantRoute { case profile }
enum MerchantTab { case account }
@MainActor final class MerchantTabsCoordinator: ObservableObject {
    enum Dialog { case logout }
    @Published var dialog: Dialog?
    var resets = 0
    init(responseHandler: ResponseHandler? = nil) {}
    func reset() { resets += 1; dialog = nil }
    func open(_ route: MerchantRoute, in tab: MerchantTab) {}
}

@main
struct CoordinatorSessionChecks {
    @MainActor static func main() async throws {
        let client = DefaultResponseHandler()
        let coordinator = MerchantAppCoordinator(responseHandler: client)
        await coordinator.restoreIfNeeded()
        precondition(coordinator.root == .auth && client.profileCalls == 0)

        AuthTokenStore.failWrites = true
        do { try await coordinator.completeSignIn(token: "token-a"); preconditionFailure("Storage failure must prevent login") }
        catch { precondition(error as? APIError == .credentialStorage) }
        precondition(UserDefaults.accessToken == nil && coordinator.root == .auth)
        AuthTokenStore.failWrites = false
        try await coordinator.completeSignIn(token: "token-a")
        precondition(coordinator.root == .mainTabs && UserDefaults.isLogin && UserDefaults.user?.id == "1")
        await coordinator.restoreIfNeeded()
        precondition(client.profileCalls == 1, "An authenticated root must not restore again")

        client.load = { _ in throw APIError.offline }
        do {
            let restored = MerchantAppCoordinator(responseHandler: client)
            await restored.restoreIfNeeded()
            precondition(restored.root == .splash && restored.restorationError == .offline)
            precondition(UserDefaults.accessToken == "token-a", "Offline restoration must retain the token for retry")
            client.load = { _ in MerchantProfile(id: "1", name: "Refreshed Store", phone: nil, email: nil) }
            await restored.restoreSession()
            precondition(restored.root == .mainTabs && UserDefaults.user?.name == "Refreshed Store")
        }

        let profile = MerchantProfileViewModel(responseHandler: client)
        client.load = { _ in MerchantProfile(id: "1", name: "Updated Profile", phone: nil, email: nil) }
        await profile.refresh()
        await drainNotifications()
        precondition(UserDefaults.user == profile.profile && coordinator.profile?.name == "Updated Profile")

        client.logout = { _ in throw APIError.offline }
        let account = MerchantAccountViewModel(coordinator: coordinator.tabs, onLogout: coordinator.signOut)
        account.presentLogoutConfirmation()
        await account.confirmLogout()
        precondition(account.error == .offline && !account.isSigningOut)
        precondition(coordinator.root == .mainTabs && UserDefaults.accessToken == "token-a")

        var pendingLogout: CheckedContinuation<Void, Error>?
        client.logout = { _ in try await withCheckedThrowingContinuation { pendingLogout = $0 } }
        let logout = Task { await account.confirmLogout() }
        for _ in 0..<100 where pendingLogout == nil { await Task.yield() }
        precondition(pendingLogout != nil)
        let calls = client.logoutCalls
        await account.confirmLogout()
        precondition(client.logoutCalls == calls, "Repeated confirmation must not send a second logout")
        pendingLogout?.resume()
        await logout.value
        precondition(coordinator.root == .auth && UserDefaults.accessToken == nil && UserDefaults.user == nil && !UserDefaults.isLogin)

        client.logout = { _ in }
        client.load = { _ in MerchantProfile(id: "2", name: "New Store", phone: nil, email: nil) }
        try await coordinator.completeSignIn(token: "token-b")
        NotificationCenter.default.post(name: .sessionExpired, object: "token-a")
        await drainNotifications()
        precondition(UserDefaults.accessToken == "token-b" && coordinator.root == .mainTabs)
        NotificationCenter.default.post(name: .sessionExpired, object: "token-b")
        await drainNotifications()
        precondition(UserDefaults.accessToken == nil && coordinator.root == .auth)

        // Finishing an old profile request must not restore a session after logout or block a new login.
        var pendingProfile: CheckedContinuation<MerchantProfile, Error>?
        UserDefaults.accessToken = "old-token"
        client.load = { _ in try await withCheckedThrowingContinuation { pendingProfile = $0 } }
        let oldRestore = Task { await coordinator.restoreSession() }
        for _ in 0..<100 where pendingProfile == nil { await Task.yield() }
        precondition(pendingProfile != nil)
        coordinator.forgetSession()
        client.load = { _ in MerchantProfile(id: "3", name: "Latest Store", phone: nil, email: nil) }
        try await coordinator.completeSignIn(token: "latest-token")
        pendingProfile?.resume(returning: MerchantProfile(id: "old", name: "Old Store", phone: nil, email: nil))
        await oldRestore.value
        precondition(UserDefaults.accessToken == "latest-token" && UserDefaults.user?.id == "3" && coordinator.root == .mainTabs)

        AuthTokenStore.failDeletes = true
        do { try await coordinator.signOut(); preconditionFailure("A storage failure must be reported") }
        catch { precondition(error as? APIError == .credentialStorage) }
        precondition(UserDefaults.accessToken == "latest-token")
        AuthTokenStore.failDeletes = false
        coordinator.forgetSession()
        print("Passed: login, restore/retry, profile persistence, logout failure and duplicate protection, stale responses, expiry, and storage failures.")
    }

    @MainActor private static func drainNotifications() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

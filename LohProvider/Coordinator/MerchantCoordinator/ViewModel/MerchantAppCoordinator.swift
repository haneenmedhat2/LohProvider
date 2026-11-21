import SwiftUI
import Combine

/// Owns session restoration and switches between authentication and the main tabs.
@MainActor
final class MerchantAppCoordinator: ObservableObject {
    enum Root: Equatable { case splash, auth, mainTabs }

    @Published private(set) var root: Root = .splash
    @Published private(set) var profile = UserDefaults.user
    @Published private(set) var restorationError: APIError?
    @Published private(set) var sessionID = UUID()
    @Published private(set) var tabs: MerchantTabsCoordinator
    let responseHandler: ResponseHandler
    private var restoringSession = false
    private var cancellables = Set<AnyCancellable>()

    init(responseHandler: ResponseHandler? = nil, tabs: MerchantTabsCoordinator? = nil) {
        let client = responseHandler ?? DefaultResponseHandler()
        self.responseHandler = client
        self.tabs = tabs ?? MerchantTabsCoordinator(responseHandler: client)

        NotificationCenter.default.publisher(for: .sessionExpired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let token = note.object as? String, token == UserDefaults.accessToken else { return }
                self?.forgetSession()
            }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .profileUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.profile = UserDefaults.user }
            .store(in: &cancellables)
    }

    func restoreIfNeeded() async {
        guard root == .splash, restorationError == nil else { return }
        await restoreSession()
    }

    func restoreSession() async {
        guard !restoringSession else { return }
        guard let token = UserDefaults.accessToken else { forgetSession(); return }
        let sessionID = self.sessionID
        restoringSession = true
        restorationError = nil
        defer { if self.sessionID == sessionID { restoringSession = false } }
        do {
            let loaded: MerchantProfile = try await responseHandler.data(
                from: AuthEndpoints.profile(token: token), language: AppLanguageManager.shared.apiLanguage)
            try Task.checkCancellation()
            guard self.sessionID == sessionID, UserDefaults.accessToken == token else { return }
            UserDefaults.save(loaded)
            UserDefaults.isLogin = true
            profile = loaded
            root = .mainTabs
        } catch {
            guard self.sessionID == sessionID, UserDefaults.accessToken == token,
                  !Task.isCancelled, !(error is CancellationError) else { return }
            let mapped = APIError.map(error)
            if mapped.invalidatesSession { forgetSession() }
            else { restorationError = mapped; root = .splash }
        }
    }

    func completeSignIn(token: String) async throws {
        guard !restoringSession else { throw APIError.requestInProgress }
        guard !token.isEmpty, token == token.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.unicodeScalars.contains(where: CharacterSet.newlines.contains) else { throw APIError.invalidResponse }
        try Task.checkCancellation()
        try AuthTokenStore().write(token)
        UserDefaults.user = nil
        UserDefaults.isLogin = false
        profile = nil
        sessionID = UUID()
        tabs = MerchantTabsCoordinator(responseHandler: responseHandler)
        await restoreSession()
    }

    func signOut() async throws {
        let token = UserDefaults.accessToken
        if let token {
            try await responseHandler.perform(AuthEndpoints.logout(token: token), language: AppLanguageManager.shared.apiLanguage)
        }
        try Task.checkCancellation()
        guard UserDefaults.accessToken == token else { return }
        try clearSession()
    }

    func forgetSession() {
        do { try clearSession() }
        catch { restorationError = APIError.map(error); root = .splash }
    }

    private func clearSession() throws {
        try UserDefaults.clearAuthentication()
        profile = nil
        restorationError = nil
        restoringSession = false
        sessionID = UUID()
        tabs = MerchantTabsCoordinator(responseHandler: responseHandler)
        root = .auth
    }
}

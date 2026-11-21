import Foundation
import Combine

/// Owns the draft language selection and applies it after the server accepts the change.
@MainActor
final class MerchantLanguageViewModel: ObservableObject {
    @Published private(set) var selected: String
    @Published private(set) var applied: String?
    @Published private(set) var isApplying = false
    @Published private(set) var error: APIError?
    private var revision = 0
    private let manager: AppLanguageManager
    private let responseHandler: ResponseHandler

    init(manager: AppLanguageManager? = nil, responseHandler: ResponseHandler? = nil) {
        let languageManager = manager ?? AppLanguageManager.shared
        self.manager = languageManager
        self.responseHandler = responseHandler ?? DefaultResponseHandler()
        selected = languageManager.selectedLanguage
    }

    func select(_ language: String) {
        guard !isApplying, ["ar", "en"].contains(language) else { return }
        selected = language
        applied = nil; error = nil
    }

    func apply() async {
        guard !isApplying else { return }
        let requested = selected
        let current = manager.selectedLanguage
        let operation = revision
        guard let token = UserDefaults.accessToken else {
            error = .unauthenticated(nil)
            return
        }
        isApplying = true; error = nil; applied = nil
        defer { isApplying = false }
        do {
            try Task.checkCancellation()
            try await responseHandler.perform(
                AuthEndpoints.changeLanguage(requested, token: token), language: requested)
            try Task.checkCancellation()
            // A system-language change while waiting supersedes this draft.
            guard revision == operation, manager.selectedLanguage == current,
                  UserDefaults.accessToken == token else { return }
            manager.setLanguage(requested)
            applied = requested
        } catch {
            guard revision == operation, UserDefaults.accessToken == token else { return }
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            self.error = APIError.map(error)
        }
    }

    func synchronize(current: String) {
        guard selected != current else { return }
        revision += 1
        selected = current; applied = nil; error = nil
    }

    func dismissSuccess() { applied = nil }
}

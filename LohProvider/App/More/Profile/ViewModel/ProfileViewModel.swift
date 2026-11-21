import Foundation
import Combine

@MainActor
final class MerchantProfileViewModel: ObservableObject {
    @Published private(set) var profile = UserDefaults.user
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshError: APIError?
    private let responseHandler: ResponseHandler

    init(responseHandler: ResponseHandler? = nil) {
        self.responseHandler = responseHandler ?? DefaultResponseHandler()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        guard let token = UserDefaults.accessToken else {
            refreshError = .unauthenticated(nil)
            return
        }
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }
        do {
            let loaded: MerchantProfile = try await responseHandler.data(
                from: AuthEndpoints.profile(token: token), language: AppLanguageManager.shared.apiLanguage)
            try Task.checkCancellation()
            guard UserDefaults.accessToken == token else { return }
            profile = loaded
            UserDefaults.save(loaded)
        } catch {
            guard UserDefaults.accessToken == token, !Task.isCancelled, !(error is CancellationError) else { return }
            refreshError = APIError.map(error)
        }
    }
}

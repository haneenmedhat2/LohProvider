import Foundation
import Combine

@MainActor
final class MerchantAccountViewModel: ObservableObject {
    @Published private(set) var isSigningOut = false
    @Published private(set) var error: APIError?

    private let coordinator: MerchantTabsCoordinator
    private let onLogout: () async throws -> Void
    init(coordinator: MerchantTabsCoordinator, onLogout: @escaping () async throws -> Void) {
        self.coordinator = coordinator
        self.onLogout = onLogout
    }

    func open(_ route: MerchantRoute) {
        coordinator.open(route, in: .account)
    }

    func presentLogoutConfirmation() {
        coordinator.dialog = .logout
    }

    func dismissLogoutConfirmation() {
        coordinator.dialog = nil
    }

    func confirmLogout() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        error = nil
        defer { isSigningOut = false }
        do {
            try await onLogout()
            dismissLogoutConfirmation()
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            self.error = APIError.map(error)
        }
    }
}

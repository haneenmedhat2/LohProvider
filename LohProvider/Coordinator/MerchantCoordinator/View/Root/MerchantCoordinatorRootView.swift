import SwiftUI

/// App entry point. Authentication and tab routing are coordinated outside feature views.
struct MerchantCoordinatorRootView: View {
    @EnvironmentObject private var coordinator: MerchantAppCoordinator
    @Environment(\.locale) private var locale
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        Group {
            switch coordinator.root {
            case .mainTabs:
                MerchantTabsView()
                    .environmentObject(coordinator.tabs)
                    .environmentObject(coordinator.tabs.offersModel)
                    .environmentObject(coordinator.tabs.supportModel)
                    .environmentObject(coordinator.tabs.settlementsModel)
                    .environmentObject(coordinator.tabs.reportsModel)
                    .environmentObject(coordinator.tabs.notificationsModel)
                    .id(coordinator.sessionID)
            case .auth:
                MerchantLoginView(onAuthenticated: coordinator.completeSignIn, responseHandler: coordinator.responseHandler)
                    .logMerchantScreen()
            case .splash:
                if let error = coordinator.restorationError {
                    VStack(spacing: 20) {
                        Text(merchantString("auth_profile_unavailable", arabic: arabic)).merchantFont(20, .bold)
                        MerchantFieldError(message: error.message { merchantString($0, arabic: arabic) })
                        MerchantButton(title: merchantString("api_retry", arabic: arabic)) { Task { await coordinator.restoreSession() } }
                        MerchantButton(title: merchantString("nav_logout", arabic: arabic), secondary: true) {
                            coordinator.forgetSession()
                        }
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(MerchantTheme.background)
                } else {
                    ProgressView(merchantString("auth_restoring", arabic: arabic))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(MerchantTheme.background)
                }
            }
        }
        .environment(\.merchantProfile, coordinator.profile)
        .task { await coordinator.restoreIfNeeded() }
    }
}

#if DEBUG
#Preview {
    MerchantCoordinatorRootView()
        .environmentObject(MerchantAppCoordinator())
}
#endif

import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appCoordinator = MerchantAppCoordinator()
    @StateObject private var maintenance = MerchantMaintenanceViewModel.shared
    @StateObject private var updateGate = MerchantAppUpdateGate()
    @State private var showSplash = true

    var body: some View {
        Group {
            #if DEBUG
            mainApp
            #else
            switch updateGate.state {
            case .checking:
                MerchantSplashView(onFinished: {})
            case .updateRequired(let storeURL):
                MerchantAppUpdateView(storeURL: storeURL)
            case .ready:
                mainApp
            }
            #endif
        }
        .environmentObject(appCoordinator)
        .tint(MerchantTheme.brand)
        .background(MerchantTheme.background.ignoresSafeArea())
        .background(MerchantMaintenancePresentation(viewModel: maintenance))
        .task {
            #if !DEBUG
            await updateGate.refresh()
            #endif
        }
        .onChange(of: scenePhase) { phase in
            #if !DEBUG
            if phase == .active { Task { await updateGate.refresh() } }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushDidTap)) { _ in
            openPendingNotification()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationsShouldRefresh)) { _ in
            if appCoordinator.root == .mainTabs {
                Task { await appCoordinator.tabs.notificationsModel.refreshCount() }
            }
        }
        .onChange(of: appCoordinator.root) { _ in
            openPendingNotification()
        }
    }

    private var mainApp: some View {
        ZStack {
            MerchantCoordinatorRootView()

            if showSplash {
                MerchantSplashView {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private func openPendingNotification() {
        guard let destination = AppDelegate.pendingNotificationDestination else { return }
        switch appCoordinator.root {
        case .splash: return
        case .auth:
            AppDelegate.pendingNotificationDestination = nil
        case .mainTabs:
            AppDelegate.pendingNotificationDestination = nil
            switch destination {
            case .order(let id): appCoordinator.tabs.open(.orderDetails(id), in: .offers)
            case .settlements: appCoordinator.tabs.select(.settlements)
            case .offer(let id): appCoordinator.tabs.open(.offerDetails(id), in: .offers)
            case .notifications: appCoordinator.tabs.open(.notifications, in: .offers)
            }
            Task { await appCoordinator.tabs.notificationsModel.refreshCount() }
        }
    }
}

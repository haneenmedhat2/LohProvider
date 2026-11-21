import SwiftUI

@MainActor
final class MerchantTabsCoordinator: ObservableObject {
    @Published var selectedTab: MerchantTab = .offers
    @Published var sheet: MerchantSheet?
    @Published var dialog: MerchantDialog?

    let offersModel: MerchantOffersViewModel
    let supportModel: MerchantSupportViewModel
    let settlementsModel: MerchantSettlementsViewModel
    let reportsModel: MerchantReportsViewModel
    let notificationsModel: MerchantNotificationsViewModel

    let offers = BaseCoordinator<MerchantRoute>()
    let reports = BaseCoordinator<MerchantRoute>()
    let settlements = BaseCoordinator<MerchantRoute>()
    let account = BaseCoordinator<MerchantRoute>()

    init(responseHandler: ResponseHandler? = nil) {
        let client = responseHandler ?? DefaultResponseHandler()
        offersModel = MerchantOffersViewModel(responseHandler: client, token: { UserDefaults.accessToken })
        supportModel = MerchantSupportViewModel(responseHandler: client, token: { UserDefaults.accessToken })
        settlementsModel = MerchantSettlementsViewModel(responseHandler: client, token: { UserDefaults.accessToken })
        reportsModel = MerchantReportsViewModel(responseHandler: client, token: { UserDefaults.accessToken })
        notificationsModel = MerchantNotificationsViewModel(responseHandler: client, token: { UserDefaults.accessToken })
    }

    func stack(for tab: MerchantTab) -> BaseCoordinator<MerchantRoute> {
        switch tab {
        case .offers: return offers
        case .reports: return reports
        case .settlements: return settlements
        case .account: return account
        }
    }

    func select(_ tab: MerchantTab) {
        // Programmatic selection preserves history; native TabView owns user tap behavior.
        selectedTab = tab
    }

    func open(_ route: MerchantRoute, in tab: MerchantTab) {
        sheet = nil
        dialog = nil
        selectedTab = tab
        stack(for: tab).push(route)
    }

    func reset() {
        for tab in MerchantTab.allCases { stack(for: tab).reset() }
        sheet = nil
        dialog = nil
        selectedTab = .offers
    }
}

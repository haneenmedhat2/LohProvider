import Foundation

@main
struct MerchantNavigationChecks {
    @MainActor
    static func main() {
        let navigation = MerchantTabsCoordinator()
        precondition(navigation.selectedTab == .offers)
        precondition(MerchantTab.allCases == [.offers, .reports, .settlements, .account])
        navigation.open(.notifications, in: .offers)
        precondition(navigation.offers.path == [.notifications] && MerchantRoute.notifications.titleKey == "nav_notifications")
        navigation.offers.pop()
        navigation.offers.push(.offerDetails("offer-1"))
        navigation.offers.push(.orderDetails("order-1"))
        navigation.select(.reports)
        navigation.reports.push(.reportDetails)
        navigation.select(.offers)
        precondition(navigation.offers.path.count == 2, "Switching tabs preserves history")
        precondition(navigation.reports.path == [.reportDetails], "Histories are independent")
        navigation.select(.offers)
        precondition(navigation.offers.path.count == 2, "Programmatic reselection preserves history")
        precondition(navigation.reports.path.count == 1)
        navigation.sheet = .orderCode
        navigation.open(.ticketDetails("ticket-1"), in: .account)
        precondition(navigation.sheet == nil && navigation.selectedTab == .account)
        precondition(navigation.account.path == [.ticketDetails("ticket-1")])
        navigation.account.pop()
        precondition(navigation.account.path.isEmpty)
        navigation.sheet = .reportExport
        navigation.dialog = .logout
        navigation.reset()
        precondition(navigation.selectedTab == .offers)
        precondition(navigation.sheet == nil && navigation.dialog == nil)
        for tab in MerchantTab.allCases { precondition(navigation.stack(for: tab).path.isEmpty) }
        print("Passed: tab order, default selection, independent stacks, programmatic selection, route opening, back navigation, modal dismissal, and logout reset.")
    }
}

import SwiftUI

struct MerchantTabStack: View {
    let tab: MerchantTab
    @ObservedObject var stack: BaseCoordinator<MerchantRoute>
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @EnvironmentObject private var appCoordinator: MerchantAppCoordinator

    var body: some View {
        NavigationStack(path: $stack.path) {
            Group {
                if tab == .account {
                    MerchantAccountView(coordinator: coordinator, onLogout: appCoordinator.signOut)
                        .logMerchantScreen()
                } else if tab == .settlements {
                    MerchantSettlementsView().logMerchantScreen()
                } else if tab == .reports {
                    MerchantReportsView().logMerchantScreen()
                } else {
                    MerchantOffersView().logMerchantScreen()
                }
            }
                .navigationDestination(for: MerchantRoute.self) { route in
                    Group {
                        switch route {
                        case .notifications: MerchantNotificationsView().logMerchantScreen()
                        case .profile: MerchantProfileView(responseHandler: appCoordinator.responseHandler).logMerchantScreen()
                        case .language: MerchantLanguageView(responseHandler: appCoordinator.responseHandler).logMerchantScreen()
                        case .support: MerchantSupportView().logMerchantScreen()
                        case .createTicket: MerchantCreateTicketView().logMerchantScreen()
                        case .supportSent(let id): MerchantSupportSentView(ticketID: id).logMerchantScreen()
                        case .ticketDetails(let id): MerchantTicketDetailView(ticketID: id).logMerchantScreen()
                        case .settlementDetails(let id): MerchantSettlementDetailView(settlementID: id).logMerchantScreen()
                        case .reportDetails: MerchantReportDetailView().logMerchantScreen()
                        case .offerDetails(let id): MerchantOfferDetailView(offerID: id).logMerchantScreen()
                        case .orderDetails(let id): MerchantOrderView(orderID: id).logMerchantScreen()
                        }
                    }
                }
        }
        .environmentObject(stack)
        .toolbar(stack.path.isEmpty ? .visible : .hidden, for: .tabBar)
    }
}

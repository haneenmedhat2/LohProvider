import SwiftUI
import UIKit

struct MerchantTabsView: View {
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @EnvironmentObject private var reportStore: MerchantReportsViewModel
    @EnvironmentObject private var offerStore: MerchantOffersViewModel
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @Environment(\.locale) private var locale
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor(named: "LOHHeading")
    }

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ForEach(MerchantTab.allCases) { tab in
                MerchantTabStack(tab: tab, stack: coordinator.stack(for: tab))
                    .tag(tab)
                    .tabItem {
                        Label(merchantString(tab.titleKey, arabic: arabic), image: tab.assetName)
                            .accessibilityIdentifier("merchantTab_\(tab.rawValue)")
                    }
            }
        }
        .overlay {
            if let error = offerStore.verificationError {
                MerchantVerificationErrorOverlay(error: error)
                    .environmentObject(offerStore)
            }
        }
        .sheet(item: $coordinator.sheet, onDismiss: {
            if let id = offerStore.pendingOrderID {
                offerStore.pendingOrderID = nil
                if coordinator.offers.path.last != .orderDetails(id) {
                    coordinator.open(.orderDetails(id), in: .offers)
                }
            }
        }) { sheet in
            Group {
                switch sheet {
                case .reportPeriod:
                    MerchantReportPeriodView(period: reportStore.period, filter: reportStore.filter).logMerchantScreen()
                        .presentationDetents([.height(560), .large])
                case .reportExport:
                    MerchantReportExportView(period: reportStore.period, previewReport: reportStore.isPreview ? reportStore.snapshot : nil).logMerchantScreen()
                case .orderCode:
                    MerchantOrderCodeView().logMerchantScreen().presentationDetents([.height(340), .large])
                case .offersOrderCode:
                    MerchantOrderCodeView(fromOffers: true).logMerchantScreen().presentationDetents([.height(240), .large])
                case .scanner:
                    MerchantOrderScannerView().logMerchantScreen().presentationDetents([.large])
                }
            }
                .environmentObject(coordinator)
                .environmentObject(reportStore)
                .environmentObject(offerStore)
                .environment(\.locale, Locale(identifier: languageManager.selectedLanguage))
                .environment(\.layoutDirection, languageManager.layoutDirection)
                .presentationDragIndicator(.visible)
                .presentationBackground(.white)
        }
        .tint(MerchantTheme.brand)
    }
}

#if DEBUG
struct MerchantTabsView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["en", "ar"], id: \.self) { language in
            MerchantTabsView()
                .environmentObject(MerchantTabsCoordinator())
                .environmentObject(MerchantOffersViewModel.preview())
                .environmentObject(MerchantSupportViewModel())
                .environmentObject(MerchantSettlementsViewModel.preview())
                .environmentObject(MerchantReportsViewModel.preview())
                .environmentObject(MerchantNotificationsViewModel())
                .environmentObject(MerchantAppCoordinator())
                .environment(\.locale, Locale(identifier: language))
                .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
                .previewDisplayName(language)
        }
    }
}
#endif

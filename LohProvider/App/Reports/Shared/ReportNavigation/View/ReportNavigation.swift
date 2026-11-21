import SwiftUI

struct MerchantReportNavigation: ViewModifier {
    @Environment(\.merchantProfile) private var merchantProfile
    @Environment(\.locale) private var locale
    var detail = false
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    @ViewBuilder func body(content: Content) -> some View {
        if detail {
            content.background(MerchantTheme.surface.ignoresSafeArea())
                .modifier(MerchantNavigationBar(title: "report_detailed_report", background: MerchantTheme.surface, titleSize: 17, titleWeight: .bold))
                .toolbar { detailIdentity }
        } else {
            content.background(MerchantTheme.surface.ignoresSafeArea())
            .navigationTitle(merchantString("tab_reports", arabic: arabic))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                MerchantStoreNavigationHeader(greeting: merchantString("report_hello", arabic: arabic),
                                              name: merchantProfile?.name, image: merchantProfile?.image)
            }
        }
    }

    @ToolbarContentBuilder private var detailIdentity: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarTrailing) {
                MerchantReportNavigationIdentity(name: merchantProfile?.name, image: merchantProfile?.image)
            }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                MerchantReportNavigationIdentity(name: merchantProfile?.name, image: merchantProfile?.image)
            }
        }
    }
}

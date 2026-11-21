import SwiftUI
import Kingfisher

struct MerchantOfferNavigation: ViewModifier {
    @Environment(\.merchantProfile) private var merchantProfile
    @Environment(\.locale) private var locale
    var title: String?
    var vendor: MerchantOfferVendor?
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var greeting: String { vendor?.greeting ?? merchantString("report_hello", arabic: arabic) }
    @ViewBuilder func body(content: Content) -> some View {
        if let title {
            content.background(MerchantTheme.background.ignoresSafeArea())
                .modifier(MerchantNavigationBar(title: title))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        vendorImage(size: 32)
                    }
                }
        } else {
            content.background(MerchantTheme.surface.ignoresSafeArea())
            .navigationTitle(merchantString("tab_offers", arabic: arabic))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                MerchantStoreNavigationHeader(greeting: greeting, name: vendor?.name ?? merchantProfile?.name,
                                              image: merchantProfile?.image ?? vendor?.image)
            }
        }
    }

    private func vendorImage(size: CGFloat) -> some View {
        MerchantProviderImage(url: merchantProfile?.image ?? vendor?.image, size: size, cornerRadius: 14)
    }
}

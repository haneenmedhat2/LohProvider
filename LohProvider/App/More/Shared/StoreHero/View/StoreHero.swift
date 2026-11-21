import SwiftUI

struct MerchantStoreHero: View {
    @Environment(\.merchantProfile) private var storedProfile
    @Environment(\.locale) private var locale
    @State private var showingImage = false
    var profile = false
    var merchantProfile: MerchantProfile? = nil
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var displayedProfile: MerchantProfile? { merchantProfile ?? storedProfile }
    var body: some View {
        VStack(spacing: 16) {
            if arabic { icon }
            VStack(spacing: 4) {
                Text(displayedProfile?.name ?? "—").merchantFont(profile && !arabic ? 20 : 22, .bold).foregroundStyle(MerchantTheme.heading)
                Text(merchantString("account_merchant", arabic: arabic)).merchantFont(14).foregroundStyle(MerchantTheme.muted)
            }
            if !arabic { icon }
        }.frame(maxWidth: .infinity).padding(.bottom, 20)
            .fullScreenCover(isPresented: $showingImage) {
                MerchantProviderImageViewer(url: displayedProfile?.image, name: displayedProfile?.name)
            }
    }
    private var icon: some View {
        Button { showingImage = true } label: {
            MerchantProviderImage(url: displayedProfile?.image, size: profile && !arabic ? 72 : 80,
                                  cornerRadius: profile && !arabic ? 36 : 40)
                .overlay(Circle().strokeBorder(MerchantTheme.subtle, lineWidth: 2))
        }.buttonStyle(.plain)
            .accessibilityLabel(merchantString("profile_view_image", arabic: arabic))
            .accessibilityIdentifier("merchantProfileImage")
    }
}

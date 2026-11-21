import SwiftUI
import Kingfisher

struct MerchantVerificationErrorOverlay: View {
    @EnvironmentObject private var store: MerchantOffersViewModel
    @Environment(\.locale) private var locale
    let error: MerchantVerificationError
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 18) {
                MerchantOfferIcon(name: error == .expired ? "Expired" : "Invalid", size: error == .expired ? 32 : 28, localized: false)
                    .frame(width: 64, height: 64)
                    .background(error == .expired ? MerchantTheme.brandTint : MerchantTheme.error.opacity(0.12), in: Circle())
                Text(merchantString(error.titleKey, arabic: arabic)).merchantFont(20, .bold).foregroundStyle(MerchantTheme.heading)
                Text(merchantString(error.messageKey, arabic: arabic)).merchantFont(14).foregroundStyle(MerchantTheme.secondary)
                MerchantButton(title: merchantString("offers_ok", arabic: arabic)) { store.verificationError = nil }
            }.multilineTextAlignment(.center).padding(24)
                .background(.white, in: RoundedRectangle(cornerRadius: 24)).padding(.horizontal, 35)
                .accessibilityAddTraits(.isModal)
        }
    }
}

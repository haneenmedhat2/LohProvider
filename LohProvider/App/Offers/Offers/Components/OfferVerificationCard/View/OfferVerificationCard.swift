import SwiftUI

struct MerchantOfferVerificationCard: View {
    @Environment(\.locale) private var locale
    let verify: (MerchantSheet) -> Void
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }
    var body: some View {
        VStack(spacing: 8) {
            MerchantOfferIcon(name: "Verify", size: 28)
            Text(text("offers_verify_heading")).merchantFont(14, .bold).foregroundStyle(MerchantTheme.heading)
            Text(text("offers_verify_hint")).merchantFont(11).foregroundStyle(MerchantTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                MerchantOfferAction(title: text("offers_enter_code"), icon: "Code", secondary: true,
                                    fontWeight: .semibold) { verify(.orderCode) }
                MerchantOfferAction(title: text("nav_scan_barcode"), icon: "Scan") { verify(.scanner) }
            }.padding(.top, 4)
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MerchantTheme.brand, lineWidth: 1))
            .accessibilityIdentifier("merchantOffersVerification")
    }
}

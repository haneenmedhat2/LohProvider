import SwiftUI

struct MerchantOrderVerificationBadge: View {
    @Environment(\.locale) private var locale
    let presentation: MerchantOrderPresentation

    var body: some View {
        HStack(spacing: 8) {
            Text(merchantString("offers_method", locale: locale)).merchantFont(12).foregroundStyle(MerchantTheme.muted)
            Text(presentation.verificationText { merchantString($0, locale: locale) })
                .merchantFont(13, .semibold).foregroundStyle(MerchantTheme.body)
            if presentation.method == .barcode {
                Image("LOHOrderVerificationScan").resizable().scaledToFit().frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            } else {
                MerchantOfferIcon(name: "Code", size: 16)
            }
        }.padding(.horizontal, 14).padding(.vertical, 5)
            .background(MerchantTheme.success.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MerchantTheme.success.opacity(0.25)))
    }
}

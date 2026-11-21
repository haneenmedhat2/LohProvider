import SwiftUI

struct MerchantOrderResultCard: View {
    @Environment(\.locale) private var locale
    let presentation: MerchantOrderPresentation
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    var body: some View {
        MerchantCard(padding: 0, radius: 20) {
            VStack(spacing: 0) {
                MerchantOfferIcon(name: "SuccessAr", size: 28, localized: false)
                    .frame(width: 64, height: 64).background(MerchantTheme.success, in: Circle())
                    .padding(.bottom, 14)
                Text(text(presentation.isComplete ? "offers_delivery_success" : "offers_order_found"))
                    .merchantFont(presentation.isComplete ? 18 : 20, .black).foregroundStyle(MerchantTheme.success)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(height: presentation.isComplete ? 23.4 : 30)
                Text(text(presentation.isComplete ? "offers_thanks" : "offers_order_found_hint"))
                    .merchantFont(13).foregroundStyle(MerchantTheme.muted)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true).padding(.top, 6)
                if !presentation.isComplete {
                    MerchantOrderVerificationBadge(presentation: presentation).padding(.top, 16)
                }
            }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .padding(.horizontal, 20).padding(.vertical, 24)
        }.accessibilityElement(children: .combine)
    }
}

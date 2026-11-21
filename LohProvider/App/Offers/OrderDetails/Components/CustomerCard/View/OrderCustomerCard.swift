import SwiftUI

struct MerchantOrderCustomerCard: View {
    @Environment(\.locale) private var locale
    let presentation: MerchantOrderPresentation

    var body: some View {
        MerchantCard(padding: 18, radius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text(merchantString("offers_customer_info", locale: locale))
                    .merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 14) {
                    MerchantOrderCustomerRow(title: merchantString("offers_customer_name", locale: locale),
                                             value: presentation.order.customer(arabic: locale.language.languageCode?.identifier == "ar"),
                                             icon: "CustomerAr")
                    Rectangle().fill(MerchantTheme.border.opacity(0.5)).frame(height: 1)
                        .padding(.leading, 44).accessibilityHidden(true)
                    MerchantOrderCustomerRow(title: merchantString("offers_method", locale: locale),
                                             value: presentation.verificationText(customerRow: true) { merchantString($0, locale: locale) },
                                             icon: presentation.method == .barcode ? "barcode" : "CodeAr",
                                             isSystemIcon: presentation.method == .barcode)
                }
            }
        }
        .shadow(color: MerchantTheme.heading.opacity(0.025), radius: 10, x: 0, y: 3)
    }
}

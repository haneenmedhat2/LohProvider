import SwiftUI

struct MerchantOrderCustomerRow: View {
    let title: String
    let value: String
    let icon: String
    var isSystemIcon = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isSystemIcon {
                    Image(systemName: icon)
                        .resizable().scaledToFit().frame(width: 16, height: 16)
                        .foregroundStyle(MerchantTheme.brand)
                } else {
                    MerchantOfferIcon(name: icon, size: 16, localized: false)
                }
            }
                .frame(width: 32, height: 32).background(MerchantTheme.brandTint, in: Circle())
            Text(title).merchantFont(13).foregroundStyle(MerchantTheme.muted)
            Spacer(minLength: 8)
            Text(value).merchantFont(14, .bold).foregroundStyle(MerchantTheme.heading)
                .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
        }.frame(minHeight: 40)
            .accessibilityElement(children: .combine)
    }
}

import SwiftUI
import Kingfisher

struct MerchantOfferAction: View {
    @Environment(\.locale) private var locale
    let title: String
    let icon: String
    var secondary = false
    var height: CGFloat = 44
    var fontWeight: MerchantFontWeight = .bold
    var iconSize: CGFloat = 15
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                MerchantOfferIcon(name: icon, size: iconSize)
                Text(title).merchantFont(12, fontWeight).multilineTextAlignment(.center)
            }.foregroundStyle(secondary ? MerchantTheme.body : MerchantTheme.ink)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(secondary ? .white : MerchantTheme.brand, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(secondary ? MerchantTheme.border : .clear))
        }.buttonStyle(.plain)
    }
}

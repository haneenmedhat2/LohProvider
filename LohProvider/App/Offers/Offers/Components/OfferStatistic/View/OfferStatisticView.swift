import SwiftUI

struct MerchantOfferStatisticView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: String
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 6) {
            MerchantOfferIcon(name: icon, size: 18)
                .frame(width: 36, height: 36).background(MerchantTheme.brandTint, in: RoundedRectangle(cornerRadius: 10))
            Text(value).merchantFont(18, .black).foregroundStyle(MerchantTheme.heading)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title).merchantFont(11).foregroundStyle(MerchantTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2).minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
    }
}

import SwiftUI

struct MerchantOfferMiniStat: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let value: String
    let title: String
    var bordered = true
    var body: some View {
        VStack(spacing: 3) {
            Text(value).merchantFont(13, .bold).foregroundStyle(MerchantTheme.heading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.85)
            Text(title).merchantFont(10).foregroundStyle(MerchantTheme.muted)
                .multilineTextAlignment(.center).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity).padding(.horizontal, 6)
            .overlay(alignment: .trailing) {
                if bordered && !dynamicTypeSize.isAccessibilitySize { Rectangle().fill(MerchantTheme.border.opacity(0.5)).frame(width: 1).padding(.vertical, 4) }
            }
    }
}

import SwiftUI

struct MerchantReportNavigationIdentity: View {
    let name: String?
    let image: URL?

    var body: some View {
        HStack(spacing: 8) {
            MerchantProviderImage(url: image, size: 40, cornerRadius: 10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(MerchantTheme.brand, lineWidth: 2))
            VStack(alignment: .leading, spacing: 3) {
                Text(name ?? "—").merchantFont(12, .bold).foregroundStyle(MerchantTheme.heading)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Capsule().fill(MerchantTheme.brand).frame(width: 32, height: 2.5)
            }.frame(maxWidth: 60, alignment: .leading)
        }.accessibilityElement(children: .combine)
    }
}

import SwiftUI

struct MerchantOrderMetric: View {
    let title: String
    let value: String
    var subtitle: String?
    var money = false

    var body: some View {
        VStack(spacing: 6) {
            Text(title).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(value).merchantFont(money ? 15 : 12, money ? .bold : .bold)
                .foregroundStyle(money ? MerchantTheme.success : MerchantTheme.heading)
                .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle).merchantFont(11).foregroundStyle(MerchantTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.multilineTextAlignment(.center)
            .padding(.horizontal, 8).padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .combine)
    }
}

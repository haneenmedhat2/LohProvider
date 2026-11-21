import SwiftUI

struct MerchantNotificationTitle: View {
    @Environment(\.locale) private var locale
    let count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Text(merchantString("nav_notifications", locale: locale)).merchantFont(17, .bold)
                .foregroundStyle(MerchantTheme.heading)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if let count, count > 0 {
                Text(count > 99 ? "99+" : count.formatted(.number.locale(locale))).merchantFont(11, .bold)
                    .foregroundStyle(.white).padding(.horizontal, 7)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(MerchantTheme.brand, in: Capsule())
            }
        }.accessibilityElement(children: .combine)
    }
}

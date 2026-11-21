import SwiftUI

struct MerchantNotificationButton: View {
    @Environment(\.locale) private var locale
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("LOHNotificationBell").renderingMode(.template).resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(MerchantTheme.heading)
                .frame(width: 44, height: 44)
                .background(MerchantTheme.brandTint, in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(count > 99 ? "99+" : count.formatted(.number.locale(locale)))
                            .merchantFont(10, .bold).foregroundStyle(.white)
                            .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                            .background(MerchantTheme.error, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: 3, y: -4)
                    }
                }
        }.buttonStyle(.plain)
            .accessibilityLabel(merchantString("nav_notifications", locale: locale))
            .accessibilityValue(count.formatted(.number.locale(locale)))
            .accessibilityIdentifier("merchantNotificationsButton")
    }
}

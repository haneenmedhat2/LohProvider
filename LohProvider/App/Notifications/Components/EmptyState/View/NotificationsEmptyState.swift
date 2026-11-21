import SwiftUI

struct MerchantNotificationsEmptyState: View {
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 12) {
            Image("LOHNotificationBell").renderingMode(.template).resizable().scaledToFit()
                .frame(width: 40, height: 40).foregroundStyle(MerchantTheme.brand).accessibilityHidden(true)
            Text(merchantString("notifications_empty", locale: locale))
                .merchantFont(16, .bold).foregroundStyle(MerchantTheme.heading)
            Text(merchantString("notifications_empty_hint", locale: locale))
                .merchantFont(14).foregroundStyle(MerchantTheme.secondary)
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}

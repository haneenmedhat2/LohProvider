import SwiftUI

struct MerchantNotificationNavigationBar: View {
    @Environment(\.locale) private var locale
    let count: Int?
    let canMarkAllAsRead: Bool
    let onBack: () -> Void
    let onMarkAllAsRead: () -> Void
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - 32)
            let titleWidth = min(180, contentWidth * 0.44)
            let sideWidth = (contentWidth - titleWidth) / 2
            HStack(spacing: 0) {
                Button(action: onBack) {
                    Image(systemName: arabic ? "chevron.right" : "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MerchantTheme.heading)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(merchantString("account_back", locale: locale))
                .frame(width: sideWidth, alignment: .leading)

                MerchantNotificationTitle(count: count)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
                    .frame(width: titleWidth)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("notificationNavigationTitle")

                Button(action: onMarkAllAsRead) {
                    Text(merchantString("notifications_mark_all_read", locale: locale))
                        .merchantFont(13, .medium)
                        .foregroundStyle(MerchantTheme.brand)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(!canMarkAllAsRead)
                .opacity(canMarkAllAsRead ? 1 : 0.45)
                .frame(width: sideWidth, alignment: .trailing)
                .accessibilityIdentifier("markAllNotificationsRead")
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
        }
        .frame(height: 60)
        .background(MerchantTheme.surface.ignoresSafeArea(edges: .top))
    }
}

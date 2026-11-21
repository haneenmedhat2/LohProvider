import SwiftUI

struct MerchantNotificationRow: View {
    @Environment(\.locale) private var locale
    let notification: MerchantNotification
    let isUpdating: Bool
    let open: () -> Void
    let delete: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: open) { content }.buttonStyle(.plain)
                .accessibilityIdentifier("merchantNotification_" + notification.id)
                .accessibilityValue(notification.isRead.map {
                    merchantString($0 ? "notifications_read" : "notifications_unread", locale: locale)
                } ?? "")
            Button(action: delete) {
                Image(systemName: "trash").foregroundStyle(MerchantTheme.error).frame(width: 44, height: 44)
            }.buttonStyle(.plain)
                .accessibilityLabel(merchantString("notifications_delete", locale: locale) + ": " + notification.title)
                .accessibilityIdentifier("deleteNotification_" + notification.id)
        }.padding(12).background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .disabled(isUpdating)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("LOHNotificationBell").renderingMode(.template).resizable().scaledToFit()
                .frame(width: 22, height: 22).foregroundStyle(MerchantTheme.brand)
                .frame(width: 44, height: 44)
                .background(MerchantTheme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if notification.isRead == false {
                        Circle()
                            .fill(MerchantTheme.brand)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(MerchantTheme.surface, lineWidth: 2))
                            .offset(x: 4, y: -4)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title).merchantFont(14, notification.isRead == true ? .medium : .bold).foregroundStyle(MerchantTheme.heading)
                Text(notification.body).merchantFont(12).foregroundStyle(MerchantTheme.secondary).lineSpacing(3)
                Text(notification.createdAt).merchantFont(11).foregroundStyle(MerchantTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

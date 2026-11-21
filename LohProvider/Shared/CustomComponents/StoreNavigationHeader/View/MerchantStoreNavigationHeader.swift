import SwiftUI

struct MerchantStoreNavigationHeader: View {
    let greeting: String
    let name: String?
    let image: URL?
    var notificationCount = 0
    var onNotifications: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            MerchantProviderImage(url: image, size: 54, cornerRadius: 14)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MerchantTheme.brand, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                Text(name ?? "—").merchantFont(24, .extraBold).foregroundStyle(MerchantTheme.heading)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Capsule().fill(MerchantTheme.brand).frame(width: 38, height: 3).padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let onNotifications {
                MerchantNotificationButton(count: notificationCount, action: onNotifications)
            }
        }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
            .background(MerchantTheme.surface)
    }
}

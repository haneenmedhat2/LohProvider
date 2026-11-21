import SwiftUI

struct MerchantOfferOrderStatus: View {
    @Environment(\.locale) private var locale
    let order: MerchantOfferOrder
    var preview = false
    private var pending: Bool { preview || ["pending", "بانتظار التسليم"].contains(order.deliveryStatus?.lowercased() ?? "") }
    private var color: Color { order.isDelivered ? MerchantTheme.success : pending ? MerchantTheme.error : MerchantTheme.muted }
    private var title: String {
        if order.delivered { return merchantString("offers_delivered", locale: locale) }
        if let status = order.statusText, !status.isEmpty { return status }
        if order.isDelivered { return merchantString("offers_delivered", locale: locale) }
        return pending ? merchantString("offers_waiting", locale: locale) : order.deliveryStatus ?? "—"
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title).merchantFont(11, .semibold).fixedSize(horizontal: false, vertical: true)
            Circle().fill(color).frame(width: 6, height: 6).accessibilityHidden(true)
        }
        .foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.25)))
    }
}

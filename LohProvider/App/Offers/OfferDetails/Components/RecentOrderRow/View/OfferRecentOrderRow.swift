import SwiftUI

struct MerchantOfferRecentOrderRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var direction
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let order: MerchantOfferOrder
    let offer: MerchantOffer
    var preview = false
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        HStack(spacing: 10) {
            MerchantOfferIcon(name: "DetailChevron", size: 16, localized: false)
                .scaleEffect(x: direction == .rightToLeft ? 1 : -1, y: 1)
            MerchantOfferIcon(name: "CustomerDetailAr", size: 18, localized: false)
                .frame(width: 36, height: 36).background(MerchantTheme.brandTint, in: Circle())
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                VStack(alignment: .leading, spacing: 0) {
                    Text(order.customer(arabic: arabic)).merchantFont(14, .bold).foregroundStyle(MerchantTheme.heading)
                    Text(order.couponName ?? offer.name(arabic: arabic)).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                    MerchantOfferOrderStatus(order: order, preview: preview)
                    Text(order.createdAtText ?? MerchantOfferFormat.date(order.purchasedAt, arabic: arabic, time: true))
                        .merchantFont(11).foregroundStyle(MerchantTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }.layoutPriority(1)
            }
        }.padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 73)
            .background(MerchantTheme.surface).contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }
}

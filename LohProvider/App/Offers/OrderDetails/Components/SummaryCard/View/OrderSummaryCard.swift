import SwiftUI

struct MerchantOrderSummaryCard: View {
    @Environment(\.locale) private var locale
    let presentation: MerchantOrderPresentation
    private var order: MerchantOfferOrder { presentation.order }
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        MerchantCard(padding: 18, radius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text(merchantString("nav_order_details", locale: locale))
                    .merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    MerchantOfferArtwork(offer: presentation.artwork, size: 56, order: true)
                    Text(order.couponName ?? presentation.offer.name(arabic: arabic))
                        .merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let status = presentation.statusText {
                        Text(status).merchantFont(12, .bold).foregroundStyle(MerchantTheme.success)
                            .frame(height: 18)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(MerchantTheme.successTint, in: RoundedRectangle(cornerRadius: 8))
                    }
                }.environment(\.layoutDirection, .leftToRight)
                HStack(alignment: .top, spacing: 0) {
                    MerchantOrderMetric(title: merchantString("offers_price", locale: locale),
                                        value: MerchantOfferFormat.money(order.details?.priceHalalas ?? presentation.offer.priceHalalas,
                                                                         arabic: arabic, currency: order.details?.currency ?? presentation.offer.currency),
                                        money: true)
                    metricDivider
                    MerchantOrderMetric(title: merchantString("offers_purchase_date", locale: locale),
                                        value: order.details?.purchasedAt.dateText ?? MerchantOfferFormat.date(order.purchasedAt, arabic: arabic),
                                        subtitle: order.details?.purchasedAt.timeText ?? MerchantOfferFormat.date(order.purchasedAt, arabic: arabic, time: true))
                    metricDivider
                    MerchantOrderMetric(title: merchantString("offers_valid_until", locale: locale),
                                        value: order.details?.validUntil.dateText ?? MerchantOfferFormat.date(order.expiresAt, arabic: arabic),
                                        subtitle: order.details?.validUntil.timeText ?? MerchantOfferFormat.date(order.expiresAt, arabic: arabic, time: true))
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(MerchantTheme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(MerchantTheme.border.opacity(0.45), lineWidth: 1)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .shadow(color: MerchantTheme.heading.opacity(0.025), radius: 10, x: 0, y: 3)
    }

    private var metricDivider: some View {
        Rectangle().fill(MerchantTheme.border.opacity(0.5))
            .frame(width: 1).padding(.vertical, 14)
            .accessibilityHidden(true)
    }
}

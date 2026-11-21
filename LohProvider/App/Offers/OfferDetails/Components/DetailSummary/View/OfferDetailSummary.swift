import SwiftUI

struct MerchantOfferDetailSummary: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var titleHeight = 24.0
    @ScaledMetric private var captionHeight = 18.0
    let offer: MerchantOffer
    let coupon: MerchantCoupon?
    let width: CGFloat
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var stacked: Bool { dynamicTypeSize.isAccessibilitySize || width < 350 }

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            MerchantOfferArtwork(offer: offer, size: 120, hero: true)
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        title.fixedSize(horizontal: true, vertical: true).frame(height: titleHeight)
                        Spacer(minLength: 0)
                        status
                    }
                    VStack(alignment: .leading, spacing: 6) { title; status }
                }
                if let coupon {
                    HStack(spacing: 8) {
                        Image("LOHSettlementCalendarSmall").frame(width: 14, height: 14).accessibilityHidden(true)
                        Text(coupon.updatedAtText ?? merchantString("offers_updated", locale: locale) + " " + MerchantOfferFormat.date(coupon.updatedAt, arabic: arabic))
                            .merchantFont(12).foregroundStyle(MerchantTheme.muted).fixedSize(horizontal: false, vertical: true)
                            .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : captionHeight)
                    }.padding(.bottom, 4)
                }
                MerchantOfferDetailValue(title: merchantString("offers_price", locale: locale), value: MerchantOfferFormat.money(coupon?.priceHalalas ?? offer.priceHalalas, arabic: arabic, currency: coupon?.currency ?? offer.currency), calendar: false)
                MerchantOfferDetailValue(title: merchantString("offers_publish_date", locale: locale), value: coupon?.publishedAtText ?? MerchantOfferFormat.date(coupon?.publishedAt ?? offer.createdAt, arabic: arabic), calendar: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MerchantTheme.subtle))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var title: some View {
        Text(offer.name(arabic: arabic)).merchantFont(16, .bold).foregroundStyle(MerchantTheme.heading)
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var status: some View {
        if let coupon {
            let active = coupon.status.lowercased() == "active"
            Text(coupon.statusText).merchantFont(12, .bold)
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : captionHeight)
                .foregroundStyle(active ? MerchantTheme.success : MerchantTheme.secondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(active ? MerchantTheme.successTint : MerchantTheme.subtle, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

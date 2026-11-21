import SwiftUI

struct MerchantOfferRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let offer: MerchantOffer
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }
    private func money(_ amount: Int) -> String {
        (Decimal(amount) / 100).formatted(.number.locale(locale).precision(.fractionLength(0...2))) + " " + (offer.currency ?? "SAR")
    }
    private var publishedDate: String {
        guard let date = offer.createdAt else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = MerchantOfferFormat.calendar
        formatter.timeZone = MerchantOfferFormat.calendar.timeZone
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    private var statisticsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 0))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                MerchantOfferArtwork(offer: offer, size: 76)
                VStack(alignment: .leading, spacing: 6) {
                    Text(offer.name(arabic: locale.language.languageCode?.identifier == "ar"))
                        .merchantFont(16, .bold).foregroundStyle(MerchantTheme.heading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image("LOHSettlementCalendarSmall").frame(width: 14, height: 14).accessibilityHidden(true)
                        Text(text("offers_publish_date") + " " + publishedDate)
                            .merchantFont(11).foregroundStyle(MerchantTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MerchantTheme.muted).accessibilityHidden(true)
            }
            statisticsLayout {
                MerchantOfferMiniStat(value: money(offer.salesHalalas), title: text("offers_sales"))
                MerchantOfferMiniStat(value: offer.salesCount.formatted(.number.locale(locale)), title: text("offers_orders"))
                MerchantOfferMiniStat(value: money(offer.lohHalalas), title: text("offers_loh"), bordered: false)
            }.padding(.vertical, 10).background(MerchantTheme.background, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(14).background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MerchantTheme.subtle))
        .shadow(color: .black.opacity(0.035), radius: 5, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

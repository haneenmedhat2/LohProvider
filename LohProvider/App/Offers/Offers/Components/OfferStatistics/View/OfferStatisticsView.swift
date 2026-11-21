import SwiftUI

struct MerchantOfferStatisticsView: View {
    @EnvironmentObject private var store: MerchantOffersViewModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }
    private var salesTitle: String {
        guard let currency = store.stats?.currency, !currency.isEmpty else { return text("offers_sales_currency") }
        return text("offers_sales") + "\n(" + currency + ")"
    }
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), alignment: .center, spacing: 12) {
            MerchantOfferStatisticView(icon: "Total", title: text("offers_total"), value: (store.stats?.totalOffers ?? 0).formatted(.number.locale(locale)))
            MerchantOfferStatisticView(icon: "Active", title: text("offers_active"), value: (store.stats?.activeOffers ?? 0).formatted(.number.locale(locale)))
            MerchantOfferStatisticView(icon: "Sales", title: salesTitle, value: (Decimal(store.stats?.salesHalalas ?? 0) / 100).formatted(.number.locale(locale).precision(.fractionLength(0...2))))
            MerchantOfferStatisticView(icon: "Orders", title: text("offers_orders"), value: (store.stats?.salesCount ?? 0).formatted(.number.locale(locale)))
        }.padding(.horizontal, 8).padding(.vertical, 16)
            .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MerchantTheme.subtle, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            .accessibilityIdentifier("merchantOffersStatistics")
    }
}

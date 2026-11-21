import SwiftUI

struct MerchantOfferDetailValue: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var labelHeight = 18.0
    @ScaledMetric private var valueHeight = 21.0
    let title: String
    let value: String
    let calendar: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { label; Spacer(minLength: 4); amount.fixedSize() }
            VStack(alignment: .leading, spacing: 4) { label; amount }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private var label: some View {
        HStack(spacing: 6) {
            if calendar {
                Image("LOHSettlementCalendarSmall").frame(width: 14, height: 14).accessibilityHidden(true)
            } else { MerchantOfferIcon(name: "PriceAr", size: 14, localized: false) }
            Text(title).merchantFont(12).foregroundStyle(MerchantTheme.muted).fixedSize()
                .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : labelHeight)
        }
    }

    private var amount: some View {
        Text(value).merchantFont(14, .semibold).foregroundStyle(MerchantTheme.heading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : valueHeight)
    }
}

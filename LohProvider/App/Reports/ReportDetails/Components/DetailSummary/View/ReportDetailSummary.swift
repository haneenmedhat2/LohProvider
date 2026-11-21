import SwiftUI

struct MerchantReportDetailSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let totals: MerchantReportTotals
    let currency: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 1) { metrics }
            } else {
                HStack(spacing: 1) { metrics }.fixedSize(horizontal: false, vertical: true)
            }
        }.background(MerchantTheme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MerchantTheme.subtle))
            .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder private var metrics: some View {
        MerchantReportDetailMetric(title: "report_orders", value: Decimal(totals.ordersCount), icon: "OrdersDetail", tint: MerchantTheme.reportOrdersTint)
        MerchantReportDetailMetric(title: "report_sales", value: totals.salesTotal, currency: currency, icon: "SalesDetail", tint: MerchantTheme.brandTint)
        MerchantReportDetailMetric(title: "report_average", value: totals.averageOrderValue, currency: currency, icon: "Average", tint: MerchantTheme.successTint)
    }
}

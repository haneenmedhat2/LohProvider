import SwiftUI

struct MerchantReportDetailTableTotals: View {
    @Environment(\.locale) private var locale
    @ScaledMetric private var rowHeight = 74.0
    let totals: MerchantReportTotals
    let currency: String
    let width: CGFloat

    var body: some View {
        HStack(spacing: 1) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    summaryTitle
                    MerchantReportIcon(name: "SummaryAr", size: 18, localized: false)
                }.fixedSize(horizontal: true, vertical: false)
                VStack(spacing: 5) {
                    MerchantReportIcon(name: "SummaryAr", size: 18, localized: false)
                    summaryTitle
                }
            }.foregroundStyle(MerchantTheme.heading).padding(.horizontal, 6)
                .frame(width: columnWidth).frame(minHeight: rowHeight, maxHeight: .infinity)
                .background(MerchantTheme.reportTableHeader)
            metric(MerchantReportOverview.number(Decimal(totals.ordersCount)), title: "report_orders")
            metric(MerchantReportOverview.number(totals.salesTotal) + " " + currency, title: "report_sales")
            metric(MerchantReportOverview.number(totals.averageOrderValue) + " " + currency, title: "report_average")
        }.fixedSize(horizontal: false, vertical: true).background(MerchantTheme.subtle)
    }

    private var columnWidth: CGFloat { (width - 3) / 4 }
    private var summaryTitle: some View {
        Text(merchantString("report_summary", locale: locale)).merchantFont(13, .bold)
            .lineLimit(1).minimumScaleFactor(0.7)
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
    private func metric(_ value: String, title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).merchantFont(13, .bold).foregroundStyle(MerchantTheme.heading)
                .fixedSize(horizontal: false, vertical: true)
            Text(merchantString(title, locale: locale)).merchantFont(10).foregroundStyle(MerchantTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.multilineTextAlignment(.center).padding(.horizontal, 6).padding(.vertical, 12)
            .frame(width: columnWidth).frame(minHeight: rowHeight, maxHeight: .infinity, alignment: .top)
            .background(MerchantTheme.reportTableHeader)
    }
}

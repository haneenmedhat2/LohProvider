import SwiftUI

struct MerchantReportSummaryContent: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var totalHeight = 30.0
    @ScaledMetric private var captionHeight = 20.0
    let overview: MerchantReportOverview
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                MerchantReportStatisticCard(title: "report_orders", statistic: overview.orders, currency: nil,
                                            comparison: overview.comparison, icon: "Orders")
                MerchantReportStatisticCard(title: "report_sales", statistic: overview.sales, currency: overview.currency,
                                            comparison: overview.comparison, icon: "Sales")
            }.environment(\.layoutDirection, .leftToRight)
            VStack(spacing: 4) {
                HStack {
                    Text(merchantString("report_sales_heading", locale: locale)).merchantFont(15, .bold)
                        .foregroundStyle(MerchantTheme.heading)
                    Spacer()
                    Text(overview.currency).merchantFont(11).foregroundStyle(MerchantTheme.muted)
                }
                MerchantSalesChartView(points: overview.points, currency: overview.currency)
            }
            VStack(spacing: 2) {
                (Text(MerchantReportOverview.number(overview.sales.total))
                    .font(MerchantTypography.font(22, weight: .black, arabic: arabic))
                 + Text(" " + overview.currency).font(MerchantTypography.font(16, weight: .black, arabic: arabic)))
                    .foregroundStyle(MerchantTheme.success).lineLimit(1).minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true).frame(height: totalHeight)
                Text(merchantString("report_sales", locale: locale)).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                    .fixedSize(horizontal: false, vertical: true).frame(height: captionHeight)
                MerchantReportAPIChange(statistic: overview.sales, comparison: overview.comparison, prominent: true)
                    .padding(.top, 4)
            }.frame(maxWidth: .infinity).padding(.bottom, 4)
        }
    }
}

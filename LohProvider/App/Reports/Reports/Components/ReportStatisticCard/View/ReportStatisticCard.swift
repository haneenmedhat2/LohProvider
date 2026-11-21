import SwiftUI

struct MerchantReportStatisticCard: View {
    @Environment(\.locale) private var locale
    @ScaledMetric private var valueHeight = 26.0
    @ScaledMetric private var captionHeight = 18.0
    let title: String
    let statistic: MerchantReportStatistic
    let currency: String?
    let comparison: String
    let icon: String

    var body: some View {
        MerchantCard(padding: 0, radius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    MerchantReportIcon(name: icon, size: 20)
                        .frame(width: 40, height: 40)
                        .background(icon == "Orders" ? MerchantTheme.reportOrdersTint : MerchantTheme.brandTint,
                                    in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 0) {
                        (Text(MerchantReportOverview.number(statistic.total))
                            .font(MerchantTypography.font(currency == nil ? 22 : 20, weight: .black, arabic: arabic))
                         + Text(currency.map { " " + $0 } ?? "")
                            .font(MerchantTypography.font(14, weight: .black, arabic: arabic)))
                            .foregroundStyle(MerchantTheme.heading).lineLimit(1).minimumScaleFactor(0.55)
                            .fixedSize(horizontal: false, vertical: true).frame(height: valueHeight)
                        Text(merchantString(title, locale: locale)).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                            .lineLimit(1).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true).frame(height: captionHeight)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                MerchantReportAPIChange(statistic: statistic, comparison: comparison)
            }.padding(.horizontal, 12).padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
}

import SwiftUI

struct MerchantReportMetric: View {
    @Environment(\.locale) private var locale
    let key: String
    let value: String
    let icon: String
    var detail = false
    var change: Double?
    var apiChange: MerchantReportStatistic?
    var comparison: String?
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var color: Color { icon == "Average" ? MerchantTheme.success : icon.hasPrefix("Orders") ? Color.purple : MerchantTheme.brand }
    var body: some View {
        VStack(alignment: detail ? .center : .leading, spacing: 6) {
            MerchantReportIcon(name: icon, size: detail ? 18 : arabic ? 20 : 22)
                .frame(width: detail ? 36 : 40, height: detail ? 36 : 40)
                .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
            Text(value).merchantFont(detail ? 17 : 22, .black).foregroundStyle(MerchantTheme.heading)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(merchantString(key, arabic: arabic)).merchantFont(detail ? 10 : 12).foregroundStyle(MerchantTheme.muted)
                .multilineTextAlignment(detail ? .center : .leading)
            if !detail {
                if let apiChange {
                    MerchantReportAPIChange(statistic: apiChange, comparison: comparison ?? "").padding(.top, 4)
                } else { MerchantReportChange(change: change).padding(.top, 4) }
            }
        }.frame(maxWidth: .infinity, alignment: detail ? .center : .leading)
    }
}

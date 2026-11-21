import SwiftUI

struct MerchantReportAPIChange: View {
    @Environment(\.locale) private var locale
    @ScaledMetric private var changeHeight = 20.0
    let statistic: MerchantReportStatistic
    let comparison: String
    var prominent = false
    private var color: Color {
        statistic.trend == "down" ? MerchantTheme.error : statistic.trend == "up" ? MerchantTheme.success : MerchantTheme.muted
    }
    var body: some View {
        VStack(alignment: prominent ? .center : .leading, spacing: prominent ? 4 : 8) {
            HStack(spacing: 4) {
                if statistic.trend == "up" || statistic.trend == "down" {
                    MerchantReportIcon(name: "Growth", size: prominent ? 10 : 12, tint: color)
                        .rotationEffect(.degrees(statistic.trend == "down" ? 180 : 0))
                } else { Image(systemName: "minus").font(.system(size: 10, weight: .bold)) }
                Text(statistic.trend == "unknown" ? "—" : abs(statistic.changePercent).formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(0...2))) + "%")
            }.merchantFont(prominent ? 12 : 13, .bold).foregroundStyle(color)
                .frame(height: changeHeight)
                .padding(.horizontal, prominent ? 8 : 0).padding(.vertical, prominent ? 2 : 0)
                .background(prominent ? (statistic.trend == "up" ? MerchantTheme.successTint : color.opacity(0.12)) : .clear, in: Capsule())
            Text(comparison).merchantFont(11).foregroundStyle(MerchantTheme.muted)
                .multilineTextAlignment(prominent ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }.environment(\.layoutDirection, .leftToRight)
    }
}

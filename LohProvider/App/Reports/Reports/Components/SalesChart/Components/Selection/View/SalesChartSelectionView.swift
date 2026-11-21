import SwiftUI

struct MerchantSalesChartSelectionView: View {
    @Environment(\.locale) private var locale
    let point: MerchantReportPoint
    let currency: String
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(point.label).merchantFont(11, .semibold).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    MerchantReportIcon(name: "Close", size: 12, localized: false).frame(width: 28, height: 28)
                }.buttonStyle(.plain).accessibilityLabel(merchantString("report_clear_selection", locale: locale))
            }
            Text(point.date).merchantFont(9).foregroundStyle(MerchantTheme.muted)
            Text(MerchantReportOverview.number(point.value) + " " + currency)
                .merchantFont(13, .bold).foregroundStyle(MerchantTheme.success).lineLimit(1).minimumScaleFactor(0.6)
        }.padding(.horizontal, 10).padding(.bottom, 8)
            .foregroundStyle(MerchantTheme.heading)
            .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(MerchantTheme.border))
            .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }
}

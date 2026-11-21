import SwiftUI

struct MerchantReportDetailContent: View {
    let report: MerchantReportDetailPresentation
    let width: CGFloat
    let export: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            MerchantReportDetailSummary(totals: report.stats, currency: report.currency)
            MerchantReportDetailTable(report: report, width: width)
            if !report.note.isEmpty {
                HStack(spacing: 6) {
                    MerchantReportIcon(name: "InfoAr", size: 14, localized: false)
                    Text(report.note).merchantFont(11).foregroundStyle(MerchantTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .leftToRight)
            }
            MerchantReportDetailActions(export: export)
        }
    }
}

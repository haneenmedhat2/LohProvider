import SwiftUI

struct MerchantReportExportFileSummary: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let period: String

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            HStack(spacing: 8) {
                Text("PDF").font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(MerchantTheme.error).frame(width: 28, height: 28)
                    .background(MerchantTheme.reportPDFTint, in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(merchantString("report_sales_report", locale: locale)).merchantFont(12, .semibold).foregroundStyle(MerchantTheme.heading)
                        .fixedSize(horizontal: false, vertical: true).frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 18)
                    Text(merchantString("report_pdf_format", locale: locale)).merchantFont(11).foregroundStyle(MerchantTheme.muted)
                        .fixedSize(horizontal: false, vertical: true).frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 16.5)
                }.fixedSize(horizontal: true, vertical: false)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            MerchantReportExportPeriodLabel(period: period, compact: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MerchantTheme.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

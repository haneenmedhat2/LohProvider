import SwiftUI

struct MerchantReportExportPeriodLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let period: String
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            MerchantReportIcon(name: compact ? "ExportFileCalendar" : "ExportCalendar", size: compact ? 14 : 16, localized: false)
            Text(period).merchantFont(compact ? 12 : 13)
                .foregroundStyle(MerchantTheme.body).fixedSize(horizontal: false, vertical: true)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : (compact ? 18 : 20))
        }.accessibilityElement(children: .combine)
    }
}

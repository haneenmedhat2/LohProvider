import SwiftUI

struct MerchantReportExportHeading: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var titleHeight = 26.0
    @ScaledMetric private var subtitleHeight = 20.0
    let ready: Bool
    let saved: Bool

    var body: some View {
        VStack(spacing: 6) {
            if ready {
                MerchantReportIcon(name: "ExportSuccess", size: 26, localized: false)
                    .frame(width: 60, height: 60).background(MerchantTheme.success, in: Circle())
                    .padding(.bottom, 8)
            }
            Text(merchantString(ready ? "report_ready" : "report_download", locale: locale))
                .merchantFont(17, .bold).fixedSize(horizontal: false, vertical: true)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : titleHeight).accessibilityAddTraits(.isHeader)
            Text(merchantString(ready ? (saved ? "report_saved" : "report_ready_hint") : "report_download_hint", locale: locale))
                .merchantFont(13).foregroundStyle(MerchantTheme.muted)
                .fixedSize(horizontal: false, vertical: true).frame(height: dynamicTypeSize.isAccessibilitySize ? nil : subtitleHeight)
        }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
    }
}

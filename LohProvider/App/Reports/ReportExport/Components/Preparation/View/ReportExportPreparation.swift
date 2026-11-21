import SwiftUI

struct MerchantReportExportPreparation: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var titleHeight = 26.0
    @ScaledMetric private var subtitleHeight = 20.0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                MerchantReportIcon(name: "ExportRing", size: 80, localized: false)
                MerchantReportExportPDFIcon()
            }.frame(width: 80, height: 80).accessibilityHidden(true)
            Text(merchantString("report_preparing", locale: locale)).merchantFont(17, .bold)
                .fixedSize(horizontal: false, vertical: true).frame(height: dynamicTypeSize.isAccessibilitySize ? nil : titleHeight)
                .padding(.top, 16).accessibilityAddTraits(.isHeader)
            Text(merchantString("report_preparing_hint", locale: locale)).merchantFont(13)
                .foregroundStyle(MerchantTheme.muted).fixedSize(horizontal: false, vertical: true)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : subtitleHeight).padding(.top, 6)
            MerchantReportExportProgress().padding(.top, 20)
            HStack(spacing: 10) {
                MerchantReportIcon(name: "ExportClock", size: 28, localized: false)
                Text(merchantString("report_preparing_destination", locale: locale)).merchantFont(12)
                    .foregroundStyle(MerchantTheme.body).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).frame(maxWidth: .infinity, minHeight: 52)
                .background(MerchantTheme.background, in: RoundedRectangle(cornerRadius: 12)).padding(.top, 16)
        }
    }
}

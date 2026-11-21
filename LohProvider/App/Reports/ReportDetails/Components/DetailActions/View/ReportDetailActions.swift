import SwiftUI

struct MerchantReportDetailActions: View {
    @Environment(\.locale) private var locale
    let export: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            action("report_download_pdf", icon: "DetailDownload", secondary: false)
            action("report_share", icon: "ShareAr", secondary: true)
        }.padding(.top, 4).padding(.bottom, 20)
    }

    private func action(_ key: String, icon: String, secondary: Bool) -> some View {
        Button(action: export) {
            HStack(spacing: 8) {
                MerchantReportIcon(name: icon, size: 18, localized: false)
                Text(merchantString(key, locale: locale)).merchantFont(16, secondary ? .bold : .bold)
                    .fixedSize(horizontal: false, vertical: true)
            }.foregroundStyle(secondary ? MerchantTheme.body : MerchantTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(secondary ? MerchantTheme.surface : MerchantTheme.brand, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(secondary ? MerchantTheme.border : .clear))
                .environment(\.layoutDirection, .leftToRight)
        }.buttonStyle(.plain).accessibilityIdentifier(key)
    }
}

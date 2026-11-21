import SwiftUI

struct MerchantReportExportActionLabel: View {
    let title: String
    let secondary: Bool

    var body: some View {
        HStack(spacing: 8) {
            MerchantReportIcon(name: secondary ? "ExportShare" : "ExportDownload", size: 18, localized: false)
            Text(title).merchantFont(16, secondary ? .bold : .bold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(secondary ? MerchantTheme.body : MerchantTheme.ink)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(secondary ? MerchantTheme.surface : MerchantTheme.brand, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(secondary ? MerchantTheme.border : .clear))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

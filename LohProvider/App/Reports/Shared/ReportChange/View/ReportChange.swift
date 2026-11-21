import SwiftUI

struct MerchantReportChange: View {
    @Environment(\.locale) private var locale
    let change: Double?
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let change {
                HStack(spacing: 4) {
                    MerchantReportIcon(name: "Growth", size: arabic ? 12 : 14)
                        .rotationEffect(.degrees(change < 0 ? 180 : 0))
                    Text(String(format: "%.0f%%", abs(change))).merchantFont(12, .bold)
                }.foregroundStyle(change < 0 ? MerchantTheme.error : MerchantTheme.success)
            } else {
                Text("—").merchantFont(12).foregroundStyle(MerchantTheme.muted)
            }
            Text(merchantString("report_previous_period", arabic: arabic)).merchantFont(10).foregroundStyle(MerchantTheme.muted)
        }
    }
}

import SwiftUI

struct MerchantReportPeriodButton: View {
    @EnvironmentObject private var store: MerchantReportsViewModel
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @Environment(\.locale) private var locale
    var periodLabel: String? = nil
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var displayPeriod: String {
        if let periodLabel, !periodLabel.isEmpty { return periodLabel }
        return MerchantReportFormat.period(store.period, arabic: arabic)
    }
    var body: some View {
        Button { coordinator.sheet = .reportPeriod } label: {
            HStack(spacing: 10) {
                MerchantReportIcon(name: "Calendar", size: 18)
                Text(displayPeriod)
                    .merchantFont(14, .medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                MerchantReportIcon(name: "Chevron", size: 16)
            }.foregroundStyle(MerchantTheme.body).padding(.horizontal, 16).frame(minHeight: 50)
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MerchantTheme.border))
        }.buttonStyle(.plain).accessibilityIdentifier("reportPeriod")
    }
}

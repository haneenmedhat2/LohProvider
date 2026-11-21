import SwiftUI

struct MerchantReportDetailMetric: View {
    @Environment(\.locale) private var locale
    @ScaledMetric private var valueHeight = 24.0
    @ScaledMetric private var captionHeight = 16.0
    let title: String
    let value: Decimal
    var currency: String? = nil
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            MerchantReportIcon(name: icon + "Ar", size: 18, localized: false)
                .frame(width: 36, height: 36)
                .background(tint, in: RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 4)
            (Text(MerchantReportOverview.number(value))
                .font(MerchantTypography.font(currency == nil ? 20 : 18, weight: .black, arabic: arabic))
             + Text(currency.map { " " + $0 } ?? "")
                .font(MerchantTypography.font(12, weight: .black, arabic: arabic)))
                .foregroundStyle(MerchantTheme.heading).lineLimit(1).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true).frame(height: valueHeight)
            Text(merchantString(title, locale: locale)).merchantFont(10).foregroundStyle(MerchantTheme.muted)
                .fixedSize(horizontal: false, vertical: true).frame(minHeight: captionHeight)
        }.multilineTextAlignment(.center).padding(.horizontal, 8).padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MerchantTheme.surface)
    }

    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
}

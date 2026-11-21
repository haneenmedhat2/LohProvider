import SwiftUI

struct MerchantBrandHeader: View {
    let arabic: Bool
    var body: some View {
        VStack(spacing: 0) {
            Image(arabic ? "LOHLogoArabic" : "LOHLogoEnglish")
                .resizable().scaledToFit()
                .frame(width: arabic ? 134 : 350, height: arabic ? 56 : 52)
                .accessibilityLabel(merchantString("brand_name", arabic: arabic))
            Text(merchantString("brand_name", arabic: arabic))
                .merchantFont(arabic ? 28 : 20, .bold)
                .foregroundStyle(MerchantTheme.ink)
                .frame(minHeight: arabic ? 48 : 30)
            Text(merchantString("brand_tagline", arabic: arabic))
                .merchantFont(arabic ? 14 : 13).foregroundStyle(MerchantTheme.secondary)
                .frame(minHeight: 22)
            RoundedRectangle(cornerRadius: 2).fill(MerchantTheme.brand)
                .frame(width: 36, height: 3).padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

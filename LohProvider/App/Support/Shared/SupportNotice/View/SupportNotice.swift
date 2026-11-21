import SwiftUI

struct MerchantSupportNotice: View {
    @Environment(\.locale) private var locale
    let key: String
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    var body: some View {
        HStack(spacing: 10) {
            MerchantSupportIcon(name: "Info", size: arabic ? 18 : 22)
            Text(merchantString(key, arabic: locale.language.languageCode?.identifier == "ar"))
                .merchantFont(12).foregroundStyle(MerchantTheme.body).frame(maxWidth: .infinity)
        }.padding(14).background(MerchantTheme.brandTint).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

import SwiftUI

struct MerchantButton: View {
    @Environment(\.locale) private var locale
    let title: String
    var secondary = false
    var isLoading = false
    var foregroundColor: Color = MerchantTheme.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().tint(foregroundColor) }
                Text(title)
            }
        }
        .buttonStyle(MainButtonStyle(
            background: LinearGradient(colors: [secondary ? .white : MerchantTheme.brand], startPoint: .top, endPoint: .bottom),
            foregroundColor: foregroundColor,
            height: 54,
            cornerRadius: MerchantTheme.Radius.button,
            horizontalPadding: 0,
            font: MerchantTypography.font(18, weight: .bold, arabic: locale.language.languageCode?.identifier == "ar")
        ))
        .overlay(RoundedRectangle(cornerRadius: MerchantTheme.Radius.button).stroke(secondary ? MerchantTheme.border : .clear))
        .disabled(isLoading)
    }
}

import SwiftUI

private struct MerchantTextStyle: ViewModifier {
    @Environment(\.locale) private var locale
    let size: CGFloat
    let weight: MerchantFontWeight
    func body(content: Content) -> some View {
        content.font(MerchantTypography.font(size, weight: weight, arabic: locale.language.languageCode?.identifier == "ar"))
    }
}

extension View {
    func merchantFont(_ size: CGFloat, _ weight: MerchantFontWeight = .regular) -> some View {
        modifier(MerchantTextStyle(size: size, weight: weight))
    }
}


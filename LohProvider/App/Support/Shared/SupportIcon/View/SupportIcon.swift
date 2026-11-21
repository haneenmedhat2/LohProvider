import SwiftUI

struct MerchantSupportIcon: View {
    @Environment(\.locale) private var locale
    let name: String
    var size: CGFloat
    var color: Color? = nil
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    var body: some View {
        Image("LOHSupport" + name + (arabic ? "Ar" : "En"))
            .renderingMode(color == nil ? .original : .template)
            .resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
            .foregroundStyle(color ?? .primary)
    }
}

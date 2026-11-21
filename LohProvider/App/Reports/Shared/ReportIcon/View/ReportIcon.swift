import SwiftUI

struct MerchantReportIcon: View {
    @Environment(\.locale) private var locale
    let name: String
    var size: CGFloat = 18
    var localized = true
    var tint: Color? = nil
    var body: some View {
        Image("LOHReport" + name + (localized ? (locale.language.languageCode?.identifier == "ar" ? "Ar" : "En") : ""))
            .renderingMode(tint == nil ? .original : .template)
            .resizable().scaledToFit().frame(width: size, height: size)
            .foregroundStyle(tint ?? .primary).accessibilityHidden(true)
    }
}

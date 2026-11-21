import SwiftUI
import Kingfisher

struct MerchantOfferIcon: View {
    @Environment(\.locale) private var locale
    let name: String
    var size: CGFloat = 18
    var localized = true
    var body: some View {
        Image("LOHOffer" + name + (localized ? (locale.language.languageCode?.identifier == "ar" ? "Ar" : "En") : ""))
            .resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
    }
}

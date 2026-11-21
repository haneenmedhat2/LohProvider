import SwiftUI
import Kingfisher

/// Original exported Figma art, or original layers at their original coordinates.
struct MerchantOfferArtwork: View {
    @Environment(\.locale) private var locale
    let offer: MerchantOffer
    var size: CGFloat = 90
    var hero = false
    var order = false
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    var body: some View {
        Group {
            if let image = offer.image {
                KFImage(image)
                    .placeholder { placeholder }
                    .cancelOnDisappear(true).loadDiskFileSynchronously()
                    .resizable().scaledToFill().frame(width: size, height: size)
            } else if offer.artwork.isEmpty {
                placeholder
            } else if offer.id == "mojito" && (hero || order) {
                Image("LOHOffer" + (hero ? "Hero" : "Order") + (arabic ? "Ar" : "En"))
                    .resizable().scaledToFit()
            } else if offer.artwork == "Amber" || (!arabic && offer.artwork == "Latte") {
                layeredArtwork
            } else {
                Image("LOHOffer" + offer.artwork + (arabic ? "Ar" : "En")).resizable().scaledToFit()
            }
        }.frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .environment(\.layoutDirection, .leftToRight).accessibilityHidden(true)
    }
    private var placeholder: some View {
        Image(systemName: "tag").resizable().scaledToFit().padding(size * 0.3)
            .foregroundStyle(MerchantTheme.muted).frame(width: size, height: size).background(MerchantTheme.brandTint)
    }
    private var layeredArtwork: some View {
        let base: CGFloat = arabic ? 90 : 110
        return ZStack(alignment: .topLeading) {
            Image("LOHOffer" + offer.artwork + "Base" + (arabic ? "Ar" : "En")).resizable().frame(width: base, height: base)
            if arabic {
                part("AmberPart0", 19.8, 54, 18, 18)
                part("AmberPart1", 12.6, 10.8, 21.6, 10.8)
                part("AmberPart2", 9, 5.4, 23.4, 7.2)
                part("AmberPart3", 16.2, 10.8, 19.8, 40.5)
                part("AmberPart4", 21.6, 57.6, 49.5, 14.4)
                part("AmberPart5", 14.4, 10.8, 53.1, 7.2)
                part("AmberPart6", 10.8, 5.4, 54.9, 3.6)
                part("AmberPart7", 18, 12.6, 51.3, 36)
            } else {
                let start = offer.artwork == "Latte" ? 4 : 0
                part("EnPart\(start)", 28, 56, 24, 42)
                part("EnPart\(start + 1)", 24, 48, 60, 41)
                part("EnPart\(start + 2)", 16, 16, 30, 34)
                part("EnPart\(start + 3)", 14, 14, 65, 34)
            }
        }.frame(width: base, height: base).scaleEffect(size / base).frame(width: size, height: size)
    }
    private func part(_ name: String, _ w: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat) -> some View {
        Image("LOHOffer" + name).resizable().frame(width: w, height: h).offset(x: x, y: y)
    }
}

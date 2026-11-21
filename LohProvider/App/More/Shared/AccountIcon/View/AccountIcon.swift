import SwiftUI

struct MerchantAccountIcon: View {
    @Environment(\.locale) private var locale
    let name: String
    var size: CGFloat = 22
    var tile: CGFloat = 44
    var circular = false
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var assetName: String {
        let localized = ["LOHAccountStore", "LOHAccountProfile", "LOHAccountGlobe", "LOHAccountSupport", "LOHLanguageGlobe"]
        return !arabic && localized.contains(name) ? name + "En" : name
    }
    var body: some View {
        Image(assetName).resizable().scaledToFit().frame(width: size, height: size)
            .frame(width: tile, height: tile)
            .background(arabic ? Color(red: 1, green: 241/255, blue: 237/255) : Color(red: 254/255, green: 243/255, blue: 233/255))
            .clipShape(RoundedRectangle(cornerRadius: circular ? tile / 2 : 12))
            .accessibilityHidden(true)
    }
}

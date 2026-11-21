import SwiftUI

struct MerchantSupportTile: View {
    @Environment(\.locale) private var locale
    let name: String
    var size: CGFloat = 22
    var tile: CGFloat = 44
    var circle = false
    var iconColor: Color? = nil
    var body: some View {
        MerchantSupportIcon(name: name, size: size, color: iconColor).frame(width: tile, height: tile)
            .background(locale.language.languageCode?.identifier == "ar"
                        ? Color(red: 1, green: 241/255, blue: 237/255)
                        : Color(red: 254/255, green: 243/255, blue: 233/255))
            .clipShape(RoundedRectangle(cornerRadius: circle ? tile / 2 : 12))
    }
}

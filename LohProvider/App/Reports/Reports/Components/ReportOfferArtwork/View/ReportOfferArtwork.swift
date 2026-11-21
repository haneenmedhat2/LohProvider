import SwiftUI
import Charts

/// Original Figma vector layers composed at their source positions inside the 52pt artwork.
struct MerchantReportOfferArtwork: View {
    @Environment(\.locale) private var locale
    @State private var reloadID = UUID()
    let index: Int
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    var body: some View {
        ZStack(alignment: .topLeading) {
            if !arabic {
                Color(red: 232/255, green: 245/255, blue: 233/255)
                part("EnLeft", 16, 28, 10, 20)
                part("EnRight", 14, 24, 29, 18)
            } else if index == 0 {
                part("imgIcon13", 52, 52, 0, 0)
                part("imgVector4", 12, 28, 10, 14)
                part("imgVector5", 14, 32, 26, 10)
            } else if index == 1 {
                part("imgIcon14", 52, 52, 0, 0)
                part("imgVector6", 32, 14, 10, 15)
                part("imgVector7", 32, 6, 10, 24)
                part("imgVector8", 32, 3, 10, 28)
                part("imgVector9", 32, 3, 10, 29)
                part("imgVector10", 32, 12, 10, 30)
            } else {
                part("imgIcon15", 52, 52, 0, 0)
                part("imgVector11", 28, 22, 12, 18)
                part("imgVector12", 28, 10, 12, 13)
                part("imgVector13", 20, 6, 16, 15)
                part("imgVector14", 13.0607, 4.28033, 19.47, 21.47)
                part("imgVector15", 4, 12, 38, 24)
            }
        }.frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 10))
            .environment(\.layoutDirection, .leftToRight).accessibilityHidden(true)
    }
    private func part(_ name: String, _ w: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat) -> some View {
        Image("LOHReportOffer" + name).resizable().frame(width: w, height: h).offset(x: x, y: y)
    }
}

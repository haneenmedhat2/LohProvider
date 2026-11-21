import SwiftUI

struct MerchantAppUpdateView: View {
    let storeURL: URL
    @ObservedObject private var language = AppLanguageManager.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    artwork
                        .frame(height: 239)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(text("update_title"))
                            .merchantFont(26, .black)
                            .foregroundStyle(Color("LOHTextPrimary"))
                            .accessibilityAddTraits(.isHeader)
                        Text(text("update_description"))
                            .merchantFont(14)
                            .foregroundStyle(Color("LOHTextSecondary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 0) {
                        Text(text("update_whats_new"))
                            .merchantFont(16, .bold)
                            .foregroundStyle(Color("LOHTextPrimary"))
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .padding(.horizontal, 16)

                        updateRow("update_faster", icon: "LOHUpdateSpeed")
                        updateRow("update_security", icon: "LOHUpdateShield")
                        updateRow("update_fixes", icon: "LOHUpdateRepair")
                    }
                    .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        openURL(storeURL)
                    } label: {
                        Text(text("update_now"))
                            .merchantFont(16, .bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .foregroundStyle(.white)
                    .background(Color("LOHBrandAction"), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("merchantUpdateNow")

                    HStack(spacing: 8) {
                        Image("LOHUpdateExternal")
                            .resizable()
                            .frame(width: 14, height: 14)
                        Text(text("update_store_note"))
                            .merchantFont(12)
                    }
                    .foregroundStyle(Color("LOHTextMuted"))
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 350)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color("LOHSurfaceCanvas").ignoresSafeArea())
        .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language.isRTL ? "ar" : "en"))
        .preferredColorScheme(.light)
        .accessibilityIdentifier("merchantAppUpdate")
    }

    private func updateRow(_ key: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .resizable()
                .frame(width: 18, height: 18)
                .frame(width: 36, height: 36)
                .background(Color(red: 1, green: 240/255, blue: 236/255), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            Text(text(key))
                .merchantFont(14, .medium)
                .foregroundStyle(Color("LOHTextPrimary"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 69)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(red: 242/255, green: 242/255, blue: 247/255))
                .frame(height: 1)
        }
    }

    private var artwork: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                illustration("PhoneBack", x: 30, y: 10, width: 110, height: 195)
                illustration("PhoneFace", x: 32, y: 12, width: 106, height: 191)
                illustration("PhoneSpeaker", x: 62, y: 14, width: 46, height: 12)
                illustration("PhoneScreen", x: 40, y: 40, width: 90, height: 150)
                Text("LOH")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MerchantTheme.brand)
                    .frame(width: 46)
                    .offset(x: 62, y: 78)
                Text("آخر ساعة")
                    .font(.custom("Cairo-Regular", size: 11))
                    .foregroundStyle(Color("LOHTextPrimary"))
                    .frame(width: 40)
                    .offset(x: 65, y: 107)
                illustration("PhoneSideTall", x: 140, y: 60, width: 4, height: 28)
                illustration("PhoneSideShort", x: 26, y: 55, width: 4, height: 20)
                illustration("PhoneSideShort", x: 26, y: 80, width: 4, height: 20)
            }
            .frame(width: 180, height: 220, alignment: .topLeading)
            .offset(x: 85)

            Circle()
                .fill(Color(red: 1, green: 240/255, blue: 232/255).opacity(0.8))
                .frame(width: 224, height: 224)
                .offset(x: 63, y: 8)

            ZStack(alignment: .topLeading) {
                illustration("BadgeCircle", x: 2, y: 2, width: 76, height: 76)
                illustration("BadgeRing", x: 20, y: 20, width: 40, height: 40)
                illustration("BadgeArrow", x: 38, y: 13, width: 16, height: 17)
                illustration("BadgeStem", x: 38, y: 26, width: 4, height: 24)
                illustration("BadgeTip", x: 30, y: 40, width: 20, height: 12)
            }
            .frame(width: 80, height: 80, alignment: .topLeading)
            .offset(x: 195, y: 120)
        }
        .frame(width: 350, height: 239, alignment: .topLeading)
    }

    private func illustration(_ name: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Image("LOHUpdate\(name)")
            .resizable()
            .frame(width: width, height: height)
            .offset(x: x, y: y)
    }

    private func text(_ key: String) -> String { merchantString(key, arabic: language.isRTL) }
}

#if DEBUG
struct MerchantAppUpdateView_Previews: PreviewProvider {
    static var previews: some View {
        MerchantAppUpdateView(storeURL: MerchantAppStoreVersionChecker.fallbackStoreURL)
    }
}
#endif

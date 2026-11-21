import SwiftUI

struct MerchantOrderHeader: View {
    @Environment(\.merchantProfile) private var profile
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let vendor: MerchantOfferVendor?

    var body: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(locale.language.languageCode?.identifier == "ar" ? "LOHBackRight" : "LOHBackLeft")
                    .resizable().scaledToFit().frame(width: 22, height: 22)
                    .frame(width: 36, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(merchantString("back", locale: locale))
            VStack(alignment: .leading, spacing: 0) {
                Text(vendor?.greeting ?? merchantString("report_hello", locale: locale))
                    .merchantFont(12).foregroundStyle(MerchantTheme.muted).frame(height: 14.4)
                Text(profile?.name ?? vendor?.name ?? "—")
                    .merchantFont(24, .black).foregroundStyle(MerchantTheme.heading)
                    .lineLimit(1).minimumScaleFactor(0.75).frame(height: 26.4)
                Capsule().fill(MerchantTheme.brand).frame(width: 38, height: 3).padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            MerchantProviderImage(url: profile?.image ?? vendor?.image, size: 54, cornerRadius: 14)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MerchantTheme.brand, lineWidth: 2))
        }.padding(.horizontal, 16).padding(.bottom, 8)
            .background(MerchantTheme.surface)
    }
}

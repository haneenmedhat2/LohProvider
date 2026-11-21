import SwiftUI

struct MerchantAccountNotice: View {
    let text: String
    var icon = "LOHProfileWarning"
    var body: some View {
        HStack(spacing: 10) {
            Text(text).merchantFont(13).foregroundStyle(MerchantTheme.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            Image(icon).resizable().scaledToFit().frame(width: 20, height: 20).accessibilityHidden(true)
        }.environment(\.layoutDirection, .leftToRight)
            .padding(14).background(MerchantTheme.brandTint).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

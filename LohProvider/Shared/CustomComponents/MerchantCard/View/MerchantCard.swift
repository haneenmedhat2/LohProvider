import SwiftUI

struct MerchantCard<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = MerchantTheme.Radius.card
    var elevated = false
    @ViewBuilder var content: Content
    var body: some View {
        CardContainer(padding: padding, cornerRadius: radius) { content }
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(elevated ? .clear : MerchantTheme.border.opacity(0.55)))
            .shadow(color: .black.opacity(elevated ? 0.06 : 0), radius: 12, x: 0, y: 4)
    }
}

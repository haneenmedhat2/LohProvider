import SwiftUI

struct MerchantFieldContainer<Content: View>: View {
    var hasError = false
    var focused = false
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 0) { content }
            .frame(minHeight: 52)
            .background(MerchantTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: MerchantTheme.Radius.field))
            .overlay(RoundedRectangle(cornerRadius: MerchantTheme.Radius.field)
                .stroke(hasError ? MerchantTheme.error : focused ? MerchantTheme.brand : MerchantTheme.border, lineWidth: 1))
    }
}

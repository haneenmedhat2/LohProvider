import SwiftUI

struct MerchantFieldIcon: View {
    let name: String
    var body: some View {
        Image(name).resizable().scaledToFit().frame(width: 18, height: 18)
            .frame(width: 40, height: 40)
            .background(MerchantTheme.brandTint, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 6)
            .accessibilityHidden(true)
    }
}

import SwiftUI

struct MerchantHeader: View {
    let title: String
    var body: some View {
        Text(title).merchantFont(18, .bold).foregroundStyle(MerchantTheme.heading)
            .frame(maxWidth: .infinity).frame(minHeight: 56)
    }
}

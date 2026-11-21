import SwiftUI

struct MerchantFieldLabel: View {
    let title: String
    var body: some View {
        Text(title).merchantFont(13, .semibold).foregroundStyle(MerchantTheme.body)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

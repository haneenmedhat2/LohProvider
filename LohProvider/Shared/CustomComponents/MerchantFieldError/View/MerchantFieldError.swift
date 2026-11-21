import SwiftUI

struct MerchantFieldError: View {
    let message: String?
    var body: some View {
        if let message {
            Text(message).merchantFont(12).foregroundStyle(MerchantTheme.error)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("fieldError")
        }
    }
}

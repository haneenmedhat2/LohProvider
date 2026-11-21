import SwiftUI

struct MerchantDialogView<Content: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Content
    var body: some View {
        MerchantCard(padding: 24, radius: 24, elevated: true) {
            VStack(spacing: 16) {
                Text(title).merchantFont(20, .bold).foregroundStyle(MerchantTheme.heading)
                Text(message).merchantFont(14).foregroundStyle(MerchantTheme.secondary)
                actions
            }
            .multilineTextAlignment(.center)
        }
    }
}

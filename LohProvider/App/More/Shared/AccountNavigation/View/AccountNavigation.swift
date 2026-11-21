import SwiftUI

struct MerchantAccountNavigation: ViewModifier {
    let title: String
    var showsBackButton = true
    func body(content: Content) -> some View {
        content.background(MerchantTheme.background.ignoresSafeArea())
            .modifier(MerchantNavigationBar(title: title, showsBackButton: showsBackButton))
    }
}

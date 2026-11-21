import SwiftUI

extension View {
    /// Attach directly to a screen to print its SwiftUI view type.
    func logMerchantScreen() -> some View {
        onAppear {
            #if DEBUG
            print("[Screen] \(String(describing: Self.self))")
            #endif
        }
    }
}

import SwiftUI

struct MerchantSettlementIcon: View {
    let name: String
    var size: CGFloat = 16
    var body: some View {
        Image("LOHSettlement" + name).resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

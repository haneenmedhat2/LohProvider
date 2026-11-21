import SwiftUI

private struct MerchantProfileKey: EnvironmentKey {
    static let defaultValue: MerchantProfile? = nil
}

extension EnvironmentValues {
    var merchantProfile: MerchantProfile? {
        get { self[MerchantProfileKey.self] }
        set { self[MerchantProfileKey.self] = newValue }
    }
}

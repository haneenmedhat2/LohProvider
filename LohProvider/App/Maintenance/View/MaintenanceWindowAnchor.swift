import UIKit

final class MerchantMaintenanceWindowAnchor: UIView {
    var sceneChanged: ((UIWindowScene?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        sceneChanged?(window?.windowScene)
    }
}

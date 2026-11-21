import SwiftUI
import UIKit

/// A scene-level window keeps maintenance above navigation, tab bars, and sheets.
struct MerchantMaintenancePresentation: UIViewRepresentable {
    @ObservedObject var viewModel: MerchantMaintenanceViewModel

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeUIView(context: Context) -> MerchantMaintenanceWindowAnchor {
        let view = MerchantMaintenanceWindowAnchor()
        view.isUserInteractionEnabled = false
        view.sceneChanged = { [weak coordinator = context.coordinator] scene in
            coordinator?.update(scene: scene)
        }
        return view
    }

    func updateUIView(_ uiView: MerchantMaintenanceWindowAnchor, context: Context) {
        context.coordinator.update(scene: uiView.window?.windowScene)
    }

    static func dismantleUIView(_ uiView: MerchantMaintenanceWindowAnchor, coordinator: Coordinator) {
        uiView.sceneChanged = nil
        coordinator.dismiss()
    }

    @MainActor
    final class Coordinator {
        private let viewModel: MerchantMaintenanceViewModel
        private var maintenanceWindow: UIWindow?
        private weak var previousKeyWindow: UIWindow?

        init(viewModel: MerchantMaintenanceViewModel) { self.viewModel = viewModel }

        func update(scene: UIWindowScene?) {
            guard viewModel.isPresented else { dismiss(); return }
            guard let scene, maintenanceWindow == nil else { return }
            previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
            previousKeyWindow?.endEditing(true)
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            let host = UIHostingController(rootView: MerchantMaintenanceView(viewModel: viewModel).preferredColorScheme(.light))
            host.view.accessibilityViewIsModal = true
            window.rootViewController = host
            maintenanceWindow = window
            window.makeKeyAndVisible()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }

        func dismiss() {
            guard let window = maintenanceWindow else { return }
            let wasKeyWindow = window.isKeyWindow
            window.isHidden = true
            window.rootViewController = nil
            maintenanceWindow = nil
            if wasKeyWindow { previousKeyWindow?.makeKey() }
            previousKeyWindow = nil
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
}

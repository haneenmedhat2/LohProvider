import SwiftUI
import UIKit

struct MerchantNavigationBar: ViewModifier {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let title: String
    var background: Color = MerchantTheme.background
    var titleSize: CGFloat = 18
    var titleWeight: MerchantFontWeight = .bold
    var showsBackButton = true

    private var isRTL: Bool { locale.language.languageCode?.identifier == "ar" }
    private var localizedTitle: String { merchantString(title, arabic: isRTL) }

    func body(content: Content) -> some View {
        content
            .navigationTitle(localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(showsBackButton)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background {
                if showsBackButton {
                    MerchantInteractiveBackGesture(isRTL: isRTL)
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                }
            }
            .toolbar {
                if showsBackButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            MerchantBackChevron(pointsRight: isRTL)
                                .stroke(MerchantTheme.heading, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .frame(width: 10, height: 18)
                                .frame(width: 24, height: 24)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        .accessibilityLabel(merchantString("account_back", locale: locale))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(localizedTitle).merchantFont(titleSize, titleWeight).foregroundStyle(MerchantTheme.heading)
                }
            }
    }
}

private struct MerchantInteractiveBackGesture: UIViewControllerRepresentable {
    let isRTL: Bool

    func makeUIViewController(context: Context) -> GestureController {
        GestureController()
    }

    func updateUIViewController(_ controller: GestureController, context: Context) {
        controller.isRTL = isRTL
        DispatchQueue.main.async { controller.enableSwipeBack() }
    }

    final class GestureController: UIViewController {
        var isRTL = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableSwipeBack()
        }

        func enableSwipeBack() {
            guard let navigationController else { return }
            navigationController.view.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
            guard navigationController.viewControllers.count > 1,
                  let gesture = navigationController.interactivePopGestureRecognizer else { return }
            gesture.delegate = nil
            gesture.isEnabled = true
        }
    }
}

private struct MerchantBackChevron: Shape {
    let pointsRight: Bool

    func path(in rect: CGRect) -> Path {
        let outerX = pointsRight ? rect.minX : rect.maxX
        let tipX = pointsRight ? rect.maxX : rect.minX
        return Path { path in
            path.move(to: CGPoint(x: outerX, y: rect.minY))
            path.addLine(to: CGPoint(x: tipX, y: rect.midY))
            path.addLine(to: CGPoint(x: outerX, y: rect.maxY))
        }
    }
}

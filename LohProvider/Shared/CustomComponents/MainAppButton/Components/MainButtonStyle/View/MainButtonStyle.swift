import SwiftUI

struct MainButtonStyle: ButtonStyle {
    var background: LinearGradient = .mainVertical
    var foregroundColor: Color = .white
    var height: CGFloat = 48
    var cornerRadius: CGFloat = 16
    var horizontalPadding: CGFloat = 8
    var font: Font = AppFont.semiBold(size: 16)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                background
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .foregroundStyle(foregroundColor)
            .cornerRadius(cornerRadius)
            .padding(.horizontal, horizontalPadding)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

import SwiftUI

struct MerchantOrderActions: View {
    @Environment(\.locale) private var locale
    let presentation: MerchantOrderPresentation
    let isLoading: Bool
    let canConfirm: Bool
    let confirm: () -> Void
    let cancel: () -> Void
    let proceed: () -> Void
    let enterCode: () -> Void
    let scan: () -> Void
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    var body: some View {
        VStack(spacing: 10) {
            if presentation.isComplete {
                Button(text("offers_continue"), action: proceed).buttonStyle(style())
            } else {
                if presentation.showsReady {
                    Button(action: confirm) {
                        HStack(spacing: 10) {
                            if isLoading { ProgressView().tint(MerchantTheme.ink) }
                            else {
                                MerchantOfferIcon(name: "ConfirmEn", size: 14, localized: false)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(MerchantTheme.ink.opacity(0.3), lineWidth: 2))
                            }
                            Text(text("offers_confirm_delivery"))
                        }
                    }.buttonStyle(style())
                        .disabled(isLoading || !canConfirm)
                } else {
                    HStack(spacing: 8) {
                        MerchantOfferAction(title: text("nav_order_code"), icon: "Code", secondary: true, action: enterCode)
                        MerchantOfferAction(title: text("nav_scan_barcode"), icon: "Scan", action: scan)
                    }
                }
                if !isLoading {
                    Button(text("offers_cancel_delivery"), action: cancel).buttonStyle(style(secondary: true))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MerchantTheme.border))
                }
            }
        }
    }
    private func style(secondary: Bool = false) -> MainButtonStyle {
        MainButtonStyle(background: LinearGradient(colors: [secondary ? MerchantTheme.surface : MerchantTheme.brand], startPoint: .top, endPoint: .bottom),
                        foregroundColor: secondary ? MerchantTheme.body : MerchantTheme.ink, height: secondary ? 50 : 54,
                        cornerRadius: 14, horizontalPadding: 0,
                        font: MerchantTypography.font(secondary ? 16 : 17, weight: secondary ? .bold : .bold,
                                                 arabic: locale.language.languageCode?.identifier == "ar"))
    }
}

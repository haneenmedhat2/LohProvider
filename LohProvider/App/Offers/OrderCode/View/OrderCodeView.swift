import SwiftUI

struct MerchantOrderCodeView: View {
    var fromOffers = false
    @EnvironmentObject private var store: MerchantOffersViewModel
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @Environment(\.locale) private var locale
    @State private var code = ""
    @State private var verificationTask: Task<Void, Never>?
    @FocusState private var focused: Bool
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    private var validCode: Bool {
        (store.allowsLocalVerification ? MerchantOffersViewModel.normalizedCode(code) : MerchantOffersViewModel.normalizedPurchaseCode(code)) != nil
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(text(fromOffers ? "offers_enter_code" : "nav_order_code"))
                    .merchantFont(20, .bold).foregroundStyle(MerchantTheme.heading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField(text("offers_code_placeholder"), text: $code)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode).focused($focused)
                    .merchantFont(18, .semibold).multilineTextAlignment(.center)
                    .padding(12).frame(minHeight: 52)
                    .background(MerchantTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MerchantTheme.border))
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityLabel(text("nav_order_code"))
                    .disabled(store.isVerifying)
                if let error = store.verificationAPIError { MerchantFieldError(message: error.message { text($0) }) }
                if fromOffers {
                    Button(action: verify) {
                        HStack(spacing: 8) {
                            if store.isVerifying { ProgressView().tint(MerchantTheme.ink) }
                            Text(text("offers_verify"))
                        }
                    }
                    .buttonStyle(MainButtonStyle(
                        background: LinearGradient(colors: [validCode ? MerchantTheme.brand : MerchantTheme.border],
                                                   startPoint: .top, endPoint: .bottom),
                        foregroundColor: validCode ? MerchantTheme.ink : MerchantTheme.placeholder,
                        height: 54,
                        cornerRadius: MerchantTheme.Radius.button,
                        horizontalPadding: 0,
                        font: MerchantTypography.font(18, weight: .bold, arabic: arabic)))
                    .disabled(!validCode || store.isVerifying)
                    .accessibilityIdentifier("offersOrderCodeVerify")
                } else {
                    MerchantButton(title: text("offers_verify"), isLoading: store.isVerifying, action: verify)
                        .disabled(!validCode).opacity(validCode ? 1 : 0.45)
                    MerchantButton(title: text("nav_scan_barcode"), secondary: true) {
                        focused = false
                        verificationTask?.cancel()
                        coordinator.sheet = .scanner
                    }
                    Button(text("nav_cancel")) {
                        verificationTask?.cancel(); store.cancelVerification(); coordinator.sheet = nil
                    }.merchantFont(14, .semibold).foregroundStyle(MerchantTheme.muted)
                }
            }.padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 20)
        }.background(.white)
            .onDisappear { verificationTask?.cancel() }
    }

    private func verify() {
        focused = false
        verificationTask = Task {
            let success = await store.verifyPurchase(code, method: .code)
            if success || store.verificationError != nil { coordinator.sheet = nil }
        }
    }
}

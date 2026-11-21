import SwiftUI

struct MerchantMaintenanceView: View {
    private static let supportURL = URL(string: "https://upgrade.loh.com.sa/contact-us-page")!

    @ObservedObject var viewModel: MerchantMaintenanceViewModel
    @ObservedObject private var language = AppLanguageManager.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Image("lohMaintenance")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 230)
                        .frame(maxWidth: .infinity, minHeight: 260)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text(text("maintenance_title"))
                            .merchantFont(28, .black)
                            .foregroundStyle(MerchantTheme.heading)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 8) {
                            Text(text("maintenance_description"))
                            Text(text("maintenance_try_later"))
                        }
                        .merchantFont(14)
                        .foregroundStyle(MerchantTheme.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        Image("lohMaintenanceShield")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .frame(width: 40, height: 40)
                            .background(MerchantTheme.brandTint, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                        Text(text("maintenance_note"))
                            .merchantFont(14)
                            .foregroundStyle(MerchantTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                    MerchantButton(title: text("maintenance_retry"), isLoading: viewModel.isRetrying,
                              foregroundColor: .white) {
                        Task { await viewModel.retry() }
                    }

                    if let retryMessage = viewModel.retryMessage {
                        Text(text(retryMessage))
                            .merchantFont(14)
                            .foregroundStyle(MerchantTheme.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.updatesFrequently)
                    }

                    Button {
                        openURL(Self.supportURL)
                    } label: {
                        Text(text("maintenance_contact_support"))
                            .merchantFont(16)
                            .foregroundStyle(MerchantTheme.brand)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .overlay {
                                RoundedRectangle(cornerRadius: MerchantTheme.Radius.button)
                                    .strokeBorder(MerchantTheme.brand)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: MerchantTheme.Radius.button))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(MerchantTheme.ink)
        .background(MerchantTheme.background.ignoresSafeArea())
        .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language.isRTL ? "ar" : "en"))
    }

    private func text(_ key: String) -> String { merchantString(key, arabic: language.isRTL) }
}

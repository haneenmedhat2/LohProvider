import SwiftUI

struct MerchantAccountView: View {
    @ObservedObject private var coordinator: MerchantTabsCoordinator
    @StateObject private var viewModel: MerchantAccountViewModel
    @Environment(\.locale) private var locale
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }

    init(coordinator: MerchantTabsCoordinator, onLogout: @escaping () async throws -> Void) {
        _coordinator = ObservedObject(wrappedValue: coordinator)
        _viewModel = StateObject(wrappedValue: MerchantAccountViewModel(
            coordinator: coordinator, onLogout: onLogout))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                MerchantStoreHero()
                MerchantFieldError(message: viewModel.error?.message(localize: text))
                MerchantCard(padding: 0) {
                    VStack(spacing: 0) {
                        row("nav_profile", subtitle: text("account_profile_hint"), icon: "LOHAccountProfile", route: .profile)
                        separator
                        row("nav_language", subtitle: arabic ? "العربية" : "English", icon: "LOHAccountGlobe", route: .language)
                        separator
                        row("nav_support", subtitle: text("account_support_hint"), icon: "LOHAccountSupport", route: .support)
                    }
                }
                Button { viewModel.presentLogoutConfirmation() } label: {
                    HStack(spacing: 10) {
                        Text(text("nav_logout")).merchantFont(15, .bold)
                        Image("LOHAccountLogout").resizable().scaledToFit().frame(width: 20, height: 20)
                            .accessibilityHidden(true)
                    }.foregroundStyle(MerchantTheme.error).frame(maxWidth: .infinity).frame(minHeight: 58)
                        .background(MerchantTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(coordinator.dialog == .logout ? MerchantTheme.error : MerchantTheme.border.opacity(0.55)))
                }.buttonStyle(.plain)
            }.padding(16)
        }.modifier(MerchantAccountNavigation(title: "tab_account", showsBackButton: false))
            .sheet(isPresented: Binding(
                get: { coordinator.dialog == .logout },
                set: { coordinator.dialog = $0 ? .logout : nil }
            )) {
                logoutConfirmation
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
                    .presentationDetents([.height(360), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.white)
                    .interactiveDismissDisabled(viewModel.isSigningOut)
            }
    }

    private var separator: some View { MerchantTheme.background.frame(height: 1).padding(.horizontal, 16) }
    private func row(_ title: String, subtitle: String, icon: String, route: MerchantRoute) -> some View {
        Button { viewModel.open(route) } label: {
            HStack(spacing: 12) {
                MerchantAccountIcon(name: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text(title)).merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                    Text(subtitle).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                Image(systemName: arabic ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(MerchantTheme.muted).accessibilityHidden(true)
            }.padding(16).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var logoutConfirmation: some View {
        ScrollView {
            VStack(spacing: 14) {
                MerchantAccountIcon(name: "LOHAccountLogout", size: 28, tile: 60, circular: true)
                Text(text("nav_logout")).merchantFont(18, .bold).foregroundStyle(MerchantTheme.heading)
                Text(text("account_logout_message")).merchantFont(13).foregroundStyle(MerchantTheme.muted).multilineTextAlignment(.center)
                MerchantFieldError(message: viewModel.error?.message(localize: text))
                MerchantButton(title: text("nav_logout"), isLoading: viewModel.isSigningOut) {
                    Task { await viewModel.confirmLogout() }
                }
                MerchantButton(title: text("nav_cancel"), secondary: true, foregroundColor: MerchantTheme.brand) {
                    viewModel.dismissLogoutConfirmation()
                }
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MerchantTheme.brand))
                    .disabled(viewModel.isSigningOut)
            }.padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 20)
        }.background(.white)
    }
}

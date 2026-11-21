import SwiftUI

struct MerchantProfileView: View {
    @Environment(\.locale) private var locale
    @StateObject private var viewModel: MerchantProfileViewModel
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    init(responseHandler: ResponseHandler? = nil) {
        _viewModel = StateObject(wrappedValue: MerchantProfileViewModel(responseHandler: responseHandler))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MerchantStoreHero(profile: true, merchantProfile: viewModel.profile)
                if viewModel.isRefreshing {
                    ProgressView(merchantString("profile_loading", arabic: arabic)).merchantFont(13)
                }
                if let refreshError = viewModel.refreshError {
                    VStack(spacing: 8) {
                        MerchantFieldError(message: refreshError.message { merchantString($0, arabic: arabic) })
                        Button(merchantString("api_retry", arabic: arabic)) { Task { await viewModel.refresh() } }
                            .merchantFont(14, .bold)
                    }
                }
                MerchantCard(padding: 0) {
                    VStack(spacing: 0) {
                        row("account_store_label", value: viewModel.profile?.name ?? "—", icon: "LOHProfileStore")
                        separator
                        row("account_phone", value: viewModel.profile?.phone ?? "—", icon: "LOHProfilePhone", latin: true)
                        separator
                        row("account_email", value: viewModel.profile?.email ?? "—", icon: "LOHProfileMail", latin: true)
                    }
                }
                MerchantAccountNotice(text: merchantString("account_update_notice", arabic: arabic))
            }.padding(16)
        }.modifier(MerchantAccountNavigation(title: "nav_profile"))
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
    }
    private var separator: some View { MerchantTheme.background.frame(height: 1).padding(.horizontal, 16) }
    private func row(_ key: String, value: String, icon: String, latin: Bool = false) -> some View {
        HStack(spacing: 12) {
            if arabic {
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchantString(key, arabic: true)).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                    Text(value).merchantFont(14, .semibold).foregroundStyle(MerchantTheme.heading)
                        .environment(\.layoutDirection, latin ? .leftToRight : .rightToLeft)
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(value).merchantFont(14, .semibold).foregroundStyle(MerchantTheme.heading).frame(maxWidth: .infinity, alignment: .leading)
                Text(merchantString(key, arabic: false)).merchantFont(14).foregroundStyle(MerchantTheme.muted)
            }
            MerchantAccountIcon(name: icon, size: arabic ? 22 : 18, tile: arabic ? 44 : 40)
        }.padding(16).frame(minHeight: arabic ? 77 : 72)
    }
}

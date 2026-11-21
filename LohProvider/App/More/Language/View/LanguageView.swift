import SwiftUI

struct MerchantLanguageView: View {
    @ObservedObject private var manager: AppLanguageManager
    @StateObject private var viewModel: MerchantLanguageViewModel
    @Environment(\.locale) private var locale
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }

    init(responseHandler: ResponseHandler? = nil) {
        let manager = AppLanguageManager.shared
        _manager = ObservedObject(wrappedValue: manager)
        _viewModel = StateObject(wrappedValue: MerchantLanguageViewModel(manager: manager, responseHandler: responseHandler))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    MerchantAccountIcon(name: "LOHLanguageGlobe", size: arabic ? 44 : 40, tile: 80, circular: true)
                    VStack(spacing: 6) {
                        Text(text("language_heading")).merchantFont(20, .black).foregroundStyle(MerchantTheme.heading)
                        Text(text("language_subtitle")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                    }.multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.bottom, 8)
                MerchantCard(padding: 0) {
                    VStack(spacing: 0) {
                        languageRow("ar", title: text("language_arabic"), subtitle: text("language_default"), flag: "🇸🇦")
                        MerchantTheme.background.frame(height: 1)
                        languageRow("en", title: "English", subtitle: text("language_english"), flag: "🇺🇸")
                    }
                }
                MerchantFieldError(message: viewModel.error?.message(localize: text))
                MerchantButton(title: text("language_apply"), isLoading: viewModel.isApplying) {
                    Task { await viewModel.apply() }
                }
                MerchantAccountNotice(text: text("language_notice"), icon: "LOHLanguageWarning")
            }.padding(16)
        }
        .onChange(of: manager.selectedLanguage) { value in
            // iOS Settings changes also update the pending selection.
            viewModel.synchronize(current: value)
        }
        .modifier(MerchantAccountNavigation(title: "nav_language"))
        .sheet(isPresented: Binding(
            get: { viewModel.applied != nil },
            set: { if !$0 { viewModel.dismissSuccess() } }
        )) {
            success
                .background(Color.white.ignoresSafeArea())
                .environment(\.locale, Locale(identifier: manager.selectedLanguage))
                .environment(\.layoutDirection, manager.layoutDirection)
                .presentationDetents([.height(320), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.white)
        }
    }

    private func languageRow(_ code: String, title: String, subtitle: String, flag: String) -> some View {
        Button { viewModel.select(code) } label: {
            HStack(spacing: 12) {
                Circle().stroke(viewModel.selected == code ? MerchantTheme.brand : MerchantTheme.border, lineWidth: 2)
                    .overlay { if viewModel.selected == code { Circle().fill(MerchantTheme.brand).padding(6) } }
                    .frame(width: 22, height: 22)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(title).merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                    Text(subtitle).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                }.frame(maxWidth: .infinity, alignment: .trailing)
                // Native emoji rendering avoids missing glyphs in exported SVG flags.
                Text(flag).font(.system(size: 26)).frame(width: 36).accessibilityHidden(true)
            }.padding(.horizontal, 16).padding(.vertical, 18).frame(minHeight: 77).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(viewModel.isApplying).environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(viewModel.selected == code ? [.isSelected] : [])
    }

    private var success: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image("LOHAccountCheck").resizable().scaledToFit().frame(width: 32, height: 32)
                    .frame(width: arabic ? 64 : 72, height: arabic ? 64 : 72)
                    .background(Color(red: 220/255, green: 252/255, blue: 231/255)).clipShape(Circle()).accessibilityHidden(true)
                Text(text("language_success")).merchantFont(18, .bold).foregroundStyle(MerchantTheme.heading)
                Text(text(viewModel.applied == "ar" ? "language_applied_ar" : "language_applied_en"))
                    .merchantFont(13).foregroundStyle(MerchantTheme.muted)
                MerchantButton(title: text("language_great")) { viewModel.dismissSuccess() }
            }.multilineTextAlignment(.center).padding(.horizontal, 24).padding(.vertical, 32)
        }
    }
}

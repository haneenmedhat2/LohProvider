import SwiftUI

struct MerchantOffersControls: View {
    @Environment(\.locale) private var locale
    @Binding var query: String
    @Binding var sort: MerchantOfferSort
    let verify: (MerchantSheet) -> Void
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                MerchantOfferIcon(name: "Search", size: 16)
                TextField("", text: $query, prompt: Text(text("offers_search")).foregroundColor(MerchantTheme.placeholder))
                    .merchantFont(14).foregroundStyle(MerchantTheme.body)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.search).autocorrectionDisabled()
                    .accessibilityLabel(text("offers_search")).accessibilityIdentifier("merchantOffersSearch")
            }.padding(.horizontal, 14).frame(minHeight: 44)
                .background(MerchantTheme.subtle, in: RoundedRectangle(cornerRadius: 12))
            MerchantOfferStatisticsView()
            MerchantOfferVerificationCard(verify: verify)
            HStack {
                Menu {
                    Picker(text("offers_sort"), selection: $sort) {
                        ForEach(MerchantOfferSort.allCases) { value in Text(text(value.key)).tag(value) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(text("offers_sort")).merchantFont(13, .semibold)
                        MerchantOfferIcon(name: "Sort", size: 14)
                    }.foregroundStyle(MerchantTheme.body)
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background(MerchantTheme.subtle, in: RoundedRectangle(cornerRadius: 10))
                }.accessibilityValue(text(sort.key)).accessibilityIdentifier("merchantOffersSort")
                Spacer(minLength: 0)
            }
        }.padding(.horizontal, 16).padding(.bottom, 8)
            .accessibilityIdentifier("merchantOffersControls")
    }
}

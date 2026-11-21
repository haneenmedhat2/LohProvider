import SwiftUI

struct MerchantSupportView: View {
    @EnvironmentObject private var store: MerchantSupportViewModel
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @Environment(\.locale) private var locale
    @State private var reloadID = UUID()
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        MerchantSupportIcon(name: "Help", size: arabic ? 44 : 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text("support_help_heading")).merchantFont(16, .bold).foregroundStyle(MerchantTheme.heading)
                            Text(text("support_help_subtitle")).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.environment(\.layoutDirection, .leftToRight)
                    Button { stack.push(.createTicket) } label: {
                        HStack(spacing: 10) {
                            Text(text("support_create")).merchantFont(16, .bold)
                            MerchantSupportIcon(name: "Plus", size: arabic ? 18 : 22)
                        }.frame(maxWidth: .infinity).frame(minHeight: 50)
                            .foregroundStyle(MerchantTheme.ink).background(MerchantTheme.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                }.padding(16).background(MerchantTheme.brandTint)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(arabic ? MerchantTheme.brand.opacity(0.5) : .clear))
                VStack(alignment: arabic ? .leading : .trailing, spacing: 4) {
                    Text(text("support_tickets")).merchantFont(18, .bold).foregroundStyle(MerchantTheme.heading)
                    Text(text("support_tickets_hint")).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                }.frame(maxWidth: .infinity, alignment: arabic ? .leading : .trailing).padding(.top, 12)
                if store.isLoading && store.tickets.isEmpty {
                    ProgressView(text("support_loading")).merchantFont(13).padding(24)
                }
                if let error = store.error {
                    VStack(spacing: 12) {
                        MerchantFieldError(message: error.message(localize: text))
                        MerchantButton(title: text("api_retry"), secondary: true, isLoading: store.isLoading) {
                            reloadID = UUID()
                        }
                    }
                } else if store.hasLoaded && !store.isLoading && store.tickets.isEmpty {
                    Text(text("support_empty")).merchantFont(14).foregroundStyle(MerchantTheme.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
                ForEach(store.tickets) { ticket in
                    Button { stack.push(.ticketDetails(ticket.id)) } label: { MerchantTicketCard(ticket: ticket) }
                        .buttonStyle(.plain).accessibilityIdentifier("ticket_\(ticket.id)")
                }
            }.padding(16)
        }.modifier(MerchantAccountNavigation(title: "nav_support"))
            .task(id: "\(locale.identifier)-\(reloadID)") { await store.reload() }
            .refreshable { await store.reload() }
    }
}

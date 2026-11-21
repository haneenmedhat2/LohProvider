import SwiftUI

struct MerchantTicketCard: View {
    @Environment(\.locale) private var locale
    let ticket: MerchantSupportTicket
    var showsPreview = true
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var statusLabel: String? {
        if !showsPreview, let isOpen = ticket.isOpen {
            return merchantString(isOpen ? "support_open" : "support_closed", locale: locale)
        }
        return ticket.statusLabel(arabic: arabic)
    }
    var body: some View {
        MerchantCard(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                if !arabic && showsPreview { MerchantSupportIcon(name: "Chevron", size: 16) }
                MerchantSupportTile(name: "Ticket", size: arabic ? 24 : 22)
                VStack(alignment: .trailing, spacing: 6) {
                    if let status = statusLabel {
                        MerchantStatusBadge(title: status, kind: ticket.isOpen == true ? .success : .neutral,
                                       prominent: !showsPreview)
                    }
                    Text(ticket.title.value(arabic: arabic)).merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                    if let created = ticket.createdLabel(arabic: arabic) {
                        HStack(spacing: 4) {
                            MerchantSupportIcon(name: "Calendar", size: 12)
                            Text(merchantString("support_created", arabic: arabic) + " " + created)
                                .merchantFont(11).foregroundStyle(MerchantTheme.muted)
                        }
                    }
                    if showsPreview {
                        Text(ticket.detail.value(arabic: arabic)).merchantFont(12).foregroundStyle(MerchantTheme.muted).lineLimit(2)
                    }
                }.frame(maxWidth: .infinity, alignment: .trailing).multilineTextAlignment(.trailing)
                if arabic && showsPreview { MerchantSupportIcon(name: "Chevron", size: 14) }
            }.environment(\.layoutDirection, .leftToRight)
        }
    }
}

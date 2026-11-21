import SwiftUI

struct MerchantSupportSentView: View {
    @EnvironmentObject private var store: MerchantSupportViewModel
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @Environment(\.locale) private var locale
    let ticketID: String
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    var body: some View {
        ScrollView {
            if let ticket = store.ticket(ticketID) {
                VStack(spacing: 24) {
                    VStack(spacing: 20) {
                        MerchantSupportIcon(name: "Check", size: arabic ? 36 : 40, color: .black)
                            .frame(width: arabic ? 80 : 90, height: arabic ? 80 : 90)
                            .background(Color(red: 220/255, green: 252/255, blue: 231/255)).clipShape(Circle())
                        VStack(spacing: 8) {
                            Text(text("support_sent_heading")).merchantFont(arabic ? 22 : 20, .bold).foregroundStyle(MerchantTheme.heading)
                            Text(text("support_sent_hint")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                        }.multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.top, 28)
                    MerchantCard(padding: 0) {
                        VStack(spacing: 0) {
                            summary("support_title", value: ticket.title.value(arabic: arabic), icon: "Ticket")
                            MerchantTheme.background.frame(height: 1)
                            if let typeName = ticket.typeName {
                                summary("support_issue_type", value: typeName, icon: "Info")
                                MerchantTheme.background.frame(height: 1)
                            }
                            if let orderID = ticket.orderID {
                                let orderNumber = store.ticketOrders.first(where: { $0.id == orderID })?.orderNumber ?? "#" + orderID
                                summary("support_related_order", value: orderNumber, icon: "Document")
                                MerchantTheme.background.frame(height: 1)
                            }
                            if let created = ticket.createdLabel(arabic: arabic) {
                                summary("support_submitted_on", value: created, icon: "Date")
                            }
                        }
                    }
                    MerchantButton(title: text("support_done")) { stack.replace(with: .support) }
                }.padding(16)
            }
        }.modifier(MerchantAccountNavigation(title: "support_sent_title"))
            .tint(.black)
    }
    private func summary(_ key: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            MerchantSupportTile(name: icon, size: 20, tile: arabic ? 44 : 40, circle: true, iconColor: .black)
            VStack(alignment: .trailing, spacing: 4) {
                Text(text(key)).merchantFont(arabic ? 12 : 13, arabic ? .regular : .bold)
                    .foregroundStyle(arabic ? MerchantTheme.muted : MerchantTheme.heading)
                Text(value).merchantFont(14).foregroundStyle(arabic ? MerchantTheme.body : MerchantTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .trailing).multilineTextAlignment(.trailing)
        }.padding(16).environment(\.layoutDirection, .leftToRight)
    }
}

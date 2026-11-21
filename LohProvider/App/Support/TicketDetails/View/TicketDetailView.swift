import SwiftUI

struct MerchantTicketDetailView: View {
    @EnvironmentObject private var store: MerchantSupportViewModel
    let ticketID: String

    var body: some View {
        MerchantTicketConversationView(model: store.conversation(for: ticketID))
            .id(ticketID)
            .modifier(MerchantAccountNavigation(title: "nav_ticket_details"))
    }
}

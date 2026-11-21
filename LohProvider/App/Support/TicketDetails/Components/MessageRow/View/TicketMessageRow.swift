import SwiftUI

struct MerchantTicketMessageRow: View {
    @Environment(\.locale) private var locale
    let message: MerchantChatMessage
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.isSender {
                Image(systemName: "person")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MerchantTheme.brand)
                    .frame(width: 36, height: 36)
                    .background(Color(red: 1, green: 241/255, blue: 237/255), in: Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if arabic { dateLabel }
                    if arabic { Spacer(minLength: 4) }
                    Text(merchantString(message.isSender ? "support_you" : "support_team", locale: locale))
                        .merchantFont(11, .bold)
                        .foregroundStyle(message.isSender ? MerchantTheme.brand : MerchantTheme.heading)
                    if !arabic { Spacer(minLength: 4) }
                    if !arabic { dateLabel }
                }
                .environment(\.layoutDirection, .leftToRight)
                Text(message.type == "text" ? message.body : merchantString("support_chat_attachment", locale: locale))
                    .merchantFont(14).foregroundStyle(MerchantTheme.body).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: arabic ? .trailing : .leading)
                    .multilineTextAlignment(arabic ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(message.isSender ? MerchantTheme.brandTint : MerchantTheme.background,
                        in: RoundedRectangle(cornerRadius: 14))
            if !message.isSender {
                MerchantSupportIcon(name: "Brand", size: 36).accessibilityHidden(true)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var dateLabel: some View {
        let date = message.dateLabel(arabic: arabic)
        if !date.isEmpty {
            Text(date).merchantFont(10).foregroundStyle(MerchantTheme.muted).lineLimit(1)
        }
    }
}

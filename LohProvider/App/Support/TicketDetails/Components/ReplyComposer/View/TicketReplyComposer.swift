import SwiftUI

struct MerchantTicketReplyComposer: View {
    @Environment(\.locale) private var locale
    @Binding var draft: String
    let canReply: Bool
    let canSend: Bool
    let isSending: Bool
    let isClosed: Bool
    let error: APIError?
    let send: () -> Void
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    var body: some View {
        VStack(spacing: 10) {
            if let error { MerchantFieldError(message: error.message(localize: text)) }
            if canReply {
                HStack(alignment: .bottom, spacing: 12) {
                    TextField(text("support_chat_placeholder"), text: $draft, axis: .vertical)
                        .merchantFont(14).lineLimit(1...5).padding(12)
                        .background(MerchantTheme.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(MerchantTheme.border, lineWidth: 1) }
                        .accessibilityIdentifier("ticketReplyText")
                    Button(action: send) {
                        Group {
                            if isSending { ProgressView().tint(MerchantTheme.ink) }
                            else { Image(systemName: "arrow.up").font(.system(size: 18, weight: .semibold)) }
                        }.frame(width: 46, height: 46)
                            .foregroundStyle(MerchantTheme.ink)
                            .background(canSend || isSending ? MerchantTheme.brand : MerchantTheme.border,
                                        in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain).disabled(!canSend)
                    .accessibilityLabel(text("support_chat_send")).accessibilityIdentifier("sendTicketReply")
                }
            } else {
                Label(text(isClosed ? "support_chat_closed" : "support_chat_unavailable"), systemImage: "lock")
                    .merchantFont(13).foregroundStyle(MerchantTheme.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
        }.padding(16).background(MerchantTheme.surface)
            .overlay(alignment: .top) { Rectangle().fill(MerchantTheme.border).frame(height: 1) }
    }
}

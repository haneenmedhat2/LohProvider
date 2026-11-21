import SwiftUI

struct MerchantTicketConversationView: View {
    @StateObject private var model: MerchantTicketDetailViewModel
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var nearBottom = true
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    init(model: @autoclosure @escaping () -> MerchantTicketDetailViewModel) {
        _model = StateObject(wrappedValue: model())
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                        if model.isLoading { ProgressView().tint(MerchantTheme.brand).padding(8) }
                        if let error = model.error {
                            MerchantOfferFailureView(error: error) { await model.reload() }
                        }
                        if let ticket = model.ticket {
                            MerchantTicketCard(ticket: ticket, showsPreview: false)
                            MerchantCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 8) {
                                        Text(text("support_request_details"))
                                            .merchantFont(16, .bold).foregroundStyle(MerchantTheme.heading)
                                        Spacer()
                                        MerchantSupportIcon(name: "Document", size: 20)
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                    Text(ticket.detail.value(arabic: arabic))
                                        .merchantFont(14).foregroundStyle(MerchantTheme.body)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment( .leading)
                                }
                            }
                        }
                        if model.hasLoaded {
                            MerchantCard {
                                LazyVStack(spacing: 14) {
                                    HStack(spacing: 8) {
                                        Text(text("support_conversation"))
                                            .merchantFont(16, .bold).foregroundStyle(MerchantTheme.heading)
                                        Spacer()
                                        MerchantSupportIcon(name: "Chat", size: 20)
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                    .padding(.bottom, 2)
                                    if model.hasMore {
                                        Button { Task { await model.loadMore() } } label: {
                                            if model.isLoadingMore { ProgressView().tint(MerchantTheme.brand) }
                                            else { Text(text("support_chat_more")).merchantFont(13, .medium) }
                                        }.disabled(model.isLoadingMore || model.isLoading || model.isSending)
                                            .foregroundStyle(MerchantTheme.brand).padding(6)
                                    }
                                    if let error = model.pageError {
                                        MerchantOfferFailureView(error: error) { await model.loadMore() }
                                    }
                                    if model.messages.isEmpty {
                                        Text(text("support_chat_empty")).merchantFont(14).foregroundStyle(MerchantTheme.muted)
                                            .multilineTextAlignment(.center).padding(24)
                                    }
                                    ForEach(model.messages) { message in
                                        MerchantTicketMessageRow(message: message).id(message.id)
                                    }
                                }
                            }
                        }
                        Color.clear.frame(height: 1).id("conversationBottom")
                            .onAppear { nearBottom = true }
                            .onDisappear { nearBottom = false }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await model.reload() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.hasLoaded {
                    MerchantTicketReplyComposer(draft: $model.draft, canReply: model.canReply, canSend: model.canSend,
                                               isSending: model.isSending, isClosed: model.ticket?.isOpen == false,
                                               error: model.sendError) { Task { await model.send() } }
                }
            }
            .onChange(of: model.scrollRequest) { _ in proxy.scrollTo("conversationBottom", anchor: .bottom) }
            .onChange(of: model.messages.last?.id) { _ in
                if nearBottom { proxy.scrollTo("conversationBottom", anchor: .bottom) }
            }
        }
        .background(MerchantTheme.background.ignoresSafeArea(.container))
        .task(id: locale.identifier) { model.activate(); await model.reload() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.activate(); Task { await model.reload(silently: true) } }
            else if phase == .background { model.stop() }
        }
        // Same notification names as the supplied LOH reference. Always fetch
        // the server permission; a notification alone must not close a ticket.
        .onReceive(NotificationCenter.default.publisher(for: .init("complaint_reply"))) { _ in
            Task { await model.reload(silently: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("complaint_closed"))) { _ in
            Task { await model.reload(silently: true) }
        }
        .onDisappear { model.stop() }
    }
}

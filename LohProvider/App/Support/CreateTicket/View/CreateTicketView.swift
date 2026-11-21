import SwiftUI

struct MerchantCreateTicketView: View {
    @EnvironmentObject private var store: MerchantSupportViewModel
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @Environment(\.locale) private var locale
    @State private var draft = MerchantTicketDraft()
    @State private var attempted = false
    @State private var submissionError: APIError?
    @State private var submission: Task<Void, Never>?
    @FocusState private var focused: MerchantTicketDraft.Field?

    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }

    private var selectedTypeName: String? {
        store.ticketTypes.first(where: { $0.id == draft.typeID })?.name
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        MerchantSupportTile(name: "Create", size: arabic ? 40 : 36, tile: arabic ? 80 : 72, circle: true)
                        Text(text("support_help_heading")).merchantFont(20, .bold).foregroundStyle(MerchantTheme.heading)
                        Text(text("support_form_hint")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)

                    MerchantCard(padding: arabic ? 20 : 16) {
                        VStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                label("support_issue_type")
                                Menu {
                                    ForEach(store.ticketTypes) { type in
                                        Button(type.name) { draft.typeID = type.id }
                                    }
                                } label: {
                                    selectorFace(selectedTypeName, placeholder: "support_issue_type_placeholder",
                                                 icon: "LOHTicketType")
                                }
                                .disabled(store.isLoadingTicketTypes || store.ticketTypes.isEmpty)
                                .accessibilityIdentifier("support_type_selector")
                                error(.type)
                            }
                            .id(MerchantTicketDraft.Field.type)

                            if let loadError = store.ticketTypesError {
                                MerchantFieldError(message: loadError.message(localize: text))
                                Button(text("api_retry")) { Task { await store.loadTicketTypes() } }
                                    .merchantFont(13, .medium)
                            } else if !store.isLoadingTicketTypes && store.ticketTypes.isEmpty {
                                Text(text("support_no_types")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text(text("support_related_order")).foregroundStyle(MerchantTheme.body)
                                    Text(text("support_optional")).foregroundStyle(MerchantTheme.muted)
                                }
                                .merchantFont(13, .bold)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Menu {
                                    Button(text("support_no_order")) { draft.orderID = nil }
                                    ForEach(store.ticketOrders) { order in
                                        Button(order.orderNumber) { draft.orderID = order.id }
                                    }
                                } label: {
                                    selectorFace(draft.orderID.map { id in
                                        store.ticketOrders.first(where: { $0.id == id })?.orderNumber ?? "#\(id)"
                                    }, placeholder: "support_related_order_placeholder", icon: "LOHTicketOrder")
                                }
                                .disabled(store.isLoadingTicketOrders || store.ticketOrders.isEmpty)
                                .accessibilityIdentifier("support_order_selector")
                                error(.order)
                            }
                            .id(MerchantTicketDraft.Field.order)

                            if let loadError = store.ticketOrdersError {
                                MerchantFieldError(message: loadError.message(localize: text))
                                Button(text("api_retry")) { Task { await store.loadTicketOrders() } }
                                    .merchantFont(13, .medium)
                            } else if !store.isLoadingTicketOrders && store.ticketOrders.isEmpty {
                                Text(text("support_no_orders")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                label("support_title")
                                TextField(text("support_title_placeholder"), text: $draft.title)
                                    .focused($focused, equals: .title)
                                    .merchantFont(14)
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 54)
                                    .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(MerchantTheme.border))
                                    .onChange(of: draft.title) { draft.title = String($0.prefix(191)) }
                                    .accessibilityIdentifier("support_title_field")
                                error(.title)
                            }
                            .id(MerchantTicketDraft.Field.title)

                            VStack(alignment: .leading, spacing: 8) {
                                label("support_description")
                                TextField(text("support_detail_placeholder"), text: $draft.detail, axis: .vertical)
                                    .lineLimit(5...8)
                                    .focused($focused, equals: .detail)
                                    .merchantFont(14)
                                    .padding(14)
                                    .frame(minHeight: 150, alignment: .topLeading)
                                    .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(MerchantTheme.border))
                                    .onChange(of: draft.detail) { draft.detail = String($0.prefix(1_000)) }
                                    .accessibilityIdentifier("support_detail_field")
                                counter(draft.detail.count, limit: 1_000)
                                error(.detail)
                            }
                            .id(MerchantTicketDraft.Field.detail)
                        }
                    }

                    MerchantSupportNotice(key: "support_contact_notice")
                    MerchantFieldError(message: submissionError?.message(localize: text))
                    MerchantButton(title: text("support_submit"), isLoading: store.isSubmitting) {
                        attempted = true
                        guard draft.isValid else {
                            if let field = MerchantTicketDraft.Field.allCases.first(where: { draft.error(for: $0) != nil }) {
                                focused = field == .title || field == .detail ? field : nil
                                withAnimation { proxy.scrollTo(field, anchor: .center) }
                            }
                            return
                        }
                        focused = nil
                        guard submission == nil else { return }
                        submissionError = nil
                        submission = Task {
                            defer { submission = nil }
                            do {
                                let ticket = try await store.submit(draft)
                                try Task.checkCancellation()
                                stack.path = stack.path.filter { $0 != .createTicket } + [.supportSent(ticket.id)]
                            } catch {
                                guard !Task.isCancelled, !(error is CancellationError),
                                      (error as? URLError)?.code != .cancelled else { return }
                                submissionError = APIError.map(error)
                            }
                        }
                    }
                    .disabled(store.isLoadingTicketTypes || store.ticketTypes.isEmpty)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(arabic ? MerchantTheme.background : .white)
        .modifier(MerchantAccountNavigation(title: "support_create_title"))
        .task(id: locale.identifier) { await store.loadTicketTypes() }
        .task(id: locale.identifier) { await store.loadTicketOrders() }
        .onChange(of: store.ticketTypes) { types in
            if !types.contains(where: { $0.id == draft.typeID }) { draft.typeID = "" }
        }
        .onChange(of: store.ticketOrders) { orders in
            if let id = draft.orderID, !orders.contains(where: { $0.id == id }) { draft.orderID = nil }
        }
        .onDisappear { submission?.cancel() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(text("support_done")) { focused = nil }
            }
        }
    }

    private func selectorFace(_ selected: String?, placeholder: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .frame(width: 36, height: 36)
                .background(Color(red: 1, green: 245/255, blue: 242/255), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            Text(selected ?? text(placeholder))
                .merchantFont(13)
                .foregroundStyle(selected == nil ? MerchantTheme.muted : MerchantTheme.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image("LOHTicketDown")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 66)
        .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MerchantTheme.border))
    }

    private func label(_ key: String) -> some View {
        HStack(spacing: 4) {
            Text(text(key)).foregroundStyle(MerchantTheme.body)
            Text("*").foregroundStyle(MerchantTheme.brand)
        }
        .merchantFont(13, .bold)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func counter(_ count: Int, limit: Int) -> some View {
        Text("\(count)/\(limit)")
            .merchantFont(11)
            .foregroundStyle(MerchantTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
    }

    private func error(_ field: MerchantTicketDraft.Field) -> some View {
        MerchantFieldError(message: attempted ? draft.error(for: field).map(text) : nil)
    }
}

import SwiftUI

struct MerchantNotificationsView: View {
    @EnvironmentObject private var store: MerchantNotificationsViewModel
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @EnvironmentObject private var tabs: MerchantTabsCoordinator
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var deletion: MerchantNotificationDeletion?
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.isLoading {
                        ProgressView().tint(MerchantTheme.brand).padding()
                            .accessibilityIdentifier("merchantNotificationsLoading")
                    }
                    if let error = store.error {
                        MerchantOfferFailureView(error: error) { await store.reload() }
                    }
                    if store.countError != nil && store.error == nil {
                        VStack(spacing: 8) {
                            MerchantFieldError(message: text("notifications_count_unavailable"))
                            Button(text("api_retry")) { Task { await store.refreshCount() } }
                                .merchantFont(14, .medium).foregroundStyle(MerchantTheme.brand)
                        }.padding(12)
                    }
                    ForEach(store.notifications) { item in
                        MerchantNotificationRow(notification: item, isUpdating: store.isMutating, open: {
                            Task { await store.markAsRead(id: item.id) }
                            switch item.destination {
                           // case .order(let id): tabs.open(.orderDetails(id), in: .offers)
                            case .settlements: tabs.select(.settlements)
                            case .offer(let id): stack.push(.offerDetails(id))
                            case .notifications,.order: break
                            }
                        }, delete: { deletion = .one(item.id) })
                    }
                    if store.isLoadingMore {
                        ProgressView().tint(MerchantTheme.brand).padding()
                    } else if let error = store.pageError {
                        MerchantOfferFailureView(error: error) { await store.loadMore() }
                    } else if store.hasMore && store.error == nil {
                        Button(text("notifications_load_more")) { Task { await store.loadMore() } }
                            .merchantFont(14, .medium).foregroundStyle(MerchantTheme.brand).padding(12)
                            .disabled(store.isLoading)
                    }
                }.padding(16)
            }
            .refreshable { await store.reload() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if store.hasLoaded && store.notifications.isEmpty && !store.isLoading && !store.isLoadingMore
                    && !store.hasMore && store.error == nil && store.pageError == nil {
                    MerchantNotificationsEmptyState().padding(24).allowsHitTesting(false)
                }
            }
            .disabled(store.isMutating)
        }
        .background(MerchantTheme.notificationCanvas.ignoresSafeArea())
        .navigationTitle(text("nav_notifications"))
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            MerchantNotificationNavigationBar(count: store.count, canMarkAllAsRead: store.canMarkAllAsRead,
                                              onBack: { dismiss() }, onMarkAllAsRead: {
                Task { await store.markAllAsRead() }
            })
        }
        .overlay {
            if store.isMutating {
                ProgressView().tint(MerchantTheme.brand).padding(24)
                    .background(MerchantTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("merchantNotificationUpdating")
            }
        }
        .confirmationDialog(text(deletion?.titleKey ?? "notifications_delete_confirm"),
                            isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }),
                            titleVisibility: .visible, presenting: deletion) { action in
            Button(text("notifications_delete"), role: .destructive) {
                deletion = nil
                Task { await store.delete(action) }
            }
            Button(text("nav_cancel"), role: .cancel) { deletion = nil }
        }
        .alert(text("nav_notifications"), isPresented: Binding(get: { store.mutationError != nil }, set: {
            if !$0 { store.dismissMutationError() }
        })) {
            Button(text("nav_cancel"), role: .cancel) { store.dismissMutationError() }
        } message: {
            if let error = store.mutationError { Text(error.message(localize: text)) }
        }
        .task(id: locale.identifier) { await store.reload() }
        .onDisappear { store.cancelRefresh() }
    }
}

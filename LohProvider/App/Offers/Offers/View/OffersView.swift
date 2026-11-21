import SwiftUI

struct MerchantOffersView: View {
    @EnvironmentObject private var store: MerchantOffersViewModel
    @EnvironmentObject private var notifications: MerchantNotificationsViewModel
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @Environment(\.locale) private var locale
    @Environment(\.merchantProfile) private var merchantProfile
    @Environment(\.scenePhase) private var scenePhase
    @State private var query = ""
    @State private var sort: MerchantOfferSort = .recent
    @State private var isPullRefreshing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MerchantStoreNavigationHeader(
                    greeting: store.vendor?.greeting ?? merchantString("report_hello", locale: locale),
                    name: store.vendor?.name ?? merchantProfile?.name,
                    image: merchantProfile?.image ?? store.vendor?.image,
                    notificationCount: notifications.count ?? 0,
                    onNotifications: { stack.push(.notifications) })
                controls
                offerList
            }
        }
        .refreshable {
            isPullRefreshing = true
            Task { @MainActor in
                async let offers: Void = store.refresh(query: query, sort: sort)
                async let count: Void = notifications.refreshCount()
                _ = await (offers, count)
                isPullRefreshing = false
            }
        }
        .overlay(alignment: .top) {
            if isPullRefreshing {
                ProgressView()
                    .tint(MerchantTheme.brand)
                    .padding(10)
                    .background(MerchantTheme.surface, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                    .padding(.top, 8)
                    .accessibilityIdentifier("merchantOffersPullRefreshLoading")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(MerchantTheme.surface.ignoresSafeArea())
        .navigationTitle(merchantString("tab_offers", locale: locale))
        .toolbar(.hidden, for: .navigationBar)
        .task(id: [query, sort.rawValue, locale.identifier]) {
            await store.reload(query: query, sort: sort, debounce: !query.isEmpty)
        }
        .onDisappear { store.cancelRefresh() }
        .task(id: locale.identifier) { await notifications.refreshCount() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await notifications.refreshCount() } }
        }
    }

    private var controls: some View {
        MerchantOffersControls(query: $query, sort: $sort) { sheet in
            store.beginCodeVerification()
            coordinator.sheet = sheet == .orderCode ? .offersOrderCode : sheet
        }
    }

    private var offerList: some View {
        LazyVStack(spacing: 12) {
            if store.isLoading {
                ProgressView()
                    .tint(MerchantTheme.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .accessibilityIdentifier("merchantOffersLoading")
            }
            else if let error = store.error {
                MerchantOfferFailureView(error: error) { await reload() }
            } else if store.offers.isEmpty {
                Text(merchantString("offers_empty", locale: locale)).merchantFont(15).foregroundStyle(MerchantTheme.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
            ForEach(store.offers) { offer in
                Button { stack.push(.offerDetails(offer.id)) } label: { MerchantOfferRow(offer: store.offer(offer.id) ?? offer) }
                    .buttonStyle(.plain).accessibilityIdentifier("merchantOffer_" + offer.id)
            }
            if let error = store.pageError {
                MerchantOfferFailureView(error: error) { await store.loadMore() }
            } else if store.hasMore {
                MerchantButton(title: merchantString("offers_load_more", locale: locale), secondary: true, isLoading: store.isLoadingMore) {
                    Task { await store.loadMore() }
                }.disabled(store.isLoading).padding(.vertical, 4)
            }
        }.padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func reload() async { await store.reload(query: query, sort: sort) }
}

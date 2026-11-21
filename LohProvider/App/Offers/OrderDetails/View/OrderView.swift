import SwiftUI

struct MerchantOrderView: View {
    @EnvironmentObject private var store: MerchantOffersViewModel
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let orderID: String

    private var presentation: MerchantOrderPresentation? {
        guard let order = store.order(orderID), let offer = store.offer(order.offerID) else { return nil }
        return .init(order: order, offer: offer, coupon: store.couponDetails[order.offerID]?.coupon,
                     locallyVerified: store.verifiedOrderID == orderID)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if store.loadingOrders.contains(orderID) { ProgressView().tint(MerchantTheme.brand).padding(8) }
                if let error = store.orderErrors[orderID] {
                    MerchantOfferFailureView(error: error) { await store.loadOrder(id: orderID) }
                }
                if let presentation {
                    if presentation.showsResult { MerchantOrderResultCard(presentation: presentation) }
                    MerchantOrderSummaryCard(presentation: presentation)
                    MerchantOrderCustomerCard(presentation: presentation)
                } else {
                    Text(merchantString("offers_order_missing", locale: locale)).merchantFont(16).foregroundStyle(MerchantTheme.secondary)
                }
            }.padding(.horizontal, 16).padding(.bottom, 20)
        }
        .refreshable { await store.loadOrder(id: orderID) }
        .safeAreaInset(edge: .top, spacing: 0) { MerchantOrderHeader(vendor: store.vendor) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let presentation {
                VStack(spacing: 10) {
                    if let error = store.deliveryErrors[orderID] {
                        MerchantOfferFailureView(error: error) { await store.loadOrder(id: orderID) }
                    }
                    MerchantOrderActions(presentation: presentation,
                                         isLoading: store.deliveringOrders.contains(orderID),
                                         canConfirm: store.canConfirmDelivery(id: orderID),
                                         confirm: { Task { await store.confirmDelivery(id: orderID) } },
                                         cancel: { store.clearVerification(for: orderID); dismiss() },
                                         proceed: { stack.popToRoot() },
                                         enterCode: { store.beginVerification(for: orderID); coordinator.sheet = .orderCode },
                                         scan: { store.beginVerification(for: orderID); coordinator.sheet = .scanner })
                }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
                    .background(MerchantTheme.surface)
                    .overlay(alignment: .top) { Rectangle().fill(MerchantTheme.subtle.opacity(0.4)).frame(height: 1) }
            }
        }
        .background(MerchantTheme.surface.ignoresSafeArea())
        .navigationTitle(merchantString("nav_order_details", locale: locale))
        .toolbar(.hidden, for: .navigationBar)
        .task(id: [orderID, locale.identifier]) { await store.loadOrder(id: orderID) }
        .onDisappear { store.clearVerification(for: orderID) }
    }
}

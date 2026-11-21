import SwiftUI

struct MerchantOfferDetailView: View {
    @EnvironmentObject private var store: MerchantOffersViewModel
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @Environment(\.locale) private var locale
    let offerID: String
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let offer = store.offer(offerID) {
                    VStack(spacing: 16) {
                        MerchantOfferDetailSummary(offer: offer, coupon: store.couponDetails[offerID]?.coupon, width: geometry.size.width)
                        Text(text("offers_latest_orders")).merchantFont(16, .bold)
                            .foregroundStyle(MerchantTheme.heading).accessibilityAddTraits(.isHeader)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        let orders = store.orders(for: offerID)
                        if store.loadingCustomers.contains(offerID) {
                            ProgressView().tint(MerchantTheme.brand).padding()
                                .accessibilityIdentifier("merchantOfferDetailsLoading")
                        }
                        if let error = store.customerErrors[offerID] {
                            MerchantOfferFailureView(error: error) { await store.loadCouponDetails(offerID: offerID) }
                        } else if orders.isEmpty && !store.loadingCustomers.contains(offerID) {
                            Text(text("offers_no_customers")).merchantFont(14).foregroundStyle(MerchantTheme.muted).padding(24)
                        }
                        if !orders.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(orders) { order in
                                    Button { stack.push(.orderDetails(order.id)) } label: {
                                        MerchantOfferRecentOrderRow(order: order, offer: offer, preview: store.allowsLocalVerification)
                                    }.buttonStyle(.plain).accessibilityIdentifier("merchantRecentOrder_" + order.id)
                                    if order.id != orders.last?.id { Rectangle().fill(MerchantTheme.background).frame(height: 1) }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MerchantTheme.subtle))
                            .padding(.top, -8)
                        }
                    }.padding(16).padding(.bottom, 24)
                } else {
                    VStack(spacing: 16) {
                        if store.loadingCustomers.contains(offerID) {
                            ProgressView().tint(MerchantTheme.brand).padding(24)
                        } else if let error = store.customerErrors[offerID] {
                            MerchantOfferFailureView(error: error) { await store.loadCouponDetails(offerID: offerID) }
                        } else { Text(text("offers_empty")).merchantFont(15).padding(24) }
                    }.frame(maxWidth: .infinity)
                }
            }.background(MerchantTheme.surface)
                .refreshable { await store.refreshCouponDetails(offerID: offerID) }
        }
        .modifier(MerchantOfferNavigation(title: "nav_offer_details"))
        .task(id: [offerID, locale.identifier]) { await store.loadCouponDetails(offerID: offerID) }
        .onDisappear { store.cancelCouponRefresh(offerID: offerID) }
    }
}

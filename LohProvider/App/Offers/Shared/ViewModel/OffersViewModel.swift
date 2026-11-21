import Foundation
import Combine

@MainActor final class MerchantOffersViewModel: ObservableObject {
    @Published private(set) var offers: [MerchantOffer] = []
    @Published private(set) var orders: [MerchantOfferOrder] = []
    @Published private(set) var totalItems: Int?
    @Published private(set) var vendor: MerchantOfferVendor?
    @Published private(set) var stats: MerchantOfferStatistics?
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: APIError?
    @Published private(set) var pageError: APIError?
    @Published private(set) var loadingCustomers: Set<String> = []
    @Published private(set) var customerErrors: [String: APIError] = [:]
    @Published private(set) var couponDetails: [String: MerchantCouponDetails] = [:]
    @Published private(set) var loadingOrders: Set<String> = []
    @Published private(set) var orderErrors: [String: APIError] = [:]
    @Published private(set) var sales: [String: MerchantCouponSale] = [:]
    @Published private(set) var loadingSales: Set<String> = []
    @Published private(set) var saleErrors: [String: APIError] = [:]
    @Published private(set) var deliveringOrders: Set<String> = []
    @Published private(set) var deliveryErrors: [String: APIError] = [:]
    @Published private(set) var deliveryMessages: [String: String] = [:]
    @Published private(set) var isVerifying = false
    @Published private(set) var verificationAPIError: APIError?
    @Published private(set) var verificationOrderID: String?
    @Published var verificationError: MerchantVerificationError?
    @Published var pendingOrderID: String?
    @Published private(set) var verifiedOrderID: String?

    private let responseHandler: ResponseHandler?
    private var token: () -> String? = { nil }
    private var query = ""
    private var sort: MerchantOfferSort = .recent
    private var currentPage = 0
    private var generation = UUID()
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = UUID()
    private var customerGenerations: [String: UUID] = [:]
    private var couponRefreshes: [String: (id: UUID, task: Task<Void, Never>)] = [:]
    private var orderGenerations: [String: UUID] = [:]
    private var saleGenerations: [String: UUID] = [:]
    private var verificationGeneration = UUID()
    private var confirmedDeliveries: Set<String> = []
    private var deliveringCodes: Set<String> = []
    private var accountToken: String?
    private var offerCache: [String: MerchantOffer] = [:]
    private var now = Date()

    init(responseHandler: ResponseHandler, token: @escaping () -> String?) {
        self.responseHandler = responseHandler
        self.token = token
        accountToken = token()
    }

    #if DEBUG
    private init(previewDate: Date) {
        responseHandler = nil
        now = previewDate
        offers = Self.previewOffers
        orders = Self.previewOrders
        totalItems = offers.count
        vendor = Self.previewVendor
        stats = Self.previewStatistics
        offerCache = Dictionary(uniqueKeysWithValues: offers.map { ($0.id, $0) })
    }
    #endif

    var allowsLocalVerification: Bool {
        #if DEBUG
        return responseHandler == nil
        #else
        return false
        #endif
    }

    func offer(_ id: String) -> MerchantOffer? {
        // Notifications can open an offer that is outside the current home-page filters or pages.
        let coupon = couponDetails[id]?.coupon
        guard let offer = offers.first(where: { $0.id == id }) ?? offerCache[id] ?? coupon.map({
            MerchantOffer(id: $0.id, nameAr: $0.name, nameEn: $0.name, salesCount: 0,
                          lohHalalas: 0, salesHalalas: 0, createdAt: $0.publishedAt)
        }) else { return nil }
        return couponDetails[id]?.coupon.applying(to: offer) ?? offer
    }
    func order(_ id: String) -> MerchantOfferOrder? { orders.first { $0.id == id } }
    func orders(for offerID: String) -> [MerchantOfferOrder] { orders.filter { $0.offerID == offerID } }

    /// A new query/sort/language generation supersedes every older page request.
    func reload(query: String, sort: MerchantOfferSort, debounce: Bool = false) async {
        guard !Task.isCancelled else { return }
        cancelRefresh()
        await loadOffers(query: query, sort: sort, debounce: debounce)
    }

    /// Own the request independently of SwiftUI's transient pull-to-refresh task.
    /// A filter change or leaving the screen explicitly cancels it.
    func refresh(query: String, sort: MerchantOfferSort) async {
        synchronizeAccount()
        cancelRefresh()
        let refreshGeneration = UUID()
        self.refreshGeneration = refreshGeneration
        let task = Task { await loadOffers(query: query, sort: sort) }
        refreshTask = task
        await task.value
        if self.refreshGeneration == refreshGeneration { refreshTask = nil }
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshGeneration = UUID()
    }

    private func loadOffers(query: String, sort: MerchantOfferSort, debounce: Bool = false) async {
        guard !Task.isCancelled else { return }
        synchronizeAccount()
        let generation = UUID()
        self.generation = generation
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtersChanged = self.query != query || self.sort != sort
        self.query = query
        self.sort = sort
        error = nil; pageError = nil; isLoadingMore = false; isLoading = true
        // Keep the complete snapshot, including pagination, until a refresh succeeds.
        // A different filter must never display or append the previous filter's results.
        if filtersChanged {
            offers = []; totalItems = nil; currentPage = 0; hasMore = false; vendor = nil; stats = nil
        }
        defer {
            if self.generation == generation { isLoading = false }
            synchronizeAccount()
        }
        do {
            if debounce { try await Task.sleep(nanoseconds: 300_000_000) }
            try Task.checkCancellation()
            #if DEBUG
            if responseHandler == nil {
                offers = Self.previewOffers.filter {
                    self.query.isEmpty || $0.nameAr.localizedStandardContains(self.query) || $0.nameEn.localizedStandardContains(self.query)
                }.sorted {
                    switch sort {
                    case .recent: return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                    case .oldest: return ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
                    case .highPrice: return ($0.priceHalalas ?? 0) > ($1.priceHalalas ?? 0)
                    case .lowPrice: return ($0.priceHalalas ?? 0) < ($1.priceHalalas ?? 0)
                    }
                }
                totalItems = offers.count
                vendor = Self.previewVendor
                stats = Self.previewStatistics
                return
            }
            #endif
            guard responseHandler != nil, let token = token() else { throw APIError.unauthenticated(nil) }
            let page = try await loadOffers(query: query, sort: sort, page: 1, token: token)
            try Task.checkCancellation()
            guard self.generation == generation, self.token() == token else { return }
            apply(page, replacing: true)
        } catch {
            guard self.generation == generation, accountToken == self.token(), !isCancellation(error) else { return }
            self.error = APIError.map(error)
        }
    }

    func loadMore() async {
        synchronizeAccount()
        guard hasMore, !isLoading, !isLoadingMore, responseHandler != nil, let token = token() else { return }
        let generation = generation
        isLoadingMore = true; pageError = nil
        defer {
            if self.generation == generation { isLoadingMore = false }
            synchronizeAccount()
        }
        do {
            let page = try await loadOffers(query: query, sort: sort, page: currentPage + 1, token: token)
            try Task.checkCancellation()
            guard self.generation == generation, self.token() == token else { return }
            apply(page, replacing: false)
        } catch {
            guard self.generation == generation, accountToken == self.token(), !isCancellation(error) else { return }
            pageError = APIError.map(error)
        }
    }

    func loadCustomers(offerID: String) async {
        guard !Task.isCancelled else { return }
        cancelCouponRefresh(offerID: offerID)
        await loadPurchases(offerID: offerID, allCustomers: true)
    }

    func loadCouponDetails(offerID: String) async {
        guard !Task.isCancelled else { return }
        cancelCouponRefresh(offerID: offerID)
        await loadPurchases(offerID: offerID, allCustomers: false)
    }

    /// Keep pull-to-refresh independent of the gesture task, as on the offers list.
    func refreshCouponDetails(offerID: String) async {
        synchronizeAccount()
        cancelCouponRefresh(offerID: offerID)
        let id = UUID()
        let task = Task { await loadPurchases(offerID: offerID, allCustomers: false) }
        couponRefreshes[offerID] = (id, task)
        await task.value
        if couponRefreshes[offerID]?.id == id { couponRefreshes[offerID] = nil }
    }

    func cancelCouponRefresh(offerID: String) {
        couponRefreshes[offerID]?.task.cancel()
        couponRefreshes[offerID] = nil
    }

    private func loadPurchases(offerID: String, allCustomers: Bool) async {
        guard !Task.isCancelled else { return }
        synchronizeAccount()
        guard responseHandler != nil else { return }
        let generation = UUID()
        customerGenerations[offerID] = generation
        loadingCustomers.insert(offerID); customerErrors[offerID] = nil
        defer {
            if customerGenerations[offerID] == generation { loadingCustomers.remove(offerID) }
            synchronizeAccount()
        }
        do {
            try Task.checkCancellation()
            guard let token = token() else { throw APIError.unauthenticated(nil) }
            let rows: [MerchantOfferOrder]
            let details: MerchantCouponDetails?
            if allCustomers {
                rows = try await loadCustomers(couponID: offerID, token: token)
                details = nil
            } else {
                let response = try await loadCouponDetailsData(couponID: offerID, token: token)
                rows = response.orders
                details = response
            }
            try Task.checkCancellation()
            guard customerGenerations[offerID] == generation, self.token() == token else { return }
            if let details { couponDetails[offerID] = details }
            let rowIDs = Set(rows.map(\.id))
            orders.removeAll { $0.offerID == offerID && !rowIDs.contains($0.id) }
            merge(rows)
            // Keep the server's order after merging retained customer/delivery metadata.
            let merged = Dictionary(uniqueKeysWithValues: orders.map { ($0.id, $0) })
            var seen: Set<String> = []
            let orderedRows = rows.compactMap { row in
                seen.insert(row.id).inserted ? merged[row.id] : nil
            }
            orders = orders.filter { $0.offerID != offerID } + orderedRows
        } catch {
            guard customerGenerations[offerID] == generation, accountToken == token(), !isCancellation(error) else { return }
            customerErrors[offerID] = APIError.map(error)
        }
    }

    func loadOrder(id: String) async {
        synchronizeAccount()
        guard responseHandler != nil, let selected = order(id) else { return }
        let generation = UUID()
        orderGenerations[id] = generation
        loadingOrders.insert(id); orderErrors[id] = nil
        defer {
            if orderGenerations[id] == generation { loadingOrders.remove(id) }
            synchronizeAccount()
        }
        do {
            guard let token = token() else { throw APIError.unauthenticated(nil) }
            guard let orderID = selected.serverOrderID, !orderID.isEmpty else { throw APIError.invalidResponse }
            let refreshed = try await loadOrderDetails(orderID: orderID, token: token)
            try Task.checkCancellation()
            guard orderGenerations[id] == generation, self.token() == token else { return }
            guard selected.matchesPurchase(refreshed) else {
                throw APIError.invalidResponse
            }
            merge([refreshed])
            deliveryErrors[id] = nil
        } catch {
            guard orderGenerations[id] == generation, accountToken == token(), !isCancellation(error) else { return }
            orderErrors[id] = APIError.map(error)
        }
    }

    func loadSale(id: String) async {
        synchronizeAccount()
        guard responseHandler != nil, let selected = order(id), orderErrors[id] == nil else { return }
        let generation = UUID()
        saleGenerations[id] = generation
        loadingSales.insert(id); saleErrors[id] = nil
        defer {
            if saleGenerations[id] == generation { loadingSales.remove(id) }
            synchronizeAccount()
        }
        do {
            guard let current = token() else { throw APIError.unauthenticated(nil) }
            // No separate sale ID is exposed in the saved customer/detail arrays. Start with the coupon ID,
            // and reject a response for any other purchase instead of displaying another customer's amounts.
            let sale = try await loadCouponSale(id: selected.offerID, token: current)
            try Task.checkCancellation()
            guard saleGenerations[id] == generation, token() == current else { return }
            guard sale.purchaseCode == selected.code, sale.customerID == selected.customerID else {
                sales[id] = nil
                throw APIError.invalidResponse
            }
            sales[id] = sale
        } catch {
            guard saleGenerations[id] == generation, accountToken == token(), !isCancellation(error) else { return }
            saleErrors[id] = APIError.map(error)
        }
    }

    func beginVerification(for id: String) {
        synchronizeAccount()
        guard order(id) != nil, !isVerifying else { return }
        verificationOrderID = id; verifiedOrderID = nil; pendingOrderID = nil
        verificationError = nil; verificationAPIError = nil
    }

    /// Starts the live Offers-screen flow, where the order is resolved from the
    /// code entered by the customer rather than from a previously selected row.
    func beginCodeVerification() {
        synchronizeAccount()
        guard !isVerifying else { return }
        verificationOrderID = nil; verifiedOrderID = nil; pendingOrderID = nil
        verificationError = nil; verificationAPIError = nil
    }

    nonisolated static func normalizedPurchaseCode(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.allSatisfy({ $0.wholeNumberValue.map { (0...9).contains($0) } == true }) else { return nil }
        return value.compactMap(\.wholeNumberValue).map(String.init).joined()
    }

    @discardableResult func verifyPurchase(_ raw: String, method: MerchantVerificationMethod) async -> Bool {
        if allowsLocalVerification { return verify(raw, method: method) }
        synchronizeAccount()
        guard !isVerifying, responseHandler != nil, let current = token() else { return false }
        verificationError = nil; verificationAPIError = nil; verifiedOrderID = nil; pendingOrderID = nil
        guard let code = Self.normalizedPurchaseCode(raw) else { verificationError = .invalid; return false }
        let selected = verificationOrderID.flatMap(order)
        if let selected, code != selected.code { verificationError = .invalid; return false }
        let generation = UUID()
        verificationGeneration = generation; isVerifying = true
        defer { if verificationGeneration == generation { isVerifying = false }; synchronizeAccount() }
        do {
            // From Offers, the entered code is the order-details route identifier.
            // From an existing order screen, retain the server order ID already decoded for that row.
            let routeID: String
            if let selected { routeID = selected.serverOrderID ?? "" }
            else { routeID = code }
            guard !routeID.isEmpty else { throw APIError.invalidResponse }
            var refreshed = try await loadOrderDetails(orderID: routeID, token: current)
            try Task.checkCancellation()
            guard verificationGeneration == generation, token() == current else { return false }
            if let selected {
                guard verificationOrderID == selected.id, refreshed.id == selected.id, selected.matchesPurchase(refreshed) else {
                    throw APIError.invalidResponse
                }
            } else {
                // Offers-screen entry uses coupon_number as the route code. The
                // response also contains a separate purchase_code, so either
                // response identifier may match the entered value.
                guard refreshed.code == code || refreshed.details?.couponNumber == code else {
                    throw APIError.invalidResponse
                }
                verificationOrderID = refreshed.id
            }
            merge([refreshed])
            guard !refreshed.isDelivered, !confirmedDeliveries.contains(refreshed.id) else {
                verificationError = .delivered
                return false
            }
            guard verificationOrderID == refreshed.id else {
                throw APIError.invalidResponse
            }
            refreshed.method = method; merge([refreshed])
            verifiedOrderID = refreshed.id; pendingOrderID = refreshed.id
            orderErrors[refreshed.id] = nil; deliveryErrors[refreshed.id] = nil
            return true
        } catch {
            guard verificationGeneration == generation, token() == current, !isCancellation(error) else { return false }
            verificationAPIError = APIError.map(error)
            return false
        }
    }

    func cancelVerification() {
        verificationGeneration = UUID(); isVerifying = false
        verificationOrderID = nil; verificationError = nil; verificationAPIError = nil
        verifiedOrderID = nil; pendingOrderID = nil
    }

    func canConfirmDelivery(id: String) -> Bool {
        guard let selected = order(id), !selected.isDelivered, !confirmedDeliveries.contains(id),
              !deliveringCodes.contains(selected.code), !loadingOrders.contains(id), orderErrors[id] == nil else { return false }
        return verifiedOrderID == id || (selected.isReadyForDelivery && selected.details != nil && deliveryErrors[id] == nil)
    }

    @discardableResult func confirmDelivery(id: String) async -> Bool {
        if allowsLocalVerification { return deliver(id) }
        synchronizeAccount()
        guard responseHandler != nil, let selected = order(id), let current = token(), canConfirmDelivery(id: id) else { return false }
        deliveringOrders.insert(id); deliveringCodes.insert(selected.code)
        deliveryErrors[id] = nil; verifiedOrderID = nil
        defer {
            if token() == current { deliveringOrders.remove(id); deliveringCodes.remove(selected.code) }
            synchronizeAccount()
        }
        do {
            // No automatic retry: a lost/cancelled response may follow a successful server mutation.
            let message = try await deliverCouponAPI(printCode: selected.code, token: current)
            guard token() == current else { return false }
            confirmedDeliveries.insert(id)
            var delivered = order(id) ?? selected
            delivered.delivered = true
            merge([delivered])
            deliveryMessages[id] = message
            return true
        } catch {
            guard token() == current else { return false }
            deliveryErrors[id] = APIError.map(error)
            // The merchant must verify the purchase against the server again before another attempt.
            return false
        }
    }

    private func loadOffers(query: String, sort: MerchantOfferSort, page: Int, token: String) async throws -> MerchantOfferPage {
        guard page > 0, let responseHandler else { throw APIError.configuration }
        let payload: OfferPageData = try await responseHandler.data(
            from: OfferEndpoints.list(query: query, sort: sort.rawValue, page: page, token: token),
            language: AppLanguageManager.shared.apiLanguage)
        let pagination = payload.pagination
        guard pagination.currentPage == page, pagination.totalItems >= 0, pagination.totalPages >= 0,
              pagination.currentPage <= max(1, pagination.totalPages),
              pagination.totalItems >= payload.coupons.count,
              pagination.totalItems == 0 || pagination.totalPages > 0,
              pagination.totalItems > 0 || pagination.totalPages <= 1,
              !payload.coupons.isEmpty || pagination.totalItems == 0 else { throw APIError.invalidResponse }
        return .init(offers: payload.coupons.map(\.offer), totalItems: pagination.totalItems,
                     currentPage: pagination.currentPage, totalPages: pagination.totalPages,
                     vendor: payload.vendor?.vendor, stats: payload.stats?.statistics)
    }

    private func loadCustomers(couponID: String, token: String) async throws -> [MerchantOfferOrder] {
        try validateIdentifier(couponID)
        guard let responseHandler else { throw APIError.configuration }
        let payload: [PurchaseData] = try await responseHandler.data(
            from: OfferEndpoints.customers(couponID: couponID, token: token),
            language: AppLanguageManager.shared.apiLanguage)
        return payload.map { $0.order(couponID: couponID) }
    }

    private func loadCouponDetailsData(couponID: String, token: String) async throws -> MerchantCouponDetails {
        try validateIdentifier(couponID)
        guard let responseHandler else { throw APIError.configuration }
        let payload: CouponDetailsData = try await responseHandler.data(
            from: OfferEndpoints.couponDetails(id: couponID, token: token),
            language: AppLanguageManager.shared.apiLanguage)
        guard payload.coupon.id == couponID else { throw APIError.invalidResponse }
        return .init(coupon: payload.coupon,
                     orders: payload.orders.map { $0.order(couponID: couponID) }, pagination: payload.pagination)
    }

    private func loadOrderDetails(orderID: String, token: String) async throws -> MerchantOfferOrder {
        try validateIdentifier(orderID)
        guard let responseHandler else { throw APIError.configuration }
        let payload: OrderDetailsData = try await responseHandler.data(
            from: OfferEndpoints.orderDetails(id: orderID, token: token),
            language: AppLanguageManager.shared.apiLanguage)
        guard payload.order.serverOrderID == orderID || payload.order.details?.couponNumber == orderID else {
            throw APIError.invalidResponse
        }
        return payload.order
    }

    private func loadCouponSale(id: String, token: String) async throws -> MerchantCouponSale {
        try validateIdentifier(id)
        guard let responseHandler else { throw APIError.configuration }
        let payload: CouponSaleData = try await responseHandler.data(
            from: OfferEndpoints.sales(id: id, token: token),
            language: AppLanguageManager.shared.apiLanguage)
        return payload.sale
    }

    private func deliverCouponAPI(printCode: String, token: String) async throws -> String? {
        try validateIdentifier(printCode)
        guard let responseHandler else { throw APIError.configuration }
        let response = try await responseHandler.send(
            OfferEndpoints.deliver(printCode: printCode, token: token),
            language: AppLanguageManager.shared.apiLanguage)
        return response.msg
    }

    private func validateIdentifier(_ value: String) throws {
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw APIError.configuration }
    }


    private func synchronizeAccount() {
        guard responseHandler != nil, accountToken != token() else { return }
        cancelRefresh()
        for refresh in couponRefreshes.values { refresh.task.cancel() }
        couponRefreshes = [:]
        accountToken = token()
        generation = UUID(); verificationGeneration = UUID()
        customerGenerations = [:]; orderGenerations = [:]; saleGenerations = [:]
        offers = []; orders = []; offerCache = [:]; totalItems = nil; vendor = nil; stats = nil
        currentPage = 0; hasMore = false; isLoading = false; isLoadingMore = false
        error = nil; pageError = nil; customerErrors = [:]; orderErrors = [:]; saleErrors = [:]
        loadingCustomers = []; loadingOrders = []; loadingSales = []; sales = [:]
        couponDetails = [:]
        deliveringOrders = []; deliveringCodes = []; confirmedDeliveries = []
        deliveryErrors = [:]; deliveryMessages = [:]
        verificationOrderID = nil; verifiedOrderID = nil; pendingOrderID = nil
        isVerifying = false; verificationError = nil; verificationAPIError = nil
    }

    private func apply(_ page: MerchantOfferPage, replacing: Bool) {
        if replacing { offers = [] }
        for offer in page.offers {
            if let index = offers.firstIndex(where: { $0.id == offer.id }) { offers[index] = offer }
            else { offers.append(offer) }
            offerCache[offer.id] = offer
        }
        totalItems = page.totalItems; currentPage = page.currentPage; hasMore = page.hasMore
        // Metadata describes the account, independent of the matching/loaded coupon count.
        // Later pages may omit it; only a new first page replaces the complete snapshot.
        if replacing || page.vendor != nil { vendor = page.vendor }
        if replacing || page.stats != nil { stats = page.stats }
    }
    private func merge(_ rows: [MerchantOfferOrder]) {
        for var order in rows {
            if let existing = self.order(order.id) {
                order.serverOrderID = order.serverOrderID ?? existing.serverOrderID
                order.couponName = order.couponName ?? existing.couponName
                order.purchasedAt = order.purchasedAt ?? existing.purchasedAt
                order.expiresAt = order.expiresAt ?? existing.expiresAt
                order.createdAtText = order.createdAtText ?? existing.createdAtText
                order.customerID = order.customerID ?? existing.customerID
                if order.details == nil {
                    order.phone = order.phone ?? existing.phone
                    order.details = existing.details
                }
                if order.isDelivered == existing.isDelivered { order.statusText = order.statusText ?? existing.statusText }
            }
            if confirmedDeliveries.contains(order.id) { order.delivered = true }
            if order.isDelivered {
                deliveryErrors[order.id] = nil
                if verifiedOrderID == order.id { verifiedOrderID = nil }
            }
            if order.method == nil { order.method = self.order(order.id)?.method }
            if let index = orders.firstIndex(where: { $0.id == order.id }) { orders[index] = order }
            else { orders.append(order) }
        }
    }
    private func isCancellation(_ error: Error) -> Bool {
        Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    // The six-digit fixtures are confined to the design preview; live codes have no fixed length.
    nonisolated static func normalizedCode(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6, trimmed.allSatisfy({ $0.wholeNumberValue != nil }) else { return nil }
        return trimmed.compactMap(\.wholeNumberValue).map(String.init).joined()
    }
    @discardableResult func verify(_ raw: String, method: MerchantVerificationMethod) -> Bool {
        verifiedOrderID = nil; pendingOrderID = nil; verificationError = nil
        guard allowsLocalVerification else { return false }
        guard let code = Self.normalizedCode(raw), let index = orders.firstIndex(where: { $0.code == code }) else {
            verificationError = .invalid; return false
        }
        guard !orders[index].delivered else { verificationError = .delivered; return false }
        guard let expiry = orders[index].expiresAt, expiry >= now else { verificationError = .expired; return false }
        orders[index].method = method
        verifiedOrderID = orders[index].id; pendingOrderID = orders[index].id
        return true
    }
    @discardableResult func deliver(_ id: String) -> Bool {
        guard allowsLocalVerification, verifiedOrderID == id, let index = orders.firstIndex(where: { $0.id == id }),
              !orders[index].delivered, let expiry = orders[index].expiresAt, expiry >= now else { return false }
        orders[index].delivered = true; verifiedOrderID = nil
        return true
    }
    func clearVerification(for id: String) {
        if verifiedOrderID == id { verifiedOrderID = nil }
        if verificationOrderID == id { cancelVerification() }
    }
}

#if DEBUG
extension MerchantOffersViewModel {
    private static var previewVendor: MerchantOfferVendor {
        .init(id: "preview", name: "Juice Line", greeting: nil, image: nil)
    }
    private static var previewStatistics: MerchantOfferStatistics {
        .init(totalOffers: 12, activeOffers: 6, salesCount: 398, salesHalalas: 124800, currency: "SAR")
    }
    static func preview(now: Date = MerchantOffersViewModel.date(26)) -> MerchantOffersViewModel {
        MerchantOffersViewModel(previewDate: now)
    }
    nonisolated static func date(_ day: Int, month: Int = 5, hour: Int = 10, minute: Int = 30) -> Date {
        MerchantOfferFormat.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    private static var previewOffers: [MerchantOffer] { [
        .init(id: "mojito", nameAr: "موهيتو توينز", nameEn: "Mojito Twins", artwork: "Mojito", priceHalalas: 1600, salesCount: 24, lohHalalas: 192, salesHalalas: 38400, createdAt: date(25)),
        .init(id: "rinio", nameAr: "رينيو توينز", nameEn: "Rinio Twins", artwork: "Rinio", priceHalalas: 800, salesCount: 12, lohHalalas: 480, salesHalalas: 9600, createdAt: date(25)),
        .init(id: "kombucha", nameAr: "كومبوتشا توينز", nameEn: "Kombucha Twins", artwork: "Amber", priceHalalas: 1200, salesCount: 18, lohHalalas: 180, salesHalalas: 21600, createdAt: date(20)),
        .init(id: "latte", nameAr: "لاتيه توينز", nameEn: "Latte Twins", artwork: "Latte", priceHalalas: 1400, salesCount: 10, lohHalalas: 200, salesHalalas: 14000, createdAt: date(18))
    ] }
    private static var previewOrders: [MerchantOfferOrder] { [
            .init(id: "order-1", offerID: "mojito", code: "123456", customerAr: "أحمد محمد", customerEn: "Ahmed Mohammed", purchasedAt: Self.date(25), expiresAt: Self.date(1, month: 6, hour: 23, minute: 59)),
            .init(id: "order-2", offerID: "mojito", code: "654321", customerAr: "سارة خالد", customerEn: "Sara Khalid", purchasedAt: Self.date(25, hour: 8, minute: 15), expiresAt: Self.date(1, month: 6), delivered: true, method: .barcode),
            .init(id: "order-3", offerID: "mojito", code: "234567", customerAr: "محمد علي", customerEn: "Mohammed Ali", purchasedAt: Self.date(24, hour: 17, minute: 45), expiresAt: Self.date(1, month: 6)),
            .init(id: "order-4", offerID: "rinio", code: "345678", customerAr: "نورة أحمد", customerEn: "Noura Ahmed", purchasedAt: Self.date(25), expiresAt: Self.date(1, month: 6)),
            .init(id: "order-5", offerID: "kombucha", code: "456789", customerAr: "خالد عبدالله", customerEn: "Khalid Abdullah", purchasedAt: Self.date(25), expiresAt: Self.date(1, month: 6)),
            .init(id: "order-6", offerID: "latte", code: "567890", customerAr: "ريم محمد", customerEn: "Reem Mohammed", purchasedAt: Self.date(25), expiresAt: Self.date(1, month: 6)),
            .init(id: "order-expired", offerID: "mojito", code: "111111", customerAr: "عمر أحمد", customerEn: "Omar Ahmed", purchasedAt: Self.date(20), expiresAt: Self.date(24))
        ] }
}
#endif

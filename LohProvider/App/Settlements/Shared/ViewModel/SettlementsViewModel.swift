import Foundation
import Combine

@MainActor
final class MerchantSettlementsViewModel: ObservableObject {
    @Published private(set) var receiptPage: MerchantReceiptPage?
    @Published private(set) var detail: MerchantSettlementDetail?
    @Published private(set) var detailError: APIError?
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: APIError?
    let previewReceipts: [MerchantSettlement]
    private let responseHandler: ResponseHandler?
    private let token: () -> String?
    private var generation = UUID()
    private var detailGeneration = UUID()
    private var loadedDetailID: String?
    private var loadedDetailLanguage: String?
    private var loadedToken: String?

    init(responseHandler: ResponseHandler, token: @escaping () -> String?) {
        self.responseHandler = responseHandler
        self.token = token
        previewReceipts = []
    }

    #if DEBUG
    private init() {
        responseHandler = nil
        token = { nil }
        previewReceipts = MerchantSettlement.samples
    }
    static func preview() -> MerchantSettlementsViewModel { .init() }
    #endif

    func receipt(id: String) -> MerchantReceipt? {
        receiptPage?.receipts.first { String($0.id) == id }
    }

    func loadDetails(id: String) async {
        guard let responseHandler else { return }
        let requestToken = token()
        guard let requestToken, !requestToken.isEmpty, receipt(id: id) != nil else {
            detail = nil; detailError = .invalidResponse; return
        }
        let requestLanguage = AppLanguageManager.shared.apiLanguage
        let requestGeneration = UUID()
        detailGeneration = requestGeneration
        if loadedDetailID != id || loadedDetailLanguage != requestLanguage { detail = nil }
        loadedDetailID = id
        loadedDetailLanguage = requestLanguage
        detailError = nil
        isLoadingDetail = true
        defer {
            if detailGeneration == requestGeneration { isLoadingDetail = false }
        }
        do {
            let response: MerchantSettlementDetail = try await responseHandler.data(
                from: SettlementEndpoints.details(id: id, token: requestToken),
                language: requestLanguage)
            try Task.checkCancellation()
            guard detailGeneration == requestGeneration, token() == requestToken else { return }
            guard let receiptID = Int(id), response.receipts.contains(where: { $0.id == receiptID }) else {
                throw APIError.invalidResponse
            }
            detail = response
        } catch {
            guard detailGeneration == requestGeneration, token() == requestToken,
                  !Task.isCancelled, !(error is CancellationError) else { return }
            detailError = APIError.map(error)
        }
    }

    func reload() async {
        guard let responseHandler else { return }
        let generation = UUID()
        self.generation = generation
        let requestToken = token()
        if loadedToken != requestToken {
            receiptPage = nil
            detail = nil; detailError = nil; loadedDetailID = nil; loadedDetailLanguage = nil
            detailGeneration = UUID()
        }
        loadedToken = requestToken
        error = nil
        isLoading = true
        defer {
            if self.generation == generation {
                isLoading = false
                if token() != requestToken {
                    receiptPage = nil; error = nil; loadedToken = nil
                }
            }
        }
        do {
            try Task.checkCancellation()
            guard let requestToken, !requestToken.isEmpty else { throw APIError.unauthenticated(nil) }
            let response: MerchantReceiptPage = try await responseHandler.data(
                from: SettlementEndpoints.receipts(token: requestToken),
                language: AppLanguageManager.shared.apiLanguage)
            try Task.checkCancellation()
            guard self.generation == generation, token() == requestToken else { return }
            receiptPage = response
        } catch {
            guard self.generation == generation, token() == requestToken, !Task.isCancelled,
                  !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            if (error as? APIError)?.invalidatesSession == true { receiptPage = nil }
            self.error = APIError.map(error)
        }
    }
}

import Foundation

struct SettlementEndpoints {
    private init() {}
}

extension SettlementEndpoints {
    static func receipts(token: String) -> Endpoint<APIEnvelope<MerchantReceiptPage>> {
        return Endpoint(path: "vendor/my-receipts", headerType: .authorized(token: token))
    }

    static func details(id: String, token: String) -> Endpoint<APIEnvelope<MerchantSettlementDetail>> {
        return Endpoint(path: "vendor/settelment-details/" + id, headerType: .authorized(token: token))
    }
}

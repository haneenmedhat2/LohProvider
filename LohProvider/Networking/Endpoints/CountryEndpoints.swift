import Foundation

struct CountryEndpoints {
    private init() {}
}

extension CountryEndpoints {
    static func list() -> Endpoint<APIEnvelope<[MerchantCountry]>> {
        return Endpoint(path: "countries")
    }
}

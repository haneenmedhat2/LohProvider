import Foundation

struct MerchantCountry: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let countryCode: String
    let image: URL?
    private let englishName: String?
    private let arabicName: String?

    private enum CodingKeys: String, CodingKey { case id, name, countryCode = "country_code", image }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? values.decode(UInt64.self, forKey: .id) { id = String(number) }
        else { id = try values.decode(String.self, forKey: .id) }
        name = try values.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)
        if let code = try? values.decode(String.self, forKey: .countryCode) { countryCode = code }
        else { countryCode = String(try values.decode(UInt64.self, forKey: .countryCode)) }
        let imageString = try values.decodeIfPresent(String.self, forKey: .image)
        if let imageString, let url = URL(string: imageString), url.scheme?.lowercased() == "https", url.host != nil {
            image = url
        } else {
            image = nil
        }
        englishName = nil
        arabicName = nil
        guard !id.isEmpty, !name.isEmpty,
              !countryCode.isEmpty, countryCode.count <= 4,
              countryCode.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw APIError.invalidResponse
        }
    }

    private init(id: String, name: String, countryCode: String, englishName: String, arabicName: String) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        image = nil
        self.englishName = englishName
        self.arabicName = arabicName
    }

    var dialCode: String { "+" + countryCode }

    func displayName(arabic: Bool) -> String {
        (arabic ? arabicName : englishName) ?? name
    }

    func acceptsNationalNumber(_ digits: String) -> Bool {
        guard digits.count == MerchantPhoneInput.maxDigits else { return false }
        switch countryCode {
        case "966", "971": return digits.hasPrefix("5")
        default: return true
        }
    }

    static let fallback: [MerchantCountry] = [
        .init(id: "1", name: "السعودية", countryCode: "966", englishName: "Saudi Arabia", arabicName: "السعودية"),
        .init(id: "2", name: "الإمارات", countryCode: "971", englishName: "United Arab Emirates", arabicName: "الإمارات"),
        .init(id: "3", name: "الكويت", countryCode: "965", englishName: "Kuwait", arabicName: "الكويت"),
        .init(id: "4", name: "البحرين", countryCode: "973", englishName: "Bahrain", arabicName: "البحرين"),
        .init(id: "5", name: "قطر", countryCode: "974", englishName: "Qatar", arabicName: "قطر"),
        .init(id: "6", name: "عُمان", countryCode: "968", englishName: "Oman", arabicName: "عُمان")
    ]
}

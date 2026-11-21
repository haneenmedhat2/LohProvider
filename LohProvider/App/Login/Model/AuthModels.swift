import Foundation

struct MerchantLoginToken: Decodable {
    let token: String
}

struct MerchantProfile: Codable, Equatable {
    let id: String
    let name: String?
    let phone: String?
    let email: String?
    let image: URL?

    enum CodingKeys: String, CodingKey { case id, name, storeName = "store_name", phone, fullPhone = "full_phone", email, image }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let integer = try? values.decode(Int.self, forKey: .id) { id = String(integer) }
        else { id = try values.decode(String.self, forKey: .id) }
        guard !id.isEmpty else { throw APIError.invalidResponse }
        name = try values.decodeIfPresent(String.self, forKey: .storeName) ?? values.decodeIfPresent(String.self, forKey: .name)
        phone = try values.decodeIfPresent(String.self, forKey: .fullPhone) ?? values.decodeIfPresent(String.self, forKey: .phone)
        email = try values.decodeIfPresent(String.self, forKey: .email)
        image = (try values.decodeIfPresent(String.self, forKey: .image)).flatMap(URL.init(string:))
    }

    init(id: String, name: String?, phone: String?, email: String?, image: URL? = nil) {
        self.id = id; self.name = name; self.phone = phone; self.email = email; self.image = image
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encodeIfPresent(name, forKey: .name)
        try values.encodeIfPresent(phone, forKey: .phone)
        try values.encodeIfPresent(email, forKey: .email)
        try values.encodeIfPresent(image?.absoluteString, forKey: .image)
    }
}

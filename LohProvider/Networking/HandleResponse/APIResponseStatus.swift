import Foundation

struct APIResponseStatus: Decodable {
    let key: String?
    let msg: String?
    let message: String?
    let errors: [String: [String]]?

    private enum CodingKeys: String, CodingKey { case key, msg, message, errors }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        key = try values.decodeIfPresent(String.self, forKey: .key)
        msg = try values.decodeIfPresent(String.self, forKey: .msg)
        message = try values.decodeIfPresent(String.self, forKey: .message)
        if let lists = try? values.decode([String: [String]].self, forKey: .errors) {
            errors = lists
        } else if let strings = try? values.decode([String: String].self, forKey: .errors) {
            errors = strings.mapValues { [$0] }
        } else {
            errors = nil
        }
    }

    var explanation: String? {
        msg ?? message ?? errors?.sorted(by: { $0.key < $1.key }).first?.value.first
    }
}


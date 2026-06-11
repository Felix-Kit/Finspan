import Foundation

struct RulesetVersion: Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static let baseGameV1 = RulesetVersion("base-game-v1")

    private enum CodingKeys: String, CodingKey {
        case rawValue
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let rawValue = try? singleValue.decode(String.self) {
            self.rawValue = rawValue
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawValue = try container.decode(String.self, forKey: .rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
    }
}

import Foundation

struct RulesetVersion: Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static let baseGameV1 = RulesetVersion("base-game-v1")
}

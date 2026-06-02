import Foundation

struct Player: Identifiable, Codable, Equatable, Sendable {
    let id: PlayerID
    var name: String
}

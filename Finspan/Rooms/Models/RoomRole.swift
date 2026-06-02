import Foundation

enum RoomRole: String, Codable, Equatable, Sendable {
    case host
    case player
    case spectator
}

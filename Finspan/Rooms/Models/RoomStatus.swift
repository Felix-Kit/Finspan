import Foundation

enum RoomStatus: String, Codable, Equatable, Sendable {
    case waiting
    case configuring
    case inProgress
    case paused
    case finished
    case closed
}

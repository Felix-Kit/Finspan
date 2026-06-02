import Foundation

struct AuthoritativeContext: Equatable, Sendable {
    let roomId: RoomID
    let nextSequenceNumber: EventID
    let timestamp: Date
    let randomSeed: Int
    let actorPlayerId: PlayerID
}

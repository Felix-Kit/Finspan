import Foundation

struct RoomSnapshot: Equatable {
    var id: RoomID
    var players: [RoomPlayer]
    var state: GameState
    var events: [EventEnvelope]

    static let empty = RoomSnapshot(id: "local-room", players: [], state: .empty, events: [])
}

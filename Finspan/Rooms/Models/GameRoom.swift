import Foundation

struct GameRoom: Identifiable, Codable, Equatable, Sendable {
    let roomId: RoomID
    var roomCode: String
    var hostPlayerId: PlayerID
    var status: RoomStatus
    var players: [RoomPlayer]
    var gameConfig: GameConfig
    var currentSequence: EventID
    var createdAt: Date
    var updatedAt: Date

    var id: RoomID { roomId }

    init(
        roomId: RoomID,
        roomCode: String,
        hostPlayerId: PlayerID,
        status: RoomStatus = .waiting,
        players: [RoomPlayer],
        gameConfig: GameConfig,
        currentSequence: EventID = 0,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.roomId = roomId
        self.roomCode = roomCode
        self.hostPlayerId = hostPlayerId
        self.status = status
        self.players = players
        self.gameConfig = gameConfig
        self.currentSequence = currentSequence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

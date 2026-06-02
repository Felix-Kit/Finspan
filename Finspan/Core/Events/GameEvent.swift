import Foundation

struct GameEvent: Codable, Equatable, Sendable {
    let sequenceNumber: EventID
    let roomId: RoomID
    let timestamp: Date
    let payload: GameEventPayload

    init(
        sequenceNumber: EventID,
        roomId: RoomID,
        timestamp: Date,
        payload: GameEventPayload
    ) {
        self.sequenceNumber = sequenceNumber
        self.roomId = roomId
        self.timestamp = timestamp
        self.payload = payload
    }
}

enum GameEventPayload: Codable, Equatable, Sendable {
    case roomCreated(RoomCreatedEvent)
    case playerJoined(PlayerJoinedEvent)
    case playerLeft(PlayerLeftEvent)
    case playerReadyChanged(PlayerReadyChangedEvent)
    case seatChanged(SeatChangedEvent)
    case colorChanged(ColorChangedEvent)
    case gameStarted(GameStartedEvent)
    case fishPlayed(FishPlayedEvent)
    case diverMoved(DiverMovedEvent)
    case abilityOptionChosen(AbilityOptionChosenEvent)
    case turnEnded(TurnEndedEvent)
    case weekEnded(WeekEndedEvent)
    case gameEnded(GameEndedEvent)
    case snapshotCreated(SnapshotCreatedEvent)
}

struct RoomCreatedEvent: Codable, Equatable, Sendable {
    var roomCode: String
    var hostPlayerId: PlayerID
    var hostDisplayName: String
    var gameConfig: GameConfig
}

struct PlayerJoinedEvent: Codable, Equatable, Sendable {
    var player: RoomPlayer
}

struct PlayerLeftEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
}

struct PlayerReadyChangedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var isReady: Bool
}

struct SeatChangedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var seatIndex: SeatIndex
}

struct ColorChangedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var color: PlayerColor
}

struct GameStartedEvent: Codable, Equatable, Sendable {
    var startingPlayerId: PlayerID
    var randomSeed: Int
}

struct FishPlayedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var cardId: CardID
}

struct DiverMovedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var destination: String
}

struct AbilityOptionChosenEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var optionId: AbilityOptionID
}

struct TurnEndedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var nextPlayerId: PlayerID?
}

struct WeekEndedEvent: Codable, Equatable, Sendable {
    var weekNumber: Int
}

struct GameEndedEvent: Codable, Equatable, Sendable {
    var reason: String
}

struct SnapshotCreatedEvent: Codable, Equatable, Sendable {
    var snapshotSequenceNumber: EventID
}

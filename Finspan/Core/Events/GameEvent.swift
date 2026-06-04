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
    case setupCompleted(SetupCompletedEvent)
    case fishPlayed(FishPlayedEvent)
    case diverMoved(DiverMovedEvent)
    case pendingChoiceCreated(PendingChoice)
    case pendingChoiceResolved(PendingChoiceResolvedEvent)
    case abilityOptionChosen(AbilityOptionChosenEvent)
    case turnAdvanced(TurnAdvancedEvent)
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

struct SetupCompletedEvent: Codable, Equatable, Sendable {
    var setup: GameSetup
}

struct FishPlayedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var cardId: CardID
    var targetSlot: OceanSlotAddress
    var payment: PlayFishPayment
    var nextActivePlayerId: PlayerID?
}

struct DiverMovedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var diveSite: DiveActionSite
    var bottomBonusAvailable: Bool
    var bottomBonusClaimed: Bool
    var nextActivePlayerId: PlayerID?
}

struct PendingChoiceResolvedEvent: Codable, Equatable, Sendable {
    var choiceId: PendingChoiceID
    var playerId: PlayerID
    var resolution: PendingChoiceResolution
    var appliedEffects: [PendingChoiceAppliedEffect]
}

struct AbilityOptionChosenEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var optionId: AbilityOptionID
}

struct TurnAdvancedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var nextPlayerId: PlayerID?
}

struct TurnEndedEvent: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var nextPlayerId: PlayerID?
}

struct WeekEndedEvent: Codable, Equatable, Sendable {
    var endedWeek: Int
    var nextWeek: Int?
    var previousFirstPlayerId: PlayerID?
    var nextFirstPlayerId: PlayerID?
    var nextActivePlayerId: PlayerID?
    var isGameEndTriggered: Bool
    var achievementResults: [WeeklyAchievementResult]

    var weekNumber: Int {
        endedWeek
    }

    init(
        endedWeek: Int,
        nextWeek: Int?,
        previousFirstPlayerId: PlayerID?,
        nextFirstPlayerId: PlayerID?,
        nextActivePlayerId: PlayerID?,
        isGameEndTriggered: Bool,
        achievementResults: [WeeklyAchievementResult] = []
    ) {
        self.endedWeek = endedWeek
        self.nextWeek = nextWeek
        self.previousFirstPlayerId = previousFirstPlayerId
        self.nextFirstPlayerId = nextFirstPlayerId
        self.nextActivePlayerId = nextActivePlayerId
        self.isGameEndTriggered = isGameEndTriggered
        self.achievementResults = achievementResults
    }

    init(weekNumber: Int) {
        self.init(
            endedWeek: weekNumber,
            nextWeek: weekNumber + 1,
            previousFirstPlayerId: nil,
            nextFirstPlayerId: nil,
            nextActivePlayerId: nil,
            isGameEndTriggered: false,
            achievementResults: []
        )
    }
}

struct GameEndedEvent: Codable, Equatable, Sendable {
    var reason: String
}

struct SnapshotCreatedEvent: Codable, Equatable, Sendable {
    var snapshotSequenceNumber: EventID
}

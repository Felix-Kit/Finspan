import Foundation

enum GamePhase: String, Codable, Equatable, Sendable {
    case lobby
    case setup
    case playing
    case awaitingChoice
    case weekScoring
    case endGamePending
    case gameEnded
}

struct GameState: Codable, Equatable, Sendable {
    var roomId: RoomID?
    var players: [Player]
    var currentWeek: Int
    var currentTurnIndex: Int
    var activePlayerId: PlayerID?
    var firstPlayerId: PlayerID? = nil
    var phase: GamePhase
    var eventSequence: EventID
    var randomSeed: Int?
    var turnsCompletedThisWeek: Int
    var playerGameStates: [PlayerID: PlayerGameState]
    var deckState: DeckState
    var pendingChoices: [PendingChoiceID: PendingChoice] = [:]
    var activeDiveQueue: DiveResolutionQueue? = nil
    var weeklyGoals: [WeeklyGoalDefinition]? = nil
    var weeklyAchievementResults: [WeeklyAchievementResult] = []
    var activatedGameEndAbilitySourceIds: Set<String> = []
    var finalScoreResult: FinalScoreResult? = nil

    static let empty = GameState(
        roomId: nil,
        players: [],
        currentWeek: 0,
        currentTurnIndex: 0,
        activePlayerId: nil,
        firstPlayerId: nil,
        phase: .lobby,
        eventSequence: 0,
        randomSeed: nil,
        turnsCompletedThisWeek: 0,
        playerGameStates: [:],
        deckState: .empty,
        pendingChoices: [:],
        activeDiveQueue: nil,
        weeklyGoals: nil,
        weeklyAchievementResults: [],
        activatedGameEndAbilitySourceIds: [],
        finalScoreResult: nil
    )
}

struct GameEndAbilitySource: Identifiable, Codable, Equatable, Hashable, Sendable {
    var playerId: PlayerID
    var slotAddress: OceanSlotAddress
    var cardId: CardID
    var abilityId: AbilityID

    var id: String {
        [
            playerId,
            slotAddress.diveSite.rawValue,
            "\(slotAddress.rowIndex)",
            cardId,
            abilityId
        ].joined(separator: "|")
    }
}

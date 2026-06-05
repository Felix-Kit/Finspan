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
    var weeklyAchievementResults: [WeeklyAchievementResult] = []
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
        weeklyAchievementResults: [],
        finalScoreResult: nil
    )
}

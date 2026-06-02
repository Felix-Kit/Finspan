import Foundation

enum GamePhase: String, Codable, Equatable, Sendable {
    case lobby
    case setup
    case playing
    case awaitingChoice
    case weekScoring
    case gameEnded
}

struct GameState: Codable, Equatable, Sendable {
    var roomId: RoomID?
    var players: [Player]
    var currentWeek: Int
    var currentTurnIndex: Int
    var activePlayerId: PlayerID?
    var phase: GamePhase
    var eventSequence: EventID
    var randomSeed: Int?
    var turnsCompletedThisWeek: Int

    static let empty = GameState(
        roomId: nil,
        players: [],
        currentWeek: 0,
        currentTurnIndex: 0,
        activePlayerId: nil,
        phase: .lobby,
        eventSequence: 0,
        randomSeed: nil,
        turnsCompletedThisWeek: 0
    )
}

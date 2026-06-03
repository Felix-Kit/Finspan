import Foundation

enum DomainEventDraft: Equatable, Sendable {
    case roomCreated(RoomCreatedEvent)
    case playerJoined(PlayerJoinedEvent)
    case playerLeft(PlayerLeftEvent)
    case playerReadyChanged(PlayerReadyChangedEvent)
    case seatChanged(SeatChangedEvent)
    case colorChanged(ColorChangedEvent)
    case gameStarted(GameStartedDraft)
    case setupCompleted(SetupCompletedEvent)
    case fishPlayed(FishPlayedEvent)
    case diverMoved(DiverMovedEvent)
    case abilityOptionChosen(AbilityOptionChosenEvent)
    case turnEnded(TurnEndedEvent)
    case weekEnded(WeekEndedEvent)
    case gameEnded(GameEndedEvent)
    case snapshotCreated(SnapshotCreatedEvent)
}

struct GameStartedDraft: Equatable, Sendable {
    var startingPlayerId: PlayerID
}

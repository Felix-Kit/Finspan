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
    case pendingChoiceCreated(PendingChoice)
    case pendingChoiceResolved(PendingChoiceResolvedEvent)
    case gameEndAbilityActivated(GameEndAbilityActivatedEvent)
    case abilityOptionChosen(AbilityOptionChosenEvent)
    case turnAdvanced(TurnAdvancedEvent)
    case turnEnded(TurnEndedEvent)
    case weekEnded(WeekEndedEvent)
    case gameEnded(GameEndedEvent)
    case snapshotCreated(SnapshotCreatedEvent)
}

struct GameStartedDraft: Equatable, Sendable {
    var startingPlayerId: PlayerID
}

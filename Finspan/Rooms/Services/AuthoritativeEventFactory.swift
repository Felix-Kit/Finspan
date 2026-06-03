import Foundation

struct AuthoritativeEventFactory {
    private(set) var nextSequenceNumber: EventID
    private var roomId: RoomID
    private var randomSeed: Int
    private let timestampProvider: () -> Date

    init(
        roomId: RoomID,
        nextSequenceNumber: EventID = 1,
        randomSeed: Int,
        timestampProvider: @escaping () -> Date = Date.init
    ) {
        self.roomId = roomId
        self.nextSequenceNumber = nextSequenceNumber
        self.randomSeed = randomSeed
        self.timestampProvider = timestampProvider
    }

    mutating func updateRandomSeed(_ randomSeed: Int) {
        self.randomSeed = randomSeed
    }

    mutating func updateRoomId(_ roomId: RoomID) {
        self.roomId = roomId
    }

    mutating func makeEvents(
        from drafts: [DomainEventDraft],
        actorPlayerId: PlayerID
    ) -> [GameEvent] {
        drafts.map { draft in
            let context = AuthoritativeContext(
                roomId: roomId,
                nextSequenceNumber: nextSequenceNumber,
                timestamp: timestampProvider(),
                randomSeed: randomSeed,
                actorPlayerId: actorPlayerId
            )
            nextSequenceNumber += 1
            return makeEvent(from: draft, context: context)
        }
    }

    private func makeEvent(from draft: DomainEventDraft, context: AuthoritativeContext) -> GameEvent {
        GameEvent(
            sequenceNumber: context.nextSequenceNumber,
            roomId: context.roomId,
            timestamp: context.timestamp,
            payload: makePayload(from: draft, context: context)
        )
    }

    private func makePayload(
        from draft: DomainEventDraft,
        context: AuthoritativeContext
    ) -> GameEventPayload {
        switch draft {
        case let .roomCreated(payload):
            return .roomCreated(payload)
        case let .playerJoined(payload):
            return .playerJoined(payload)
        case let .playerLeft(payload):
            return .playerLeft(payload)
        case let .playerReadyChanged(payload):
            return .playerReadyChanged(payload)
        case let .seatChanged(payload):
            return .seatChanged(payload)
        case let .colorChanged(payload):
            return .colorChanged(payload)
        case let .gameStarted(payload):
            return .gameStarted(
                GameStartedEvent(
                    startingPlayerId: payload.startingPlayerId,
                    randomSeed: context.randomSeed
                )
            )
        case let .setupCompleted(payload):
            return .setupCompleted(payload)
        case let .fishPlayed(payload):
            return .fishPlayed(payload)
        case let .diverMoved(payload):
            return .diverMoved(payload)
        case var .pendingChoiceCreated(payload):
            if payload.createdAtSequence <= 0 {
                payload.createdAtSequence = context.nextSequenceNumber
            }
            return .pendingChoiceCreated(payload)
        case let .pendingChoiceResolved(payload):
            return .pendingChoiceResolved(payload)
        case let .abilityOptionChosen(payload):
            return .abilityOptionChosen(payload)
        case let .turnEnded(payload):
            return .turnEnded(payload)
        case let .weekEnded(payload):
            return .weekEnded(payload)
        case let .gameEnded(payload):
            return .gameEnded(payload)
        case let .snapshotCreated(payload):
            return .snapshotCreated(payload)
        }
    }
}

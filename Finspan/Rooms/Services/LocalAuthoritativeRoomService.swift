import Foundation

final class LocalAuthoritativeRoomService: RoomService {
    private let engine: GameEngine
    private let reducer: EventReducer
    private let setupBuilder: DeterministicSetupBuilder
    private var eventFactory: AuthoritativeEventFactory
    private let randomSeedProvider: () -> Int
    private var eventContinuations: [AsyncStream<GameEvent>.Continuation] = []

    private(set) var gameRoom: GameRoom?
    private(set) var gameState: GameState
    private(set) var snapshot: RoomSnapshot
    private(set) var eventLog: [GameEvent]

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in
            eventContinuations.append(continuation)
        }
    }

    init(
        engine: GameEngine = GameEngine(),
        reducer: EventReducer = EventReducer(),
        setupBuilder: DeterministicSetupBuilder = DeterministicSetupBuilder(),
        snapshot: RoomSnapshot = .empty,
        roomId: RoomID = RoomSnapshot.empty.id,
        randomSeed: Int = 0,
        timestampProvider: @escaping () -> Date = Date.init,
        randomSeedProvider: @escaping () -> Int = { Int.random(in: 1...Int.max) }
    ) {
        self.engine = engine
        self.reducer = reducer
        self.setupBuilder = setupBuilder
        self.gameRoom = nil
        self.gameState = snapshot.state
        self.snapshot = snapshot
        self.eventLog = snapshot.events.map(\.event)
        self.randomSeedProvider = randomSeedProvider
        self.eventFactory = AuthoritativeEventFactory(
            roomId: roomId,
            nextSequenceNumber: snapshot.state.eventSequence + 1,
            randomSeed: randomSeed,
            timestampProvider: timestampProvider
        )
    }

    @discardableResult
    func submit(_ command: PlayerCommand) throws -> [GameEvent] {
        try validateRoomCommand(command)
        let engineDrafts = try engine.makeEventDrafts(for: command, in: gameState)
        let randomSeed = prepareAuthoritativeFields(for: command)
        let drafts = try makeAuthoritativeDrafts(
            for: command,
            engineDrafts: engineDrafts,
            randomSeed: randomSeed
        )
        let events = eventFactory.makeEvents(
            from: drafts,
            actorPlayerId: command.playerId
        )

        for event in events {
            applyRoomEvent(event)
            let nextState = reducer.reduce(gameState, event: event)
            let envelope = EventEnvelope(event: event)
            gameState = nextState
            snapshot = RoomSnapshot(
                id: event.roomId,
                players: gameRoom?.players ?? snapshot.players,
                state: nextState,
                events: snapshot.events + [envelope]
            )
            eventLog.append(event)
            publish(event)
        }

        return events
    }

    private func validateRoomCommand(_ command: PlayerCommand) throws {
        switch command.payload {
        case .createRoom:
            if gameRoom != nil {
                throw RoomServiceError.roomAlreadyExists
            }
        case .joinRoom:
            let room = try requireRoom(for: command)
            if room.status != .waiting && room.status != .configuring {
                throw RoomServiceError.cannotJoinStartedGame
            }
            if room.players.contains(where: { $0.playerId == command.playerId }) {
                throw RoomServiceError.playerAlreadyJoined(command.playerId)
            }
            if room.players.filter({ $0.role != .spectator }).count >= room.gameConfig.playerCount {
                throw RoomServiceError.roomIsFull
            }
        case .leaveRoom:
            let room = try requireRoom(for: command)
            if !room.players.contains(where: { $0.playerId == command.playerId }) {
                throw RoomServiceError.playerNotFound(command.playerId)
            }
        case .setReady:
            let room = try requireRoom(for: command)
            if !room.players.contains(where: { $0.playerId == command.playerId }) {
                throw RoomServiceError.playerNotFound(command.playerId)
            }
        case .startGame:
            let room = try requireRoom(for: command)
            if room.status == .inProgress {
                throw RoomServiceError.gameAlreadyStarted
            }
            if room.hostPlayerId != command.playerId {
                throw RoomServiceError.hostOnlyAction
            }
            for player in room.players where player.role != .spectator && !player.isReady {
                throw RoomServiceError.playerNotReady(player.playerId)
            }
        case .endTurn:
            let room = try requireRoom(for: command)
            if room.status != .inProgress {
                throw RoomServiceError.gameNotStarted
            }
            if !room.players.contains(where: { $0.playerId == command.playerId }) {
                throw RoomServiceError.playerNotFound(command.playerId)
            }
        case .chooseSeat,
             .chooseColor,
             .playFish,
             .dive,
             .resolvePendingChoice,
             .chooseAbilityOption:
            let room = try requireRoom(for: command)
            if !room.players.contains(where: { $0.playerId == command.playerId }) {
                throw RoomServiceError.playerNotFound(command.playerId)
            }
        }
    }

    private func requireRoom(for command: PlayerCommand) throws -> GameRoom {
        guard let room = gameRoom else {
            throw RoomServiceError.roomNotFound
        }
        if room.roomId != command.roomId {
            throw RoomServiceError.roomIdMismatch(expected: room.roomId, actual: command.roomId)
        }
        return room
    }

    private func prepareAuthoritativeFields(for command: PlayerCommand) -> Int? {
        if case .createRoom = command.payload, gameRoom == nil {
            eventFactory.updateRoomId(command.roomId)
        }

        if case .startGame = command.payload {
            let randomSeed = randomSeedProvider()
            eventFactory.updateRandomSeed(randomSeed)
            return randomSeed
        }

        return nil
    }

    private func makeAuthoritativeDrafts(
        for command: PlayerCommand,
        engineDrafts: [DomainEventDraft],
        randomSeed: Int?
    ) throws -> [DomainEventDraft] {
        guard case .startGame = command.payload else {
            return engineDrafts
        }

        guard let room = gameRoom, let randomSeed else {
            throw RoomServiceError.roomNotFound
        }

        let setup = try setupBuilder.makeSetup(
            players: room.players,
            randomSeed: randomSeed
        )

        return [
            .gameStarted(GameStartedDraft(startingPlayerId: setup.startingPlayerId)),
            .setupCompleted(SetupCompletedEvent(setup: setup))
        ]
    }

    private func applyRoomEvent(_ event: GameEvent) {
        switch event.payload {
        case let .roomCreated(payload):
            let host = RoomPlayer(
                playerId: payload.hostPlayerId,
                displayName: payload.hostDisplayName,
                role: .host
            )
            gameRoom = GameRoom(
                roomId: event.roomId,
                roomCode: payload.roomCode,
                hostPlayerId: payload.hostPlayerId,
                status: .waiting,
                players: [host],
                gameConfig: payload.gameConfig,
                currentSequence: event.sequenceNumber,
                createdAt: event.timestamp,
                updatedAt: event.timestamp
            )
        case let .playerJoined(payload):
            updateRoom(event) { room in
                room.players.append(payload.player)
            }
        case let .playerLeft(payload):
            updateRoom(event) { room in
                room.players.removeAll { $0.playerId == payload.playerId }
            }
        case let .playerReadyChanged(payload):
            updateRoom(event) { room in
                guard let index = room.players.firstIndex(where: { $0.playerId == payload.playerId }) else {
                    return
                }
                room.players[index].isReady = payload.isReady
            }
        case let .seatChanged(payload):
            updateRoom(event) { room in
                guard let index = room.players.firstIndex(where: { $0.playerId == payload.playerId }) else {
                    return
                }
                room.players[index].seatIndex = payload.seatIndex
            }
        case let .colorChanged(payload):
            updateRoom(event) { room in
                guard let index = room.players.firstIndex(where: { $0.playerId == payload.playerId }) else {
                    return
                }
                room.players[index].color = payload.color
            }
        case let .gameStarted(payload):
            updateRoom(event) { room in
                room.status = .inProgress
                room.gameConfig.randomSeed = payload.randomSeed
            }
        case .setupCompleted:
            updateRoom(event) { _ in }
        case .turnAdvanced:
            updateRoom(event) { _ in }
        case .turnEnded:
            updateRoom(event) { _ in }
        case .fishPlayed,
             .diverMoved,
             .pendingChoiceCreated,
             .pendingChoiceResolved,
             .abilityOptionChosen,
             .weekEnded,
             .gameEnded,
             .snapshotCreated:
            updateRoom(event) { _ in }
        }
    }

    private func updateRoom(_ event: GameEvent, mutate: (inout GameRoom) -> Void) {
        guard var room = gameRoom else {
            return
        }
        mutate(&room)
        room.currentSequence = event.sequenceNumber
        room.updatedAt = event.timestamp
        gameRoom = room
    }

    private func publish(_ event: GameEvent) {
        eventContinuations.forEach { continuation in
            continuation.yield(event)
        }
    }
}

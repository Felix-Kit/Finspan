import XCTest
@testable import Finspan

final class LocalAuthoritativeRoomServiceTests: XCTestCase {

    func testSubmitAppliesEventsToRoomSnapshot() throws {
        let service = LocalAuthoritativeRoomService(
            roomId: "room-1",
            randomSeed: 42,
            timestampProvider: { Date(timeIntervalSince1970: 1_000) }
        )

        try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 1, randomSeed: 42)
            )
        )

        XCTAssertEqual(service.snapshot.state.players.map(\.id), ["player-1"])
        XCTAssertEqual(service.snapshot.events.count, 1)
        XCTAssertEqual(service.eventLog.count, 1)
        XCTAssertEqual(service.snapshot.events.first?.sequence, 1)
    }

    func testSubmitAllocatesIncreasingSequenceNumbers() throws {
        let service = LocalAuthoritativeRoomService(
            roomId: "room-1",
            randomSeed: 42,
            timestampProvider: { Date(timeIntervalSince1970: 1_000) }
        )

        let firstEvents = try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 2, randomSeed: 42)
            )
        )
        let secondEvents = try service.submit(
            PlayerCommand(
                commandId: "command-2",
                playerId: "player-2",
                roomId: "room-1",
                payload: .joinRoom(JoinRoomCommand(displayName: "Player 2"))
            )
        )

        XCTAssertEqual(firstEvents.map(\.sequenceNumber), [1])
        XCTAssertEqual(secondEvents.map(\.sequenceNumber), [2])
        XCTAssertEqual(service.eventLog.map(\.sequenceNumber), [1, 2])
        XCTAssertEqual(service.snapshot.state.eventSequence, 2)
    }

    func testStartGameRandomSeedComesFromAuthoritativeService() throws {
        let service = LocalAuthoritativeRoomService(
            roomId: "room-1",
            timestampProvider: { Date(timeIntervalSince1970: 1_000) },
            randomSeedProvider: { 99 }
        )

        try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 1, randomSeed: 0)
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-2",
                playerId: "player-1",
                roomId: "room-1",
                payload: .setReady(SetReadyCommand(isReady: true))
            )
        )

        let events = try service.submit(
            PlayerCommand(
                commandId: "command-3",
                playerId: "player-1",
                roomId: "room-1",
                payload: .startGame(StartGameCommand())
            )
        )

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(
            events.first?.payload,
            .gameStarted(GameStartedEvent(startingPlayerId: "player-1", randomSeed: 99))
        )
        if case let .setupCompleted(payload) = events.last?.payload {
            XCTAssertEqual(payload.setup.randomSeed, 99)
            XCTAssertEqual(payload.setup.playerStates.first?.hand.count, 5)
        } else {
            XCTFail("Expected setupCompleted event.")
        }
        XCTAssertEqual(service.gameRoom?.status, .inProgress)
        XCTAssertEqual(service.gameRoom?.gameConfig.randomSeed, 99)
    }

    func testRoomLifecycleRejectsEndTurnWithoutMainAction() throws {
        let service = LocalAuthoritativeRoomService(
            timestampProvider: { Date(timeIntervalSince1970: 1_000) },
            randomSeedProvider: { 123 }
        )

        try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 2, randomSeed: 0)
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-2",
                playerId: "player-2",
                roomId: "room-1",
                payload: .joinRoom(JoinRoomCommand(displayName: "Player 2"))
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-3",
                playerId: "player-1",
                roomId: "room-1",
                payload: .setReady(SetReadyCommand(isReady: true))
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-4",
                playerId: "player-2",
                roomId: "room-1",
                payload: .setReady(SetReadyCommand(isReady: true))
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-5",
                playerId: "player-1",
                roomId: "room-1",
                payload: .startGame(StartGameCommand())
            )
        )
        let activePlayerId = try XCTUnwrap(service.gameState.activePlayerId)

        XCTAssertThrowsError(
            try service.submit(
                PlayerCommand(
                    commandId: "command-6",
                    playerId: activePlayerId,
                    roomId: "room-1",
                    payload: .endTurn(EndTurnCommand())
                )
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .passTurnNotAllowed)
        }

        XCTAssertEqual(service.gameRoom?.players.count, 2)
        XCTAssertEqual(service.gameRoom?.players.map(\.isReady), [true, true])
        XCTAssertEqual(service.gameRoom?.status, .inProgress)
        XCTAssertEqual(service.gameRoom?.currentSequence, 6)
        XCTAssertEqual(service.gameState.eventSequence, 6)
        XCTAssertEqual(service.eventLog.map(\.sequenceNumber), [1, 2, 3, 4, 5, 6])
    }

    func testRejectsNonHostStartGame() throws {
        let service = LocalAuthoritativeRoomService(
            roomId: "room-1",
            timestampProvider: { Date(timeIntervalSince1970: 1_000) },
            randomSeedProvider: { 123 }
        )

        try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 2, randomSeed: 0)
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-2",
                playerId: "player-2",
                roomId: "room-1",
                payload: .joinRoom(JoinRoomCommand(displayName: "Player 2"))
            )
        )

        XCTAssertThrowsError(
            try service.submit(
                PlayerCommand(
                    commandId: "command-3",
                    playerId: "player-2",
                    roomId: "room-1",
                    payload: .startGame(StartGameCommand())
                )
            )
        ) { error in
            XCTAssertEqual(error as? RoomServiceError, .hostOnlyAction)
        }
    }

    func testEventStreamPublishesSubmittedEvents() async throws {
        let service = LocalAuthoritativeRoomService(
            roomId: "room-1",
            timestampProvider: { Date(timeIntervalSince1970: 1_000) }
        )
        var iterator = service.eventStream.makeAsyncIterator()

        try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 1, randomSeed: 0)
            )
        )

        let event = await iterator.next()
        XCTAssertEqual(event?.sequenceNumber, 1)
        XCTAssertEqual(event?.payload, service.eventLog.first?.payload)
    }
}

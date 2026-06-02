import XCTest
@testable import Finspan

final class GameEngineTests: XCTestCase {
    private let roomId = "room-1"
    private let timestamp = Date(timeIntervalSince1970: 1_000)

    func testCreateRoomCommandEmitsDeterministicDraft() throws {
        let engine = GameEngine()

        let drafts = try engine.makeEventDrafts(
            for: .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 1, randomSeed: 42)
            ),
            in: .empty
        )

        XCTAssertEqual(
            drafts,
            [
                .roomCreated(
                    RoomCreatedEvent(
                        roomCode: "ABCD",
                        hostPlayerId: "player-1",
                        hostDisplayName: "Player 1",
                        gameConfig: GameConfig(playerCount: 1, randomSeed: 42)
                    )
                )
            ]
        )
    }

    func testGameEngineDoesNotDependOnDateOrSequenceNumber() throws {
        let engine = GameEngine()
        let command = PlayerCommand.createRoom(
            commandId: "command-1",
            playerId: "player-1",
            roomId: "room-1",
            roomCode: "ABCD",
            displayName: "Player 1",
            gameConfig: GameConfig(playerCount: 1, randomSeed: 42)
        )

        let firstDrafts = try engine.makeEventDrafts(for: command, in: .empty)
        let secondDrafts = try engine.makeEventDrafts(for: command, in: .empty)

        XCTAssertEqual(firstDrafts, secondDrafts)
    }

    func testStartGameInitializesMinimalGameState() {
        let engine = GameEngine()
        let state = startedState(engine: engine)

        XCTAssertEqual(state.roomId, roomId)
        XCTAssertEqual(state.phase, .playing)
        XCTAssertEqual(state.currentWeek, 1)
        XCTAssertEqual(state.currentTurnIndex, 0)
        XCTAssertEqual(state.activePlayerId, "player-1")
        XCTAssertEqual(state.randomSeed, 99)
        XCTAssertEqual(state.turnsCompletedThisWeek, 0)
    }

    func testEndTurnRotatesThroughMultiplePlayers() throws {
        let engine = GameEngine()
        var state = startedState(engine: engine)
        var factory = AuthoritativeEventFactory(
            roomId: roomId,
            nextSequenceNumber: 5,
            randomSeed: 99,
            timestampProvider: { self.timestamp }
        )

        state = try submitEndTurn(playerId: "player-1", state: state, engine: engine, factory: &factory)
        XCTAssertEqual(state.activePlayerId, "player-2")
        XCTAssertEqual(state.currentTurnIndex, 1)

        state = try submitEndTurn(playerId: "player-2", state: state, engine: engine, factory: &factory)
        XCTAssertEqual(state.activePlayerId, "player-3")
        XCTAssertEqual(state.currentTurnIndex, 2)

        state = try submitEndTurn(playerId: "player-3", state: state, engine: engine, factory: &factory)
        XCTAssertEqual(state.activePlayerId, "player-1")
        XCTAssertEqual(state.currentTurnIndex, 0)
    }

    func testSixTurnsAdvanceOneWeek() throws {
        let engine = GameEngine()
        var state = startedState(engine: engine)
        var factory = AuthoritativeEventFactory(
            roomId: roomId,
            nextSequenceNumber: 5,
            randomSeed: 99,
            timestampProvider: { self.timestamp }
        )

        for _ in 0..<6 {
            state = try submitEndTurn(
                playerId: try XCTUnwrap(state.activePlayerId),
                state: state,
                engine: engine,
                factory: &factory
            )
        }

        XCTAssertEqual(state.phase, .playing)
        XCTAssertEqual(state.currentWeek, 2)
        XCTAssertEqual(state.turnsCompletedThisWeek, 0)
        XCTAssertEqual(state.activePlayerId, "player-1")
    }

    func testFourWeeksEndGameAfterTwentyFourTurns() throws {
        let engine = GameEngine()
        var state = startedState(engine: engine)
        var factory = AuthoritativeEventFactory(
            roomId: roomId,
            nextSequenceNumber: 5,
            randomSeed: 99,
            timestampProvider: { self.timestamp }
        )

        for _ in 0..<24 {
            state = try submitEndTurn(
                playerId: try XCTUnwrap(state.activePlayerId),
                state: state,
                engine: engine,
                factory: &factory
            )
        }

        XCTAssertEqual(state.phase, .gameEnded)
        XCTAssertEqual(state.currentWeek, 4)
        XCTAssertNil(state.activePlayerId)
        XCTAssertEqual(state.turnsCompletedThisWeek, 0)
    }

    private func startedState(engine: GameEngine) -> GameState {
        [
            GameEvent(
                sequenceNumber: 1,
                roomId: roomId,
                timestamp: timestamp,
                payload: .roomCreated(
                    RoomCreatedEvent(
                        roomCode: "ABCD",
                        hostPlayerId: "player-1",
                        hostDisplayName: "Player 1",
                        gameConfig: GameConfig(playerCount: 3, randomSeed: 0)
                    )
                )
            ),
            GameEvent(
                sequenceNumber: 2,
                roomId: roomId,
                timestamp: timestamp,
                payload: .playerJoined(
                    PlayerJoinedEvent(
                        player: RoomPlayer(playerId: "player-2", displayName: "Player 2")
                    )
                )
            ),
            GameEvent(
                sequenceNumber: 3,
                roomId: roomId,
                timestamp: timestamp,
                payload: .playerJoined(
                    PlayerJoinedEvent(
                        player: RoomPlayer(playerId: "player-3", displayName: "Player 3")
                    )
                )
            ),
            GameEvent(
                sequenceNumber: 4,
                roomId: roomId,
                timestamp: timestamp,
                payload: .gameStarted(
                    GameStartedEvent(startingPlayerId: "player-1", randomSeed: 99)
                )
            )
        ].reduce(GameState.empty) { state, event in
            engine.reduce(state: state, event: event)
        }
    }

    private func submitEndTurn(
        playerId: PlayerID,
        state: GameState,
        engine: GameEngine,
        factory: inout AuthoritativeEventFactory
    ) throws -> GameState {
        let command = PlayerCommand(
            commandId: "end-turn-\(state.eventSequence)",
            playerId: playerId,
            roomId: roomId,
            payload: .endTurn(EndTurnCommand())
        )
        let drafts = try engine.makeEventDrafts(for: command, in: state)
        let events = factory.makeEvents(from: drafts, actorPlayerId: playerId)

        return events.reduce(state) { state, event in
            engine.reduce(state: state, event: event)
        }
    }
}

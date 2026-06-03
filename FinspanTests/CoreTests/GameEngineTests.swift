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

    func testPlayFishDraftIncludesTargetSlotAndPayment() throws {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .coast,
            zone: .sunlit,
            slotIndex: 0
        )
        let payment = PlayFishPayment(
            discardedCardIds: ["fish-6"],
            eggSources: [],
            youngSources: []
        )

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-1",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(
                    PlayFishCommand(
                        cardId: "fish-1",
                        targetSlot: targetSlot,
                        payment: payment
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(
            drafts,
            [
                .fishPlayed(
                    FishPlayedEvent(
                        playerId: "player-1",
                        cardId: "fish-1",
                        targetSlot: targetSlot,
                        payment: payment,
                        nextActivePlayerId: nil
                    )
                )
            ]
        )
    }

    func testFishPlayedReducerMovesCardToTargetSlotAndAppliesPayment() {
        let engine = GameEngine()
        var state = playFishState()
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .coast,
            zone: .sunlit,
            slotIndex: 0
        )
        let event = GameEvent(
            sequenceNumber: 10,
            roomId: roomId,
            timestamp: timestamp,
            payload: .fishPlayed(
                FishPlayedEvent(
                    playerId: "player-1",
                    cardId: "fish-2",
                    targetSlot: targetSlot,
                    payment: PlayFishPayment(
                        discardedCardIds: [],
                        eggSources: [targetSlot],
                        youngSources: []
                    ),
                    nextActivePlayerId: nil
                )
            )
        )

        state = engine.reduce(state: state, event: event)

        let playerState = state.playerGameStates["player-1"]
        XCTAssertEqual(playerState?.hand, ["fish-1", "fish-6"])
        XCTAssertEqual(playerState?.ocean.slots.first?.fishCardId, "fish-2")
        XCTAssertEqual(
            playerState?.ocean.slots.first?.resources,
            [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 1)
            ]
        )
        XCTAssertEqual(state.deckState.discardPile, [])
    }

    func testPlayFishRejectsInactivePlayer() {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(
            playerId: "player-2",
            diveSite: .coast,
            zone: .sunlit,
            slotIndex: 0
        )

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "play-fish-2",
                    playerId: "player-2",
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(
                            cardId: "fish-1",
                            targetSlot: targetSlot,
                            payment: .empty
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .inactivePlayer(expected: "player-1", actual: "player-2")
            )
        }
    }

    func testPlayFishRejectsMissingResourcePayment() {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .coast,
            zone: .sunlit,
            slotIndex: 0
        )

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "play-fish-3",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(
                            cardId: "fish-2",
                            targetSlot: targetSlot,
                            payment: .empty
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .paymentResourceCountMismatch(kind: .egg, expected: 1, actual: 0)
            )
        }
    }

    func testPlayFishAcceptsEggSourceFromDifferentSlotThanTarget() throws {
        let engine = GameEngine()
        let state = playFishStateWithResourcesInDifferentSlot()
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .coast,
            zone: .sunlit,
            slotIndex: 0
        )
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .reef,
            zone: .twilight,
            slotIndex: 0
        )

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-cross-slot-egg",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(
                    PlayFishCommand(
                        cardId: "fish-2",
                        targetSlot: targetSlot,
                        payment: PlayFishPayment(
                            discardedCardIds: [],
                            eggSources: [sourceSlot],
                            youngSources: []
                        )
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(
            drafts,
            [
                .fishPlayed(
                    FishPlayedEvent(
                        playerId: "player-1",
                        cardId: "fish-2",
                        targetSlot: targetSlot,
                        payment: PlayFishPayment(
                            discardedCardIds: [],
                            eggSources: [sourceSlot],
                            youngSources: []
                        ),
                        nextActivePlayerId: nil
                    )
                )
            ]
        )
    }

    func testFishPlayedReducerDeductsResourceFromPaymentSourceSlot() {
        let engine = GameEngine()
        var state = playFishStateWithResourcesInDifferentSlot()
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .coast,
            zone: .sunlit,
            slotIndex: 0
        )
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .reef,
            zone: .twilight,
            slotIndex: 0
        )

        state = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .fishPlayed(
                    FishPlayedEvent(
                        playerId: "player-1",
                        cardId: "fish-2",
                        targetSlot: targetSlot,
                        payment: PlayFishPayment(
                            discardedCardIds: [],
                            eggSources: [sourceSlot],
                            youngSources: []
                        ),
                        nextActivePlayerId: nil
                    )
                )
            )
        )

        let playerState = state.playerGameStates["player-1"]
        let target = playerState?.ocean.slots.first { $0.address == targetSlot }
        let source = playerState?.ocean.slots.first { $0.address == sourceSlot }

        XCTAssertEqual(target?.fishCardId, "fish-2")
        XCTAssertEqual(source?.resources.first(where: { $0.kind == .egg })?.amount, 1)
    }

    func testPlayFishAcceptsYoungSourceFromDifferentSlotThanTarget() throws {
        let engine = GameEngine()
        var state = playFishStateWithResourcesInDifferentSlot()
        state.playerGameStates["player-1"]?.hand = ["fish-3"]
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .coast,
            zone: .sunlit,
            slotIndex: 0
        )
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .reef,
            zone: .twilight,
            slotIndex: 0
        )

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-cross-slot-young",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(
                    PlayFishCommand(
                        cardId: "fish-3",
                        targetSlot: targetSlot,
                        payment: PlayFishPayment(
                            discardedCardIds: [],
                            eggSources: [],
                            youngSources: [sourceSlot]
                        )
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(
            drafts,
            [
                .fishPlayed(
                    FishPlayedEvent(
                        playerId: "player-1",
                        cardId: "fish-3",
                        targetSlot: targetSlot,
                        payment: PlayFishPayment(
                            discardedCardIds: [],
                            eggSources: [],
                            youngSources: [sourceSlot]
                        ),
                        nextActivePlayerId: nil
                    )
                )
            ]
        )
    }

    func testDiveRejectsInactivePlayer() {
        let engine = GameEngine()
        let state = playFishState()

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "dive-inactive",
                    playerId: "player-2",
                    roomId: roomId,
                    payload: .dive(DiveCommand(diveSite: .blue))
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .notActivePlayer(expected: "player-1", actual: "player-2")
            )
        }
    }

    func testDiveRejectsInvalidPhase() {
        let engine = GameEngine()
        var state = playFishState()
        state.phase = .lobby

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "dive-invalid-phase",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .dive(DiveCommand(diveSite: .blue))
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPhase(.lobby))
        }
    }

    func testDiveRejectsNoAvailableDiver() {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.availableDivers = 0

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "dive-no-diver",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .dive(DiveCommand(diveSite: .blue))
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .noAvailableDiver)
        }
    }

    func testDiveRejectsInvalidDiveSite() {
        let engine = GameEngine()
        let state = playFishState()
        let invalidDiveSite = DiveActionSite(rawValue: "red")

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "dive-invalid-site",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .dive(DiveCommand(diveSite: invalidDiveSite))
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidDiveSite(invalidDiveSite))
        }
    }

    func testDiveEmitsBottomBonusAndNextPlayerForFirstDiveSiteThisWeek() throws {
        let engine = GameEngine()
        let state = playFishState()

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-blue",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertEqual(
            drafts,
            [
                .diverMoved(
                    DiverMovedEvent(
                        playerId: "player-1",
                        diveSite: .blue,
                        bottomBonusAvailable: true,
                        bottomBonusClaimed: true,
                        nextActivePlayerId: "player-2"
                    )
                )
            ]
        )
    }

    func testDiveReducerConsumesDiverRecordsBottomBonusAndAdvancesActivePlayer() {
        let engine = GameEngine()
        var state = playFishState()

        state = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .diverMoved(
                    DiverMovedEvent(
                        playerId: "player-1",
                        diveSite: .blue,
                        bottomBonusAvailable: true,
                        bottomBonusClaimed: true,
                        nextActivePlayerId: "player-2"
                    )
                )
            )
        )

        let playerState = state.playerGameStates["player-1"]
        XCTAssertEqual(playerState?.availableDivers, 5)
        XCTAssertEqual(playerState?.usedDivers, 1)
        XCTAssertEqual(playerState?.diveSitesReachedBottomThisWeek, [.blue])
        XCTAssertEqual(state.activePlayerId, "player-2")
        XCTAssertEqual(state.currentTurnIndex, 1)
    }

    func testDiveSecondSameSiteThisWeekDoesNotMarkBottomBonus() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-blue-second",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertEqual(
            drafts,
            [
                .diverMoved(
                    DiverMovedEvent(
                        playerId: "player-1",
                        diveSite: .blue,
                        bottomBonusAvailable: false,
                        bottomBonusClaimed: false,
                        nextActivePlayerId: "player-2"
                    )
                )
            ]
        )
    }

    func testPendingChoiceCreatedReducerAddsChoiceToGameState() {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice()

        state = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceCreated(choice)
            )
        )

        XCTAssertEqual(state.pendingChoices[choice.choiceId], choice)
    }

    func testPendingChoiceResolvedReducerRemovesChoiceFromGameState() {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        state = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .skip,
                        appliedEffects: [.none]
                    )
                )
            )
        )

        XCTAssertNil(state.pendingChoices[choice.choiceId])
    }

    func testResolvePendingChoiceRejectsNonOwner() {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "resolve-pending-choice-wrong-player",
                    playerId: "player-2",
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: choice.choiceId,
                            resolution: .skip
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .pendingChoiceNotOwned(
                    choiceId: choice.choiceId,
                    expected: "player-1",
                    actual: "player-2"
                )
            )
        }
    }

    func testOptionalPendingChoiceCanBeSkipped() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(isOptional: true)
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "resolve-pending-choice-skip",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .skip
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(
            drafts,
            [
                .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .skip,
                        appliedEffects: [.none]
                    )
                )
            ]
        )
    }

    func testMissingPendingChoiceCannotBeResolved() {
        let engine = GameEngine()
        let state = playFishState()

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "resolve-pending-choice-missing",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: "missing-choice",
                            resolution: .skip
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .pendingChoiceNotFound("missing-choice"))
        }
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

    private func playFishState() -> GameState {
        GameState(
            roomId: roomId,
            players: [
                Player(id: "player-1", name: "Player 1"),
                Player(id: "player-2", name: "Player 2")
            ],
            currentWeek: 1,
            currentTurnIndex: 0,
            activePlayerId: "player-1",
            phase: .playing,
            eventSequence: 9,
            randomSeed: 99,
            turnsCompletedThisWeek: 0,
            playerGameStates: [
                "player-1": PlayerGameState(
                    playerId: "player-1",
                    hand: ["fish-1", "fish-2", "fish-6"],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: .baseGameInitial(for: "player-1")
                ),
                "player-2": PlayerGameState(
                    playerId: "player-2",
                    hand: ["fish-1", "fish-6"],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: .baseGameInitial(for: "player-2")
                )
            ],
            deckState: .empty
        )
    }

    private func playFishStateWithResourcesInDifferentSlot() -> GameState {
        var state = playFishState()
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .reef,
            zone: .twilight,
            slotIndex: 0
        )

        guard var playerState = state.playerGameStates["player-1"],
              let sourceIndex = playerState.ocean.slots.firstIndex(where: { $0.address == sourceSlot })
        else {
            return state
        }

        playerState.ocean.slots[sourceIndex].resources = [
            ResourceQuantity(kind: .egg, amount: 2),
            ResourceQuantity(kind: .young, amount: 1)
        ]
        state.playerGameStates["player-1"] = playerState
        return state
    }

    private func pendingChoice(isOptional: Bool = true) -> PendingChoice {
        PendingChoice(
            choiceId: "choice-1",
            playerId: "player-1",
            source: .diveBonus(.blue),
            kind: .bottomBonus,
            options: [],
            expectedInput: .none,
            isOptional: isOptional,
            createdAtSequence: 9
        )
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

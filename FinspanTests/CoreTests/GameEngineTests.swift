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

    func testEndTurnCommandCannotAdvanceWithoutMainAction() {
        let engine = GameEngine()
        let state = playFishState()

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "end-turn-not-allowed",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .endTurn(EndTurnCommand())
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .passTurnNotAllowed)
        }
    }

    func testPlayFishAutomaticallyAdvancesActivePlayer() throws {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .blue,
            rowIndex: 0
        )

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-auto-advance",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(
                    PlayFishCommand(
                        cardId: "fish-6",
                        targetSlot: targetSlot,
                        payment: PlayFishPayment.empty
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(drafts.last, .turnAdvanced(TurnAdvancedEvent(playerId: "player-1", nextPlayerId: "player-2")))
    }

    func testPlayFishTriggersWeekEndedWhenAllDiversAreUsed() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .blue,
            rowIndex: 0
        )

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-ending-week",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(
                    PlayFishCommand(
                        cardId: "fish-6",
                        targetSlot: targetSlot,
                        payment: PlayFishPayment.empty
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(
            drafts.last,
            .weekEnded(
                WeekEndedEvent(
                    endedWeek: 1,
                    nextWeek: 2,
                    previousFirstPlayerId: "player-1",
                    nextFirstPlayerId: "player-2",
                    nextActivePlayerId: "player-2",
                    isGameEndTriggered: false,
                    achievementResults: [
                        WeeklyAchievementResult(
                            week: 1,
                            kind: .eggsAndYoung,
                            playerId: "player-1",
                            quantity: 3,
                            points: 3
                        ),
                        WeeklyAchievementResult(
                            week: 1,
                            kind: .eggsAndYoung,
                            playerId: "player-2",
                            quantity: 3,
                            points: 3
                        )
                    ]
                )
            )
        )
    }

    func testEndTurnDoesNotTriggerWeekOrGameEnd() {
        let engine = GameEngine()
        var state = playFishState()
        state.currentWeek = 4
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "end-turn-no-game-end",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .endTurn(EndTurnCommand())
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .passTurnNotAllowed)
        }
    }

    func testActionDoesNotEndWeekWhenSomePlayerStillHasDivers() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 1
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-before-week-end",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertFalse(drafts.contains { draft in
            if case .weekEnded = draft {
                return true
            }
            return false
        })
        XCTAssertEqual(drafts.last, .turnAdvanced(TurnAdvancedEvent(playerId: "player-1", nextPlayerId: "player-2")))
    }

    func testConsumedFishDoesNotTriggerPrintedDiveBonus() throws {
        let engine = GameEngine()
        var state = playFishState()
        clearOceanContent(for: "player-1", in: &state)
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]
        setConsumedFish(
            [ConsumedFish(cardId: "consumed-blue-sunlit")],
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            in: &state
        )

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-consumed-only",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        guard case let .diverMoved(event) = drafts.first else {
            return XCTFail("Expected diver moved draft.")
        }
        XCTAssertNil(event.diveResolutionQueue)
    }

    func testActionEndsWeekWhenAllDiversUsedAndNoPendingChoices() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-ending-week",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertEqual(
            drafts.last,
            .weekEnded(
                WeekEndedEvent(
                    endedWeek: 1,
                    nextWeek: 2,
                    previousFirstPlayerId: "player-1",
                    nextFirstPlayerId: "player-2",
                    nextActivePlayerId: "player-2",
                    isGameEndTriggered: false,
                    achievementResults: [
                        WeeklyAchievementResult(
                            week: 1,
                            kind: .eggsAndYoung,
                            playerId: "player-1",
                            quantity: 3,
                            points: 3
                        ),
                        WeeklyAchievementResult(
                            week: 1,
                            kind: .eggsAndYoung,
                            playerId: "player-2",
                            quantity: 3,
                            points: 3
                        )
                    ]
                )
            )
        )
    }

    func testPendingChoicesPreventWeekEndEvenWhenAllDiversUsed() throws {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-with-pending-before-week-end",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertTrue(drafts.contains { draft in
            if case .pendingChoiceCreated = draft {
                return true
            }
            return false
        })
        XCTAssertFalse(drafts.contains { draft in
            if case .weekEnded = draft {
                return true
            }
            return false
        })
    }

    func testResolveLastPendingChoiceEndsWeekWhenAllDiversUsed() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 0
        state.playerGameStates["player-2"]?.availableDivers = 0
        let choice = pendingChoice(kind: .placeEgg)
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "resolve-ending-week",
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
            drafts.last,
            .weekEnded(
                WeekEndedEvent(
                    endedWeek: 1,
                    nextWeek: 2,
                    previousFirstPlayerId: "player-1",
                    nextFirstPlayerId: "player-2",
                    nextActivePlayerId: "player-2",
                    isGameEndTriggered: false,
                    achievementResults: [
                        WeeklyAchievementResult(
                            week: 1,
                            kind: .eggsAndYoung,
                            playerId: "player-1",
                            quantity: 3,
                            points: 3
                        ),
                        WeeklyAchievementResult(
                            week: 1,
                            kind: .eggsAndYoung,
                            playerId: "player-2",
                            quantity: 3,
                            points: 3
                        )
                    ]
                )
            )
        )
    }

    func testWeekEndedResetsDiversAndAdvancesWeek() {
        let engine = GameEngine()
        var state = playFishState()
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 0
        state.playerGameStates["player-1"]?.usedDivers = 6
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]
        state.playerGameStates["player-2"]?.availableDivers = 0
        state.playerGameStates["player-2"]?.usedDivers = 6
        state.playerGameStates["player-2"]?.diveSitesReachedBottomThisWeek = [.green]

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .weekEnded(
                    WeekEndedEvent(
                        endedWeek: 1,
                        nextWeek: 2,
                        previousFirstPlayerId: "player-1",
                        nextFirstPlayerId: "player-2",
                        nextActivePlayerId: "player-2",
                        isGameEndTriggered: false,
                        achievementResults: [
                            WeeklyAchievementResult(
                                week: 1,
                                kind: .eggsAndYoung,
                                playerId: "player-1",
                                quantity: 5,
                                points: 5
                            )
                        ]
                    )
                )
            )
        )

        XCTAssertEqual(nextState.currentWeek, 2)
        XCTAssertEqual(nextState.firstPlayerId, "player-2")
        XCTAssertEqual(nextState.activePlayerId, "player-2")
        XCTAssertEqual(nextState.currentTurnIndex, 1)
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.availableDivers, 6)
        XCTAssertEqual(nextState.playerGameStates["player-2"]?.availableDivers, 6)
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.usedDivers, 0)
        XCTAssertEqual(nextState.playerGameStates["player-2"]?.usedDivers, 0)
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek, [])
        XCTAssertEqual(nextState.playerGameStates["player-2"]?.diveSitesReachedBottomThisWeek, [])
        XCTAssertEqual(
            nextState.weeklyAchievementResults,
            [
                WeeklyAchievementResult(
                    week: 1,
                    kind: .eggsAndYoung,
                    playerId: "player-1",
                    quantity: 5,
                    points: 5
                )
            ]
        )
    }

    func testFourthWeekEndedEntersEndGamePending() {
        let engine = GameEngine()
        var state = playFishState()
        state.currentWeek = 4
        state.firstPlayerId = "player-1"

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .weekEnded(
                    WeekEndedEvent(
                        endedWeek: 4,
                        nextWeek: nil,
                        previousFirstPlayerId: "player-1",
                        nextFirstPlayerId: nil,
                        nextActivePlayerId: nil,
                        isGameEndTriggered: true
                    )
                )
            )
        )

        XCTAssertEqual(nextState.phase, .endGamePending)
        XCTAssertEqual(nextState.currentWeek, 4)
        XCTAssertNil(nextState.activePlayerId)
    }

    func testWeekOneAchievementScoresEggsAndYoungExcludingSchools() {
        let scorer = SideAWeeklyAchievementScorer()
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        setResources(
            [
                ResourceQuantity(kind: .egg, amount: 2),
                ResourceQuantity(kind: .young, amount: 3),
                ResourceQuantity(kind: .school, amount: 1)
            ],
            at: target,
            in: &state
        )

        let results = scorer.score(
            week: 1,
            playerStates: [state.playerGameStates["player-1"]!]
        )

        XCTAssertEqual(
            results,
            [
                WeeklyAchievementResult(
                    week: 1,
                    kind: .eggsAndYoung,
                    playerId: "player-1",
                    quantity: 5,
                    points: 5
                )
            ]
        )
    }

    func testWeekTwoAchievementScoresCompleteRowsOfFishIncludingForageFish() {
        let scorer = SideAWeeklyAchievementScorer()
        var state = playFishState(keepForageFish: true)
        clearOceanContent(for: "player-1", in: &state)

        let blue = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        let purple = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 1)
        let green = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 1)
        setContent(.fishCard("fish-6"), at: blue, in: &state)
        setContent(.fishCard("fish-7"), at: purple, in: &state)
        setContent(
            .forageFish(
                ForageFish(
                    forageFishId: "test-forage-green-row-1",
                    name: "测试印刷小鱼",
                    lengthCm: 5,
                    diveSite: .green,
                    rowIndex: 1
                )
            ),
            at: green,
            in: &state
        )

        let results = scorer.score(
            week: 2,
            playerStates: [state.playerGameStates["player-1"]!]
        )

        XCTAssertEqual(
            results,
            [
                WeeklyAchievementResult(
                    week: 2,
                    kind: .rowsOfFish,
                    playerId: "player-1",
                    quantity: 1,
                    points: 2
                )
            ]
        )
    }

    func testWeekTwoAchievementDoesNotScoreIncompleteRow() {
        let scorer = SideAWeeklyAchievementScorer()
        var state = playFishState()
        clearOceanContent(for: "player-1", in: &state)

        setContent(
            .fishCard("fish-6"),
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 2),
            in: &state
        )
        setContent(
            .fishCard("fish-7"),
            at: OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 2),
            in: &state
        )

        let results = scorer.score(
            week: 2,
            playerStates: [state.playerGameStates["player-1"]!]
        )

        XCTAssertEqual(results.first?.quantity, 0)
        XCTAssertEqual(results.first?.points, 0)
    }

    func testConsumedFishDoesNotScoreRowsOfFishAchievement() {
        let scorer = SideAWeeklyAchievementScorer()
        var state = playFishState()
        clearOceanContent(for: "player-1", in: &state)

        for diveSite in DiveSite.allCases {
            setConsumedFish(
                [ConsumedFish(cardId: "consumed-\(diveSite.rawValue)")],
                at: OceanSlotAddress(playerId: "player-1", diveSite: diveSite, rowIndex: 0),
                in: &state
            )
        }

        let results = scorer.score(
            week: 2,
            playerStates: [state.playerGameStates["player-1"]!]
        )

        XCTAssertEqual(results.first?.quantity, 0)
        XCTAssertEqual(results.first?.points, 0)
    }

    func testWeekThreeAchievementScoresSchoolsAtTwoPointsEach() {
        let scorer = SideAWeeklyAchievementScorer()
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        setResources(
            [ResourceQuantity(kind: .school, amount: 1)],
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            in: &state
        )
        setResources(
            [ResourceQuantity(kind: .school, amount: 3)],
            at: OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3),
            in: &state
        )

        let results = scorer.score(
            week: 3,
            playerStates: [state.playerGameStates["player-1"]!]
        )

        XCTAssertEqual(
            results,
            [
                WeeklyAchievementResult(
                    week: 3,
                    kind: .schools,
                    playerId: "player-1",
                    quantity: 4,
                    points: 8
                )
            ]
        )
    }

    func testFourthWeekEndedDraftHasNoAchievementResults() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.currentWeek = 4
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "fourth-week-ending-dive",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        guard case let .weekEnded(event) = drafts.first(where: { draft in
            if case .weekEnded = draft {
                return true
            }
            return false
        }) else {
            return XCTFail("Expected weekEnded event.")
        }
        XCTAssertTrue(event.achievementResults.isEmpty)
        XCTAssertTrue(event.isGameEndTriggered)
        XCTAssertNil(event.nextWeek)
    }

    func testFourthWeekEndEntersGameEndAbilityPhaseBeforeFinalScore() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.currentWeek = 4
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "fourth-week-final-dive",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertFalse(drafts.contains { draft in
            if case .gameEnded = draft {
                return true
            }
            return false
        })
        guard case let .weekEnded(weekEnded) = drafts.first(where: { draft in
            if case .weekEnded = draft {
                return true
            }
            return false
        }) else {
            return XCTFail("Expected weekEnded event.")
        }

        let endGamePendingState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .weekEnded(weekEnded)
            )
        )

        XCTAssertEqual(endGamePendingState.phase, .endGamePending)
        XCTAssertNil(endGamePendingState.finalScoreResult)
    }

    func testFinishGameEndAbilitiesStoresFinalScore() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.phase = .endGamePending
        state.activePlayerId = nil

        let drafts = try engine.makeEventDrafts(
            for: finishGameEndAbilitiesCommand(commandId: "finish-game-end"),
            in: state
        )

        guard case let .gameEnded(gameEnded) = drafts.first else {
            return XCTFail("Expected gameEnded event.")
        }
        let gameEndedState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 11,
                roomId: roomId,
                timestamp: timestamp,
                payload: .gameEnded(gameEnded)
            )
        )

        XCTAssertEqual(gameEndedState.phase, .gameEnded)
        XCTAssertEqual(gameEndedState.finalScoreResult, gameEnded.finalScoreResult)
    }

    func testGameEndAbilityActivationCreatesPendingChoice() throws {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        let state = gameEndAbilityState(cardIds: ["sr.gameEnd.anyCoral"])
        let source = gameEndAbilitySource(cardId: "sr.gameEnd.anyCoral", abilityId: SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd)

        let drafts = try engine.makeEventDrafts(
            for: activateGameEndAbilityCommand(commandId: "activate-game-end", source: source),
            in: state
        )

        guard case let .pendingChoiceCreated(choice) = drafts.first else {
            return XCTFail("Expected pendingChoiceCreated event.")
        }
        XCTAssertEqual(choice.playerId, "player-1")
        XCTAssertEqual(choice.source, .endGameAbility(source.id))
        XCTAssertEqual(choice.kind, .compoundAbility)
        XCTAssertEqual(choice.expectedInput, .abilityEffectSelection)
    }

    func testResolvingGameEndAbilityMarksSourceActivatedAndPreventsRepeat() throws {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        var state = gameEndAbilityState(cardIds: ["sr.gameEnd.anyCoral"])
        let source = gameEndAbilitySource(cardId: "sr.gameEnd.anyCoral", abilityId: SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd)

        state = try resolveAnyCoralGameEndAbility(source: source, in: state, using: engine)

        XCTAssertEqual(coralCount(.green, in: state), 1)
        XCTAssertEqual(coralCount(.blue, in: state), 1)
        XCTAssertTrue(state.activatedGameEndAbilitySourceIds.contains(source.id))
        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "repeat-game-end", source: source),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(source.id))
        }
    }

    func testGameEndAbilitiesCanBeActivatedInAnySourceOrder() throws {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        let state = gameEndAbilityState(cardIds: ["sr.gameEnd.anyCoral", "sr.gameEnd.greenCoral"])
        let secondSource = gameEndAbilitySource(
            cardId: "sr.gameEnd.greenCoral",
            abilityId: SharksAndReefsAbilityIDs.greenCoralThreeGameEnd,
            rowIndex: 1
        )

        let drafts = try engine.makeEventDrafts(
            for: activateGameEndAbilityCommand(commandId: "activate-second-game-end", source: secondSource),
            in: state
        )

        guard case let .pendingChoiceCreated(choice) = drafts.first else {
            return XCTFail("Expected pending choice for the second source.")
        }
        XCTAssertEqual(choice.source, .endGameAbility(secondSource.id))
    }

    func testUnsupportedGameEndAbilityCannotActivateButDoesNotCrash() {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        let state = gameEndAbilityState(cardIds: ["gameEnd.unsupported"])
        let source = gameEndAbilitySource(cardId: "gameEnd.unsupported", abilityId: "unsupported.test.gameEnd.card_999")

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-unsupported-game-end", source: source),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(source.id))
        }
    }

    func testSkippingGameEndAbilityMarksSourceHandledAndPreventsRepeatActivation() throws {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        var state = gameEndAbilityState(cardIds: ["sr.gameEnd.anyCoral"])
        let source = gameEndAbilitySource(cardId: "sr.gameEnd.anyCoral", abilityId: SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd)

        state = applying(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-skip-game-end", source: source),
                in: state
            ),
            to: state,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-game-end", choiceId: choice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertTrue(state.pendingChoices.isEmpty)
        XCTAssertTrue(state.activatedGameEndAbilitySourceIds.contains(source.id))
        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-skip-game-end-repeat", source: source),
                in: state
            )
        )
    }

    func testConsumedFishGameEndAbilityIsIgnored() {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        var state = gameEndAbilityState(cardIds: [])
        let address = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        setConsumedFish([ConsumedFish(cardId: "sr.gameEnd.anyCoral")], at: address, in: &state)
        let source = gameEndAbilitySource(cardId: "sr.gameEnd.anyCoral", abilityId: SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-consumed-game-end", source: source),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(source.id))
        }
    }

    func testBuiltInGameEndScoringAbilityIdsResolveToScoringEffects() {
        let resolver = AbilityResolver()
        let cases: [(AbilityID, AbilityEffectUnit)] = [
            (BaseGameAbilityIDs.abyssalAnglerfishGameEnd, .gameEndScore(condition: .noTokensOnThisFish, points: 3)),
            (BaseGameAbilityIDs.angelsharkGameEnd, .gameEndScore(condition: .consumedFishUnderThisFishAtLeast(3), points: 10)),
            (BaseGameAbilityIDs.atlanticBonitoGameEnd, .gameEndScore(condition: .consumedFishUnderThisFishAtLeast(2), points: 6)),
            (BaseGameAbilityIDs.clownAnemonefishGameEnd, .gameEndScore(condition: .youngOnThisFishExactly(2), points: 6)),
            (BaseGameAbilityIDs.commonFangtoothGameEnd, .gameEndScore(condition: .consumedFishUnderThisFishAtLeast(1), points: 3)),
            (BaseGameAbilityIDs.cookiecutterSharkGameEnd, .gameEndScore(condition: .bottomRow, points: 5)),
            (BaseGameAbilityIDs.leafySeadragonGameEnd, .gameEndScore(condition: .schoolOnThisFish, points: 3)),
            (BaseGameAbilityIDs.paleChimaeraGameEnd, .gameEndScore(condition: .eggYoungAndSchoolOnThisFish, points: 10)),
            (SharksAndReefsAbilityIDs.allDiveSitesCoralThreeGameEnd, .gameEndScore(condition: .allDiveSitesHaveCoralAtLeast(3), points: 5)),
            (SharksAndReefsAbilityIDs.anyDiveSiteCoralFiveGameEnd, .gameEndScore(condition: .anyDiveSiteHasCoralAtLeast(5), points: 3))
        ]

        for (abilityId, expectedEffect) in cases {
            let card = Card(id: "card-\(abilityId)", name: abilityId, abilityIds: [abilityId])
            let ability = resolver.abilityDefinitions(for: card, trigger: .gameEnd).first

            XCTAssertEqual(ability?.effects, [expectedEffect], abilityId)
            XCTAssertEqual(ability?.isOptional, false, abilityId)
        }
    }

    func testBuiltInGameEndExecutableAbilityIdsResolveToGenericEffects() {
        let resolver = AbilityResolver()
        let cases: [(AbilityID, AbilityEffectUnit)] = [
            (BaseGameAbilityIDs.binocularFishGameEnd, .placeEggOnMatchingFish(filter: .lengthBucket(.small), mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.chineseTrumpetfishGameEnd, .placeEggOnMatchingFish(filter: .lengthBucket(.medium), mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.europeanAnchovyGameEnd, .placeEggOnMatchingFish(filter: .topRow, mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.largetoothFlounderGameEnd, .placeEggOnMatchingFish(filter: .diveSite(.green), mode: .chooseOneEligibleFish)),
            (BaseGameAbilityIDs.marianaSnailfishGameEnd, .placeEggOnMatchingFish(filter: .bottomRow, mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.oceanSunfishGameEnd, .placeEggOnMatchingFish(filter: .lengthBucket(.large), mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.pudgyCuskEelGameEnd, .placeEggOnMatchingFish(filter: .diveSite(.blue), mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.sloansViperfishGameEnd, .placeEggOnMatchingFish(filter: .tag("predator"), mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.yellowtailSnapperGameEnd, .placeEggOnMatchingFish(filter: .diveSite(.purple), mode: .onEachEligibleFish)),
            (BaseGameAbilityIDs.atlanticSalmonGameEnd, .playFishFromHand(filter: .any, placement: .topRow, costMode: .payCost)),
            (BaseGameAbilityIDs.blobSculpinGameEnd, .playFishFromHand(filter: .any, placement: .diveSite(.green), costMode: .payCost)),
            (BaseGameAbilityIDs.crocodilefishGameEnd, .playFishFromHand(filter: .any, placement: .diveSite(.blue), costMode: .payCost)),
            (BaseGameAbilityIDs.facelessCuskGameEnd, .playFishFromHand(filter: .any, placement: .bottomRow, costMode: .payCost)),
            (BaseGameAbilityIDs.giantTrevallyGameEnd, .playFishFromHand(filter: .any, placement: .diveSite(.purple), costMode: .payCost)),
            (BaseGameAbilityIDs.stripedMarlinGameEnd, .playFishFromHand(filter: .any, placement: .sunlight, costMode: .payCost)),
            (SharksAndReefsAbilityIDs.blueCoralThreeGameEnd, .gainCoral(selector: .blue, count: 1)),
            (SharksAndReefsAbilityIDs.purpleCoralThreeGameEnd, .gainCoral(selector: .purple, count: 1)),
            (SharksAndReefsAbilityIDs.scatterSchoolTwiceGameEnd, .scatterSchool(count: 1)),
            (SharksAndReefsAbilityIDs.freePlayMediumDuskySharkGameEnd, .playFishForFree(filter: .lengthBucket(.medium), count: 1)),
            (SharksAndReefsAbilityIDs.freePlayMediumFrilledSharkGameEnd, .playFishForFree(filter: .lengthBucket(.medium), count: 1))
        ]

        for (abilityId, expectedFirstEffect) in cases {
            let card = Card(id: "card-\(abilityId)", name: abilityId, abilityIds: [abilityId])
            let ability = resolver.abilityDefinitions(for: card, trigger: .gameEnd).first

            XCTAssertEqual(ability?.effects.first, expectedFirstEffect, abilityId)
            XCTAssertEqual(ability?.isOptional, true, abilityId)
        }
    }

    func testKnownMixedGameEndAbilityIdsRemainUnsupported() {
        let resolver = AbilityResolver()
        let unsupportedIds = [
            "unsupported.base.gameEnd.card_062",
            "unsupported.base.gameEnd.card_109",
            "unsupported.base.gameEnd.card_117",
            "unsupported.sr.gameEnd.card_141",
            "unsupported.sr.gameEnd.card_193",
            "unsupported.sr.gameEnd.card_209"
        ]

        for abilityId in unsupportedIds {
            let card = Card(id: "card-\(abilityId)", name: abilityId, abilityIds: [abilityId])
            let ability = resolver.abilityDefinitions(for: card, trigger: .gameEnd).first

            XCTAssertEqual(ability?.effects, [.unsupported], abilityId)
        }
    }

    func testScoringOnlyGameEndAbilitiesScoreVisibleFishOnlyAndDoNotAffectPrintedPoints() {
        let calculator = FinalScoreCalculator()
        var state = gameEndAbilityState(cardIds: ["gameEnd.noTokens", "gameEnd.youngTwo"])
        state.weeklyAchievementResults = []
        clearResources(for: "player-1", in: &state)
        let youngAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        let bottomAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 5)
        setContent(.fishCard("gameEnd.bottomRow"), at: bottomAddress, in: &state)
        setResources([ResourceQuantity(kind: .young, amount: 2)], at: youngAddress, in: &state)
        setConsumedFish([ConsumedFish(cardId: "gameEnd.consumedOne")], at: bottomAddress, in: &state)
        setContent(
            .forageFish(ForageFish(forageFishId: "forage", name: "Forage", lengthCm: 5, diveSite: .purple, rowIndex: 0)),
            at: OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0),
            in: &state
        )
        setConsumedFish(
            [ConsumedFish(cardId: "gameEnd.noTokens")],
            at: OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0),
            in: &state
        )

        let result = calculator.calculate(in: state, cardCatalog: gameEndAbilityCatalog())
        let playerScore = result.results.first { $0.playerId == "player-1" }

        XCTAssertEqual(playerScore?.fishPrintedPoints, 3)
        XCTAssertEqual(playerScore?.gameEndAbilityPoints, 14)
        XCTAssertEqual(playerScore?.totalPoints, 21)
    }

    func testGameEndScoringCoralConditionsUseCurrentReefCounts() {
        let calculator = FinalScoreCalculator()
        var state = gameEndAbilityState(cardIds: ["gameEnd.allReefs3", "gameEnd.anyReef5"])
        state.weeklyAchievementResults = []
        state.playerGameStates["player-1"]?.ocean.coralReefs = [
            CoralReefState(diveSite: .blue, coralCount: 3, maxCoral: 6, completionBonus: 6),
            CoralReefState(diveSite: .purple, coralCount: 5, maxCoral: 6, completionBonus: 8),
            CoralReefState(diveSite: .green, coralCount: 3, maxCoral: 6, completionBonus: 5)
        ]

        let result = calculator.calculate(in: state, cardCatalog: gameEndAbilityCatalog())
        let playerScore = result.results.first { $0.playerId == "player-1" }

        XCTAssertEqual(playerScore?.gameEndAbilityPoints, 8)
    }

    func testGameEndOnEachMatchingEggAbilityPlacesEggsAndSkipsSlotsWithEggs() throws {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        var state = gameEndAbilityState(cardIds: ["gameEnd.smallEgg", "small.eligible", "medium.ineligible"])
        let source = gameEndAbilitySource(cardId: "gameEnd.smallEgg", abilityId: BaseGameAbilityIDs.binocularFishGameEnd)
        let smallAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        let mediumAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 2)
        let alreadyHasEggAddress = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        setContent(.fishCard("small.hasEgg"), at: alreadyHasEggAddress, in: &state)
        setResources([ResourceQuantity(kind: .egg, amount: 1)], at: alreadyHasEggAddress, in: &state)

        state = applying(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-small-eggs", source: source),
                in: state
            ),
            to: state,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "finish-small-eggs", choiceId: choice.choiceId, resolution: .finishAbility),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(resourceAmount(.egg, at: source.slotAddress, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: smallAddress, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: mediumAddress, in: state), 0)
        XCTAssertEqual(resourceAmount(.egg, at: alreadyHasEggAddress, in: state), 1)
        XCTAssertTrue(state.activatedGameEndAbilitySourceIds.contains(source.id))
    }

    func testOceanSunfishGameEndPlacesEggOnEveryLargeFish() throws {
        let engine = GameEngine(cardCatalog: TestCardCatalog(fishCards: [
            Card(
                id: "gameEnd.oceanSunfish",
                name: "Ocean Sunfish",
                abilityIds: [BaseGameAbilityIDs.oceanSunfishGameEnd],
                printedPoints: 1,
                lengthCm: 160
            ),
            Card(id: "large.one", name: "Large One", printedPoints: 1, lengthCm: 170),
            Card(id: "large.two", name: "Large Two", printedPoints: 1, lengthCm: 180),
            Card(id: "small.one", name: "Small One", printedPoints: 1, lengthCm: 10)
        ]))
        var state = gameEndAbilityState(cardIds: ["gameEnd.oceanSunfish", "large.one", "large.two", "small.one"])
        let source = gameEndAbilitySource(cardId: "gameEnd.oceanSunfish", abilityId: BaseGameAbilityIDs.oceanSunfishGameEnd)
        let largeOne = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        let largeTwo = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 2)
        let smallOne = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 3)

        state = applying(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-ocean-sunfish", source: source),
                in: state
            ),
            to: state,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "finish-ocean-sunfish", choiceId: choice.choiceId, resolution: .finishAbility),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(resourceAmount(.egg, at: source.slotAddress, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: largeOne, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: largeTwo, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: smallOne, in: state), 0)
    }

    func testEuropeanAnchovyGameEndPlacesEggOnEachTopRowFish() throws {
        let engine = GameEngine(cardCatalog: TestCardCatalog(fishCards: [
            Card(
                id: "gameEnd.anchovy",
                name: "European Anchovy",
                abilityIds: [BaseGameAbilityIDs.europeanAnchovyGameEnd],
                printedPoints: 1,
                lengthCm: 10
            ),
            Card(id: "top.one", name: "Top One", printedPoints: 1, lengthCm: 12),
            Card(id: "top.two", name: "Top Two", printedPoints: 1, lengthCm: 14),
            Card(id: "mid.one", name: "Mid One", printedPoints: 1, lengthCm: 20)
        ]))
        var state = gameEndAbilityState(cardIds: [])
        let source = gameEndAbilitySource(cardId: "gameEnd.anchovy", abilityId: BaseGameAbilityIDs.europeanAnchovyGameEnd)
        let sourceAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let topOne = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        let topTwo = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 0)
        let midOne = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        let alreadyHasEggAddress = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 1)
        setContent(.fishCard("gameEnd.anchovy"), at: sourceAddress, in: &state)
        setContent(.fishCard("top.one"), at: topOne, in: &state)
        setContent(.fishCard("top.two"), at: topTwo, in: &state)
        setContent(.fishCard("mid.one"), at: midOne, in: &state)
        setContent(.fishCard("top.hasEgg"), at: alreadyHasEggAddress, in: &state)
        setResources([ResourceQuantity(kind: .egg, amount: 1)], at: alreadyHasEggAddress, in: &state)

        state = applying(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-anchovy", source: source),
                in: state
            ),
            to: state,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(choice.expectedInput, Optional(PendingChoiceExpectedInput.none))

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "finish-anchovy", choiceId: choice.choiceId, resolution: .finishAbility),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(resourceAmount(.egg, at: sourceAddress, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: topOne, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: topTwo, in: state), 1)
        XCTAssertEqual(resourceAmount(.egg, at: midOne, in: state), 0)
        XCTAssertEqual(resourceAmount(.egg, at: alreadyHasEggAddress, in: state), 1)
        XCTAssertTrue(state.activatedGameEndAbilitySourceIds.contains(source.id))
        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-anchovy-repeat", source: source),
                in: state
            )
        )
    }

    func testGameEndPaidPlayFishFromHandRequiresPaymentAndPlacesFish() throws {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        var state = gameEndAbilityState(cardIds: ["gameEnd.playBottom"])
        let source = gameEndAbilitySource(cardId: "gameEnd.playBottom", abilityId: BaseGameAbilityIDs.facelessCuskGameEnd)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 5)
        state.playerGameStates["player-1"]?.hand = ["paid.hand", "payment.card"]

        state = applying(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-paid-play", source: source),
                in: state
            ),
            to: state,
            using: engine
        )
        var choice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "choose-paid-card", choiceId: choice.choiceId, resolution: .choosePlayFishFromHand("paid.hand")),
                in: state
            ),
            to: state,
            using: engine
        )
        choice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(choice.expectedInput, .playFishFromHandTargetSlot)

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "choose-paid-target", choiceId: choice.choiceId, resolution: .choosePlayFishFromHandTarget(target)),
                in: state
            ),
            to: state,
            using: engine
        )
        choice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(choice.expectedInput, .playFishFromHandPayment)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "paid-play-no-payment",
                    choiceId: choice.choiceId,
                    resolution: .playFishFromHand(cardId: "paid.hand", targetSlot: target, payment: .empty)
                ),
                in: state
            )
        )

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "paid-play-with-payment",
                    choiceId: choice.choiceId,
                    resolution: .playFishFromHand(
                        cardId: "paid.hand",
                        targetSlot: target,
                        payment: PlayFishPayment(
                            discardedCardIds: ["payment.card"],
                            eggSources: [],
                            youngSources: []
                        )
                    )
                ),
                in: state
            ),
            to: state,
            using: engine
        )

        let playerState = try XCTUnwrap(state.playerGameStates["player-1"])
        XCTAssertEqual(playerState.ocean.slots.first { $0.address == target }?.content, .fishCard("paid.hand"))
        XCTAssertFalse(playerState.hand.contains("paid.hand"))
        XCTAssertFalse(playerState.hand.contains("payment.card"))
        XCTAssertEqual(playerState.discardPile, ["payment.card"])
        XCTAssertTrue(state.activatedGameEndAbilitySourceIds.contains(source.id))
    }

    func testGameEndAbilityEffectsAreIncludedInFinalScoreAfterFinish() throws {
        let engine = GameEngine(cardCatalog: gameEndAbilityCatalog())
        var state = gameEndAbilityState(cardIds: ["sr.gameEnd.anyCoral"])
        let source = gameEndAbilitySource(cardId: "sr.gameEnd.anyCoral", abilityId: SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd)
        state = try resolveAnyCoralGameEndAbility(source: source, in: state, using: engine)

        let drafts = try engine.makeEventDrafts(
            for: finishGameEndAbilitiesCommand(commandId: "finish-scored-game-end"),
            in: state
        )

        guard case let .gameEnded(gameEnded) = drafts.first,
              let playerScore = gameEnded.finalScoreResult.results.first(where: { $0.playerId == "player-1" })
        else {
            return XCTFail("Expected final score.")
        }
        XCTAssertEqual(playerScore.coralPoints, 2)
        XCTAssertEqual(gameEnded.finalScoreResult.results.first?.totalPoints, playerScore.totalPoints)
    }

    func testFinalScoreCalculatorScoresAllSupportedCategoriesAndExcludesForageFishPrintedPoints() {
        let calculator = FinalScoreCalculator()
        var state = playFishState(keepForageFish: true)
        clearResources(for: "player-1", in: &state)
        clearOceanContent(for: "player-1", in: &state)
        state.weeklyAchievementResults = [
            WeeklyAchievementResult(week: 1, kind: .eggsAndYoung, playerId: "player-1", quantity: 3, points: 3),
            WeeklyAchievementResult(week: 2, kind: .rowsOfFish, playerId: "player-1", quantity: 3, points: 6)
        ]
        let scoredFishAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let forageFishAddress = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3)
        setContent(.fishCard("scored-fish"), at: scoredFishAddress, in: &state)
        setContent(
            .forageFish(
                ForageFish(
                    forageFishId: "test-forage",
                    name: "测试印刷小鱼",
                    lengthCm: 5,
                    diveSite: .purple,
                    rowIndex: 3
                )
            ),
            at: forageFishAddress,
            in: &state
        )
        setResources(
            [
                ResourceQuantity(kind: .egg, amount: 2),
                ResourceQuantity(kind: .young, amount: 3),
                ResourceQuantity(kind: .school, amount: 2)
            ],
            at: scoredFishAddress,
            in: &state
        )
        setConsumedFish(
            [
                ConsumedFish(cardId: "consumed-1"),
                ConsumedFish(
                    forageFish: ForageFish(
                        forageFishId: "consumed-forage",
                        name: "被覆盖印刷小鱼",
                        lengthCm: 2,
                        diveSite: .blue,
                        rowIndex: 0
                    )
                )
            ],
            at: scoredFishAddress,
            in: &state
        )

        let result = calculator.calculate(
            in: state,
            cardCatalog: TestCardCatalog(
                fishCards: [Card(id: "scored-fish", name: "计分鱼牌", printedPoints: 4)]
            )
        )
        let playerResult = result.results.first { $0.playerId == "player-1" }

        XCTAssertEqual(playerResult?.weeklyAchievementPoints, 9)
        XCTAssertEqual(playerResult?.fishPrintedPoints, 4)
        XCTAssertEqual(playerResult?.gameEndAbilityPoints, 0)
        XCTAssertEqual(playerResult?.eggPoints, 2)
        XCTAssertEqual(playerResult?.youngPoints, 3)
        XCTAssertEqual(playerResult?.schoolPoints, 12)
        XCTAssertEqual(playerResult?.consumedFishPoints, 2)
        XCTAssertEqual(playerResult?.coralPoints, 0)
        XCTAssertEqual(playerResult?.completeReefBonusPoints, 0)
        XCTAssertEqual(playerResult?.totalPoints, 32)
    }

    func testFinalScoreCalculatorScoresOnePointPerCoralToken() {
        let calculator = FinalScoreCalculator()
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        clearOceanContent(for: "player-1", in: &state)
        state.weeklyAchievementResults = []
        state.playerGameStates["player-1"]?.ocean.coralReefs = [
            CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6),
            CoralReefState(diveSite: .purple, coralCount: 4, maxCoral: 6, completionBonus: 8),
            CoralReefState(diveSite: .green, coralCount: 1, maxCoral: 6, completionBonus: 5)
        ]

        let result = calculator.calculate(in: state, cardCatalog: TestCardCatalog())
        let playerResult = result.results.first { $0.playerId == "player-1" }

        XCTAssertEqual(playerResult?.coralPoints, 7)
        XCTAssertEqual(playerResult?.completeReefBonusPoints, 0)
        XCTAssertEqual(playerResult?.totalPoints, 7)
    }

    func testFinalScoreCalculatorOnlyAwardsCompleteReefBonusWhenReefIsFull() {
        let calculator = FinalScoreCalculator()
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        clearOceanContent(for: "player-1", in: &state)
        state.weeklyAchievementResults = []
        state.playerGameStates["player-1"]?.ocean.coralReefs = [
            CoralReefState(diveSite: .blue, coralCount: 6, maxCoral: 6, completionBonus: 60),
            CoralReefState(diveSite: .purple, coralCount: 5, maxCoral: 6, completionBonus: 80),
            CoralReefState(diveSite: .green, coralCount: 6, maxCoral: 6, completionBonus: 50)
        ]

        let result = calculator.calculate(in: state, cardCatalog: TestCardCatalog())
        let playerResult = result.results.first { $0.playerId == "player-1" }

        XCTAssertEqual(playerResult?.coralPoints, 17)
        XCTAssertEqual(playerResult?.completeReefBonusPoints, 110)
        XCTAssertEqual(playerResult?.totalPoints, 127)
    }

    func testFinalScoreCalculatorAwardsCompleteReefBonusAtOrAboveMaxCoral() {
        let calculator = FinalScoreCalculator()
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        clearOceanContent(for: "player-1", in: &state)
        state.weeklyAchievementResults = []
        state.playerGameStates["player-1"]?.ocean.coralReefs = [
            CoralReefState(diveSite: .blue, coralCount: 7, maxCoral: 6, completionBonus: 6)
        ]

        let result = calculator.calculate(in: state, cardCatalog: TestCardCatalog())
        let playerResult = result.results.first { $0.playerId == "player-1" }

        XCTAssertEqual(playerResult?.coralPoints, 7)
        XCTAssertEqual(playerResult?.completeReefBonusPoints, 6)
        XCTAssertEqual(playerResult?.totalPoints, 13)
    }

    func testScoreCategoryIncludesSharksAndReefsFinalScoreCategories() {
        XCTAssertEqual(ScoreCategory.coral.rawValue, "coral")
        XCTAssertEqual(ScoreCategory.completeReefBonus.rawValue, "completeReefBonus")
    }

    func testFinalScoreCalculatorDeterminesWinnerAndTie() {
        let calculator = FinalScoreCalculator()
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        clearResources(for: "player-2", in: &state)
        setResources(
            [ResourceQuantity(kind: .egg, amount: 2)],
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            in: &state
        )
        setResources(
            [ResourceQuantity(kind: .egg, amount: 1)],
            at: OceanSlotAddress(playerId: "player-2", diveSite: .blue, rowIndex: 0),
            in: &state
        )

        let winnerResult = calculator.calculate(in: state, cardCatalog: TestCardCatalog())

        XCTAssertEqual(winnerResult.winnerPlayerIds, ["player-1"])
        XCTAssertFalse(winnerResult.isTie)

        setResources(
            [ResourceQuantity(kind: .egg, amount: 2)],
            at: OceanSlotAddress(playerId: "player-2", diveSite: .blue, rowIndex: 0),
            in: &state
        )
        let tieResult = calculator.calculate(in: state, cardCatalog: TestCardCatalog())

        XCTAssertEqual(tieResult.winnerPlayerIds, ["player-1", "player-2"])
        XCTAssertTrue(tieResult.isTie)
    }

    func testPlayFishDraftIncludesTargetSlotAndPayment() throws {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .blue,
            rowIndex: 0
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
            diveSite: .blue,
            rowIndex: 0
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
        XCTAssertEqual(playerState?.ocean.slots.first?.content, .fishCard("fish-2"))
        XCTAssertEqual(
            playerState?.ocean.slots.first?.resources,
            []
        )
        XCTAssertEqual(state.deckState.discardPile, [])
    }

    func testNormalFishCanPlayToEmptySlotWithoutCoverCost() throws {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "normal-empty", cardId: "fish-6", targetSlot: targetSlot),
            in: state
        )

        XCTAssertTrue(drafts.contains(.fishPlayed(FishPlayedEvent(
            playerId: "player-1",
            cardId: "fish-6",
            targetSlot: targetSlot,
            payment: .empty,
            nextActivePlayerId: nil
        ))))
    }

    func testNormalFishCanVoluntarilyCoverShorterFishWithoutCoverCost() throws {
        let engine = GameEngine()
        var state = playFishState()
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        setContent(.fishCard("starter-fish-1"), at: targetSlot, in: &state)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "normal-cover", cardId: "fish-6", targetSlot: targetSlot),
            in: state
        )

        XCTAssertTrue(drafts.contains(.fishPlayed(FishPlayedEvent(
            playerId: "player-1",
            cardId: "fish-6",
            targetSlot: targetSlot,
            payment: .empty,
            nextActivePlayerId: nil
        ))))
    }

    func testReefFishWithCoralRequirementRejectsTwilightSlot() {
        let engine = GameEngine(cardCatalog: reefFishCatalog())
        var state = reefFishState(coralReefs: [
            CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6)
        ])
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 3)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "reef-twilight", cardId: "reef-fish", targetSlot: targetSlot),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .coralRequirementMustBeSunlit(targetSlot))
        }
    }

    func testReefFishWithCoralRequirementAllowsSunlightSlot() throws {
        let engine = GameEngine(cardCatalog: reefFishCatalog())
        let state = reefFishState(coralReefs: [
            CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6)
        ])
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "reef-sunlight", cardId: "reef-fish", targetSlot: targetSlot),
            in: state
        )

        XCTAssertTrue(drafts.contains(.fishPlayed(FishPlayedEvent(
            playerId: "player-1",
            cardId: "reef-fish",
            targetSlot: targetSlot,
            payment: .empty,
            nextActivePlayerId: nil
        ))))
    }

    func testReefFishWithCoralRequirementRejectsInsufficientCoral() {
        let engine = GameEngine(cardCatalog: reefFishCatalog())
        let state = reefFishState(coralReefs: [
            CoralReefState(diveSite: .blue, coralCount: 1, maxCoral: 6, completionBonus: 6)
        ])
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "reef-insufficient", cardId: "reef-fish", targetSlot: targetSlot),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .insufficientCoral(diveSite: .blue, required: 2, actual: 1)
            )
        }
    }

    func testReefFishWithCoralRequirementUsesTargetDiveSiteCoralCount() {
        let engine = GameEngine(cardCatalog: reefFishCatalog())
        let state = reefFishState(coralReefs: [
            CoralReefState(diveSite: .blue, coralCount: 1, maxCoral: 6, completionBonus: 6),
            CoralReefState(diveSite: .green, coralCount: 6, maxCoral: 6, completionBonus: 5)
        ])
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "reef-target-site", cardId: "reef-fish", targetSlot: targetSlot),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .insufficientCoral(diveSite: .blue, required: 2, actual: 1)
            )
        }
    }

    func testReefFishWithCoralRequirementAllowsExactCoralCount() throws {
        let engine = GameEngine(cardCatalog: reefFishCatalog())
        let state = reefFishState(coralReefs: [
            CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6)
        ])
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "reef-exact", cardId: "reef-fish", targetSlot: targetSlot),
            in: state
        )

        XCTAssertTrue(drafts.contains { draft in
            if case .fishPlayed = draft {
                return true
            }
            return false
        })
    }

    func testReefFishWithSpecificCoralRequirementRequiresMatchingDiveSite() {
        let engine = GameEngine(cardCatalog: reefFishCatalog())
        let state = reefFishState(coralReefs: CoralReefState.sharksAndReefsInitial)
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "reef-specific-site", cardId: "purple-reef-fish", targetSlot: targetSlot),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .coralRequirementDiveSiteMismatch(expected: .purple, actual: .blue)
            )
        }
    }

    func testBaseGameFishWithoutCoralRequirementIsUnaffectedByMissingCoralReefs() throws {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "base-no-coral", cardId: "fish-6", targetSlot: targetSlot),
            in: state
        )

        XCTAssertTrue(drafts.contains { draft in
            if case .fishPlayed = draft {
                return true
            }
            return false
        })
    }

    func testCoverShorterFishCostRejectsEmptySlot() {
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let engine = GameEngine(cardCatalog: coverShorterFishCatalog())
        let state = coverShorterFishState()

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "cover-empty", cardId: "cover-fish", targetSlot: targetSlot),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .targetMustCoverShorterFish(targetSlot))
        }
    }

    func testCoverShorterFishCostCanCoverShorterForageFish() throws {
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        let engine = GameEngine(cardCatalog: coverShorterFishCatalog())
        let state = coverShorterFishState(keepForageFish: true)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "cover-forage", cardId: "cover-fish", targetSlot: targetSlot),
            in: state
        )

        XCTAssertTrue(drafts.contains(.fishPlayed(FishPlayedEvent(
            playerId: "player-1",
            cardId: "cover-fish",
            targetSlot: targetSlot,
            payment: .empty,
            nextActivePlayerId: nil
        ))))
    }

    func testCoverShorterFishCostCanCoverShorterFishCard() throws {
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let engine = GameEngine(cardCatalog: coverShorterFishCatalog())
        var state = coverShorterFishState()
        setContent(.fishCard("starter-fish-1"), at: targetSlot, in: &state)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "cover-card", cardId: "cover-fish", targetSlot: targetSlot),
            in: state
        )

        XCTAssertTrue(drafts.contains(.fishPlayed(FishPlayedEvent(
            playerId: "player-1",
            cardId: "cover-fish",
            targetSlot: targetSlot,
            payment: .empty,
            nextActivePlayerId: nil
        ))))
    }

    func testCoverShorterFishCostCannotCoverSameLengthOrLongerFish() {
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let engine = GameEngine(cardCatalog: coverShorterFishCatalog())
        var state = coverShorterFishState()
        setContent(.fishCard("same-length-fish"), at: targetSlot, in: &state)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "cover-same-length", cardId: "cover-fish", targetSlot: targetSlot),
                in: state
            )
        ) { error in
            XCTAssertEqual(
                error as? CommandValidationError,
                .targetFishTooLongToCover(
                    target: targetSlot,
                    newFishLengthCm: 30,
                    existingFishLengthCm: 30
                )
            )
        }
    }

    func testCoverShorterFishCostAddsConsumedFishAndPreservesResources() throws {
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        let engine = GameEngine(cardCatalog: coverShorterFishCatalog())
        var state = coverShorterFishState(keepForageFish: true)
        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "cover-preserve-resources", cardId: "cover-fish", targetSlot: targetSlot),
            in: state
        )
        guard case let .fishPlayed(event) = drafts.first else {
            return XCTFail("Expected fish played draft.")
        }

        state = engine.reduce(
            state: state,
            event: GameEvent(sequenceNumber: 10, roomId: roomId, timestamp: timestamp, payload: .fishPlayed(event))
        )

        let slot = state.playerGameStates["player-1"]?.ocean.slots.first { $0.address == targetSlot }
        XCTAssertEqual(slot?.content, .fishCard("cover-fish"))
        XCTAssertEqual(slot?.consumedFish.count, 1)
        XCTAssertEqual(slot?.consumedFish.first?.forageFishId, "sample-forage-blue-row-4")
        XCTAssertEqual(slot?.resources, [ResourceQuantity(kind: .egg, amount: 1)])
    }

    func testCoverShorterFishConsumedFishStillScoresOnePoint() throws {
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        let engine = GameEngine(cardCatalog: coverShorterFishCatalog())
        var state = coverShorterFishState(keepForageFish: true)
        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "cover-score", cardId: "cover-fish", targetSlot: targetSlot),
            in: state
        )
        guard case let .fishPlayed(event) = drafts.first else {
            return XCTFail("Expected fish played draft.")
        }
        state = engine.reduce(
            state: state,
            event: GameEvent(sequenceNumber: 10, roomId: roomId, timestamp: timestamp, payload: .fishPlayed(event))
        )

        let result = FinalScoreCalculator().calculate(in: state, cardCatalog: coverShorterFishCatalog())
        let playerResult = result.results.first { $0.playerId == "player-1" }

        XCTAssertEqual(playerResult?.consumedFishPoints, 1)
    }

    func testPlayFishRejectsInactivePlayer() {
        let engine = GameEngine()
        let state = playFishState()
        let targetSlot = OceanSlotAddress(
            playerId: "player-2",
            diveSite: .blue,
            rowIndex: 0
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
            diveSite: .blue,
            rowIndex: 0
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
            diveSite: .blue,
            rowIndex: 0
        )
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .purple,
            rowIndex: 3
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
            diveSite: .blue,
            rowIndex: 0
        )
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .purple,
            rowIndex: 3
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

        XCTAssertEqual(target?.content, .fishCard("fish-2"))
        XCTAssertEqual(source?.resources.first(where: { $0.kind == .egg })?.amount, 1)
    }

    func testPlayFishAcceptsShorterForageFishTargetSlot() throws {
        let engine = GameEngine()
        let state = playFishState(keepForageFish: true)
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .blue,
            rowIndex: 4
        )

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-forage-target",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(
                    PlayFishCommand(
                        cardId: "fish-6",
                        targetSlot: targetSlot,
                        payment: .empty
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(
            drafts.first,
            .fishPlayed(
                FishPlayedEvent(
                    playerId: "player-1",
                    cardId: "fish-6",
                    targetSlot: targetSlot,
                    payment: .empty,
                    nextActivePlayerId: nil
                )
            )
        )
    }

    func testPlayFishRejectsSameLengthOrLongerForageFishTargetSlot() {
        let engine = GameEngine()
        let state = playFishState(keepForageFish: true)
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .green,
            rowIndex: 1
        )

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "play-fish-forage-too-short",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(
                            cardId: "fish-6",
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
                .targetFishTooLongToCover(target: targetSlot, newFishLengthCm: 8, existingFishLengthCm: 9)
            )
        }
    }

    func testPlayFishAcceptsShorterFishCardTargetSlot() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand = ["fish-6"]
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        setContent(.fishCard("starter-fish-1"), at: targetSlot, in: &state)

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-cover-card",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(
                    PlayFishCommand(
                        cardId: "fish-6",
                        targetSlot: targetSlot,
                        payment: .empty
                    )
                )
            ),
            in: state
        )

        XCTAssertEqual(drafts.first, .fishPlayed(FishPlayedEvent(playerId: "player-1", cardId: "fish-6", targetSlot: targetSlot, payment: .empty, nextActivePlayerId: nil)))
    }

    func testPlayFishRejectsSameLengthOrLongerFishCardTargetSlot() {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand = ["starter-fish-1"]
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        setContent(.fishCard("fish-6"), at: targetSlot, in: &state)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "play-fish-cover-card-too-short",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(
                            cardId: "starter-fish-1",
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
                .targetFishTooLongToCover(target: targetSlot, newFishLengthCm: 2, existingFishLengthCm: 8)
            )
        }
    }

    func testFishPlayedReducerMovesCoveredForageFishToConsumedFishAndKeepsResources() {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        state.playerGameStates["player-1"]?.hand = ["fish-6"]
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        setConsumedFish([ConsumedFish(cardId: "already-consumed")], at: targetSlot, in: &state)

        state = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .fishPlayed(
                    FishPlayedEvent(
                        playerId: "player-1",
                        cardId: "fish-6",
                        targetSlot: targetSlot,
                        payment: .empty,
                        nextActivePlayerId: nil
                    )
                )
            )
        )

        let slot = state.playerGameStates["player-1"]?.ocean.slots.first { $0.address == targetSlot }
        XCTAssertEqual(slot?.content, .fishCard("fish-6"))
        XCTAssertEqual(slot?.resources, [ResourceQuantity(kind: .egg, amount: 1)])
        XCTAssertEqual(slot?.consumedFish.count, 2)
        XCTAssertEqual(slot?.consumedFish.first, ConsumedFish(cardId: "already-consumed"))
        XCTAssertEqual(slot?.consumedFish.last?.forageFishId, "sample-forage-blue-row-4")
        XCTAssertEqual(slot?.consumedFish.last?.lengthCm, 1)
    }

    func testFishPlayedReducerMovesCoveredFishCardToConsumedFish() {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand = ["fish-6"]
        let targetSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        setContent(.fishCard("starter-fish-1"), at: targetSlot, in: &state)

        state = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .fishPlayed(
                    FishPlayedEvent(
                        playerId: "player-1",
                        cardId: "fish-6",
                        targetSlot: targetSlot,
                        payment: .empty,
                        nextActivePlayerId: nil
                    )
                )
            )
        )

        let slot = state.playerGameStates["player-1"]?.ocean.slots.first { $0.address == targetSlot }
        XCTAssertEqual(slot?.content, .fishCard("fish-6"))
        XCTAssertEqual(slot?.consumedFish, [ConsumedFish(cardId: "starter-fish-1", lengthCm: 2)])
    }

    func testPlayFishAcceptsYoungSourceFromDifferentSlotThanTarget() throws {
        let engine = GameEngine()
        var state = playFishStateWithResourcesInDifferentSlot()
        state.playerGameStates["player-1"]?.hand = ["fish-3"]
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .blue,
            rowIndex: 0
        )
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .purple,
            rowIndex: 3
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

    func testDiveWithPendingChoicesDoesNotImmediatelyAdvanceActivePlayer() throws {
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

        XCTAssertEqual(drafts.count, 2)
        guard case let .diverMoved(diverMoved) = drafts[0],
              case let .pendingChoiceCreated(choice) = drafts[1]
        else {
            return XCTFail("Expected diver movement followed by the first queue choice.")
        }

        XCTAssertNil(diverMoved.nextActivePlayerId)
        XCTAssertEqual(diverMoved.diveResolutionQueue?.steps.count, 1)
        XCTAssertEqual(diverMoved.diveResolutionQueue?.currentStep?.source, .bottomBonus)
        XCTAssertEqual(choice.choiceId, "dive-blue-dive-bonus-3")
        XCTAssertEqual(choice.kind, .recoverFromDiscardOrDraw)
        XCTAssertEqual(choice.diveQueueId, diverMoved.diveResolutionQueue?.queueId)
        XCTAssertEqual(choice.diveStepId, diverMoved.diveResolutionQueue?.currentStep?.stepId)
    }

    func testPurpleBottomBonusCreatesPlaceEggPendingChoice() throws {
        let engine = GameEngine()
        let state = playFishState()

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-purple",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .purple))
            ),
            in: state
        )

        guard case let .diverMoved(diverMoved) = drafts[0],
              case let .pendingChoiceCreated(choice) = drafts[1]
        else {
            return XCTFail("Expected purple bottom bonus pending choice.")
        }

        XCTAssertEqual(diverMoved.diveResolutionQueue?.steps.count, 1)
        XCTAssertEqual(diverMoved.diveResolutionQueue?.currentStep?.source, .bottomBonus)
        XCTAssertEqual(choice.kind, .placeEgg)
        XCTAssertEqual(choice.source, .diveBonus(.purple))
    }

    func testGreenBottomBonusCreatesMoveYoungOrSchoolPendingChoice() throws {
        let engine = GameEngine()
        let state = playFishState()

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-green",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .green))
            ),
            in: state
        )

        guard case let .diverMoved(diverMoved) = drafts[0],
              case let .pendingChoiceCreated(choice) = drafts[1]
        else {
            return XCTFail("Expected green bottom bonus pending choice.")
        }

        XCTAssertEqual(diverMoved.diveResolutionQueue?.steps.count, 1)
        XCTAssertEqual(diverMoved.diveResolutionQueue?.currentStep?.source, .bottomBonus)
        XCTAssertEqual(choice.kind, .moveYoungOrSchool)
        XCTAssertEqual(choice.source, .diveBonus(.green))
    }

    func testDiveReducerConsumesDiverRecordsBottomBonusWithoutAdvancingActivePlayer() {
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
                        nextActivePlayerId: nil
                    )
                )
            )
        )

        let playerState = state.playerGameStates["player-1"]
        XCTAssertEqual(playerState?.availableDivers, 5)
        XCTAssertEqual(playerState?.usedDivers, 1)
        XCTAssertEqual(playerState?.diveSitesReachedBottomThisWeek, [.blue])
        XCTAssertEqual(state.activePlayerId, "player-1")
        XCTAssertEqual(state.currentTurnIndex, 0)
    }

    func testTurnAdvancedReducerAdvancesActivePlayer() {
        let engine = GameEngine()
        var state = playFishState()

        state = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: "player-1",
                        nextPlayerId: "player-2"
                    )
                )
            )
        )

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
                ),
                .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: "player-1",
                        nextPlayerId: "player-2"
                    )
                )
            ]
        )
    }

    func testDiveCreatesPrintedBonusChoiceWhenZoneHasFish() throws {
        let engine = GameEngine()
        var state = playFishState()
        let slotAddress = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .blue,
            rowIndex: 0
        )
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]
        if let slotIndex = state.playerGameStates["player-1"]?.ocean.slots.firstIndex(where: { $0.address == slotAddress }) {
            state.playerGameStates["player-1"]?.ocean.slots[slotIndex].content = .fishCard("fish-9")
        }

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-blue-zone-bonus",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertTrue(
            drafts.contains { draft in
                guard case let .pendingChoiceCreated(choice) = draft else {
                    return false
                }
                return choice.choiceId == "dive-blue-zone-bonus-dive-bonus-0"
                    && choice.kind == .drawFish
                    && choice.diveQueueId != nil
                    && choice.diveStepId != nil
            }
        )
    }

    func testDiveDoesNotCreateZoneBonusChoiceWhenZoneHasNoFish() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-blue-no-zone-bonus",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertFalse(
            drafts.contains { draft in
                if case .pendingChoiceCreated = draft {
                    return true
                }
                return false
            }
        )
    }

    func testDiveBonusRecognizesForageFishInMatchingZone() throws {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "dive-blue-forage-bonus",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        XCTAssertTrue(
            drafts.contains { draft in
                guard case let .pendingChoiceCreated(choice) = draft else {
                    return false
                }
                return choice.choiceId == "dive-blue-forage-bonus-dive-bonus-2"
                    && choice.kind == .drawFish
            }
        )
    }

    func testDiveResolutionQueueCreatesOnlyFirstPendingChoiceInTopToBottomOrder() throws {
        let engine = GameEngine()
        let state = blueDiveQueueState()

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-queue-order"),
            in: state
        )

        XCTAssertEqual(drafts.filter(\.isPendingChoiceCreated).count, 1)
        guard case let .diverMoved(diverMoved) = drafts.first,
              let queue = diverMoved.diveResolutionQueue,
              case let .pendingChoiceCreated(choice) = drafts.last
        else {
            return XCTFail("Expected a dive queue and its first pending choice.")
        }

        XCTAssertEqual(
            queue.steps.map(\.source),
            [
                .printedDiveBonus(.sunlit),
                .printedDiveBonus(.twilight),
                .printedDiveBonus(.midnight),
                .bottomBonus
            ]
        )
        XCTAssertEqual(queue.currentStepIndex, 0)
        XCTAssertFalse(queue.isCompleted)
        XCTAssertEqual(choice.choiceId, queue.currentStep?.pendingChoice.choiceId)
        XCTAssertEqual(choice.kind, .drawFish)
    }

    func testGreenDiveResolutionQueueUsesPrintedHatchAndMoveBonuses() throws {
        let engine = GameEngine()
        let state = diveQueueState(diveSite: .green)

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-green-queue-order", diveSite: .green),
            in: state
        )

        guard case let .diverMoved(diverMoved) = drafts.first,
              let queue = diverMoved.diveResolutionQueue,
              case let .pendingChoiceCreated(choice) = drafts.last
        else {
            return XCTFail("Expected a green dive queue and its first pending choice.")
        }

        XCTAssertEqual(
            queue.steps.map(\.pendingChoice.kind),
            [
                .hatchEgg,
                .hatchEgg,
                .moveYoungOrSchool,
                .moveYoungOrSchool
            ]
        )
        XCTAssertEqual(choice.kind, .hatchEgg)
    }

    func testResolveDiveQueueStepCreatesNextPendingChoiceWithoutAdvancingPlayer() throws {
        let engine = GameEngine()
        var state = applying(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-queue-resolve"),
                in: blueDiveQueueState()
            ),
            to: blueDiveQueueState(),
            using: engine
        )
        state.deckState.fishDrawPile = ["fish-9"]
        let firstChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-dive-queue-first",
                choiceId: firstChoice.choiceId,
                resolution: .draw(count: 1)
            ),
            in: state
        )

        XCTAssertEqual(drafts.count, 2)
        guard case let .pendingChoiceResolved(resolved) = drafts[0],
              case let .advanced(queue) = resolved.diveQueueUpdate,
              case let .pendingChoiceCreated(nextChoice) = drafts[1]
        else {
            return XCTFail("Expected queue advancement and the next pending choice.")
        }
        XCTAssertEqual(queue.currentStepIndex, 1)
        XCTAssertEqual(queue.currentStep?.source, .printedDiveBonus(.twilight))
        XCTAssertEqual(nextChoice.choiceId, queue.currentStep?.pendingChoice.choiceId)
        XCTAssertFalse(drafts.contains(where: \.isTurnCompletion))

        let nextState = applying(drafts, to: state, using: engine)
        XCTAssertEqual(nextState.activePlayerId, "player-1")
        XCTAssertEqual(nextState.activeDiveQueue?.currentStepIndex, 1)
        XCTAssertNil(nextState.pendingChoices[firstChoice.choiceId])
        XCTAssertNotNil(nextState.pendingChoices[nextChoice.choiceId])
    }

    func testSkipDiveQueueStepAlsoCreatesNextPendingChoice() throws {
        let engine = GameEngine()
        let initialState = blueDiveQueueState()
        let state = applying(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-queue-skip"),
                in: initialState
            ),
            to: initialState,
            using: engine
        )
        let firstChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "skip-dive-queue-first",
                choiceId: firstChoice.choiceId,
                resolution: .skip
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = drafts.first,
              case let .advanced(queue) = resolved.diveQueueUpdate,
              case let .pendingChoiceCreated(nextChoice) = drafts.last
        else {
            return XCTFail("Expected skip to advance the dive queue.")
        }
        XCTAssertEqual(queue.currentStepIndex, 1)
        XCTAssertEqual(nextChoice.diveStepId, queue.currentStep?.stepId)
        XCTAssertFalse(drafts.contains(where: \.isTurnCompletion))
    }

    func testDiveQueueCompletesBeforeActivePlayerAdvances() throws {
        let engine = GameEngine()
        let initialState = blueDiveQueueState()
        var state = applying(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-queue-complete"),
                in: initialState
            ),
            to: initialState,
            using: engine
        )

        while let choice = state.pendingChoices.values.first {
            let isLastStep = state.activeDiveQueue?.currentStepIndex == (state.activeDiveQueue?.steps.count ?? 0) - 1
            let drafts = try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "skip-\(choice.choiceId)",
                    choiceId: choice.choiceId,
                    resolution: .skip
                ),
                in: state
            )

            if isLastStep {
                XCTAssertTrue(drafts.contains(where: \.isTurnCompletion))
            } else {
                XCTAssertFalse(drafts.contains(where: \.isTurnCompletion))
            }
            state = applying(drafts, to: state, using: engine)

            if !isLastStep {
                XCTAssertEqual(state.activePlayerId, "player-1")
            }
        }

        XCTAssertNil(state.activeDiveQueue)
        XCTAssertEqual(state.activePlayerId, "player-2")
    }

    func testDiveQueueCompletionEndsWeekWhenAllDiversAreUsed() throws {
        let engine = GameEngine()
        var initialState = blueDiveQueueState()
        initialState.firstPlayerId = "player-1"
        initialState.playerGameStates["player-1"]?.availableDivers = 1
        initialState.playerGameStates["player-2"]?.availableDivers = 0
        var state = applying(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-queue-week-end"),
                in: initialState
            ),
            to: initialState,
            using: engine
        )
        var finalDrafts: [DomainEventDraft] = []

        while let choice = state.pendingChoices.values.first {
            finalDrafts = try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "skip-\(choice.choiceId)",
                    choiceId: choice.choiceId,
                    resolution: .skip
                ),
                in: state
            )
            state = applying(finalDrafts, to: state, using: engine)
        }

        XCTAssertTrue(finalDrafts.contains { draft in
            if case .weekEnded = draft {
                return true
            }
            return false
        })
        XCTAssertNil(state.activeDiveQueue)
        XCTAssertEqual(state.currentWeek, 2)
    }

    func testSecondDiveAtSameSiteOmitsBottomBonusStep() throws {
        let engine = GameEngine()
        var state = blueDiveQueueState()
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-queue-no-second-bottom"),
            in: state
        )

        guard case let .diverMoved(diverMoved) = drafts.first,
              let queue = diverMoved.diveResolutionQueue
        else {
            return XCTFail("Expected zone bonus queue.")
        }
        XCTAssertEqual(
            queue.steps.map(\.source),
            [
                .printedDiveBonus(.sunlit),
                .printedDiveBonus(.twilight),
                .printedDiveBonus(.midnight)
            ]
        )
    }

    func testDiveWithoutSharksAndReefsDoesNotCreateCoralReefOffer() throws {
        let engine = GameEngine()
        let state = coralDiveState(coralReefs: [])

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-no-coral"),
            in: state
        )

        guard case let .diverMoved(diverMoved) = drafts.first else {
            return XCTFail("Expected diverMoved.")
        }
        XCTAssertNil(diverMoved.diveResolutionQueue)
        XCTAssertFalse(drafts.contains(where: \.isPendingChoiceCreated))
    }

    func testDiveWithSharksAndReefsCreatesOneCoralReefOffer() throws {
        let engine = GameEngine()
        let state = coralDiveState()

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-coral"),
            in: state
        )

        guard case let .diverMoved(diverMoved) = drafts.first,
              let queue = diverMoved.diveResolutionQueue,
              case let .pendingChoiceCreated(choice) = drafts.last
        else {
            return XCTFail("Expected coral dive queue.")
        }
        XCTAssertEqual(queue.steps.filter { $0.source == .coralReefOverlay(diveSite: .blue) }.count, 1)
        XCTAssertEqual(choice.kind, .gainCoral)
        XCTAssertEqual(choice.source, .coralReef(.blue))
        XCTAssertEqual(choice.expectedInput, .coralPayment)
    }

    func testFullCoralReefDoesNotCreateGainableCoralOffer() throws {
        let engine = GameEngine()
        let state = coralDiveState(coralCount: 6)

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-full-coral"),
            in: state
        )

        guard case let .diverMoved(diverMoved) = drafts.first else {
            return XCTFail("Expected diverMoved.")
        }
        XCTAssertNil(diverMoved.diveResolutionQueue)
        XCTAssertFalse(drafts.contains(where: \.isPendingChoiceCreated))
    }

    func testSkippingCoralReefOfferDoesNotChangeCoralCount() throws {
        let engine = GameEngine()
        let initialState = coralDiveState()
        var state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-coral-skip"), in: initialState),
            to: initialState,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "skip-coral", choiceId: choice.choiceId, resolution: .skip),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(coralCount(.blue, in: state), 0)
        XCTAssertTrue(drafts.contains { draft in
            guard case let .pendingChoiceResolved(event) = draft else { return false }
            return event.appliedEffects == [.skipCoral(playerId: "player-1", diveSite: .blue)]
        })
    }

    func testPayingEggForCoralReefOfferRemovesEggAndIncreasesCoral() throws {
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3)
        let state = try resolveFirstCoralOffer(
            resolution: .gainCoralWithEgg(source: source),
            sourceResources: [ResourceQuantity(kind: .egg, amount: 1)]
        )

        XCTAssertEqual(resourceAmount(.egg, at: source, in: state), 0)
        XCTAssertEqual(coralCount(.blue, in: state), 1)
    }

    func testCoralReefOfferAlwaysAddsCoralToCurrentDiveSite() throws {
        let cases: [(DiveActionSite, DiveSite, OceanSlotAddress)] = [
            (.blue, .blue, OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3)),
            (.purple, .purple, OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 3)),
            (.green, .green, OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 3))
        ]

        for (diveActionSite, expectedReef, paymentSource) in cases {
            let state = try resolveCoralOffer(
                diveActionSite: diveActionSite,
                resolution: .gainCoralWithEgg(source: paymentSource),
                source: paymentSource,
                sourceResources: [ResourceQuantity(kind: .egg, amount: 1)]
            )

            XCTAssertEqual(coralCount(expectedReef, in: state), 1)
            for reef in DiveSite.allCases where reef != expectedReef {
                XCTAssertEqual(coralCount(reef, in: state), 0)
            }
        }
    }

    func testPayingYoungForCoralReefOfferRemovesYoungAndIncreasesCoral() throws {
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3)
        let state = try resolveFirstCoralOffer(
            resolution: .gainCoralWithYoung(source: source),
            sourceResources: [ResourceQuantity(kind: .young, amount: 1)]
        )

        XCTAssertEqual(resourceAmount(.young, at: source, in: state), 0)
        XCTAssertEqual(coralCount(.blue, in: state), 1)
    }

    func testDiscardingHandCardForCoralReefOfferDiscardsCardAndIncreasesCoral() throws {
        let state = try resolveFirstCoralOffer(
            resolution: .gainCoralByDiscard(cardId: "fish-1"),
            sourceResources: []
        )

        XCTAssertFalse(state.playerGameStates["player-1"]?.hand.contains("fish-1") ?? true)
        XCTAssertEqual(state.playerGameStates["player-1"]?.discardPile, ["fish-1"])
        XCTAssertEqual(coralCount(.blue, in: state), 1)
    }

    func testResolvingCoralReefOfferContinuesDiveQueue() throws {
        let engine = GameEngine()
        let initialState = coralDiveState(includeBottomBonus: true)
        let state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-coral-continues"), in: initialState),
            to: initialState,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "resolve-coral-continues", choiceId: choice.choiceId, resolution: .skip),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = drafts.first,
              case let .advanced(queue) = resolved.diveQueueUpdate,
              case let .pendingChoiceCreated(nextChoice) = drafts.last
        else {
            return XCTFail("Expected coral skip to advance to next dive queue step.")
        }
        XCTAssertEqual(queue.currentStep?.source, .bottomBonus)
        XCTAssertEqual(nextChoice.choiceId, queue.currentStep?.pendingChoice.choiceId)
    }

    func testGainCoralAbilityResolvesFromBuiltInRegistry() {
        let card = Card(
            id: "fixture-blue-coral",
            name: "Blue Coral Fixture",
            abilityIds: [SharksAndReefsAbilityIDs.blueCoralIfActivated]
        )

        let abilities = AbilityResolver().abilityDefinitions(for: card)

        XCTAssertEqual(abilities.map(\.abilityId), [SharksAndReefsAbilityIDs.blueCoralIfActivated])
        XCTAssertEqual(abilities.first?.effects, [.gainCoral(selector: .blue, count: 1)])
    }

    func testWhenPlayedGainCoralAbilityCreatesCompoundPendingChoice() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand.append("sr.main.194")
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "play-blue-purple-coral", cardId: "sr.main.194", targetSlot: target),
            in: state
        )

        guard case let .pendingChoiceCreated(choice) = drafts.last else {
            return XCTFail("Expected a when-played compound pending choice.")
        }
        XCTAssertEqual(choice.kind, .compoundAbility)
        XCTAssertEqual(choice.expectedInput, .abilityEffectSelection)
        XCTAssertEqual(choice.abilityDefinition?.abilityId, SharksAndReefsAbilityIDs.bluePurpleCoralWhenPlayed)
        XCTAssertEqual(
            choice.compoundAbilityProgress?.remainingEffects,
            [
                .gainCoral(selector: .blue, count: 1),
                .gainCoral(selector: .purple, count: 1)
            ]
        )
    }

    func testWhenPlayedGainCoralCompoundChoiceCreatesFreeCoralTargetChoice() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand.append("sr.main.194")
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        state = applying(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "play-compound-coral", cardId: "sr.main.194", targetSlot: target),
                in: state
            ),
            to: state,
            using: engine
        )
        let compoundChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "choose-blue-coral",
                choiceId: compoundChoice.choiceId,
                resolution: .chooseAbilityEffect(.gainCoral(selector: .blue, count: 1))
            ),
            in: state
        )

        guard case let .pendingChoiceCreated(targetChoice) = drafts.last else {
            return XCTFail("Expected a target gain coral pending choice.")
        }
        XCTAssertEqual(targetChoice.kind, .gainCoral)
        XCTAssertEqual(targetChoice.expectedInput, .coralPlacement)
        XCTAssertEqual(targetChoice.selectedAbilityEffect, .gainCoral(selector: .blue, count: 1))
    }

    func testSpecificGainCoralAbilityResolveIncrementsCoralWithoutPayment() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        let choice = gainCoralAbilityPendingChoice(selector: .blue, cardId: "sr.main.171")
        state.pendingChoices[choice.choiceId] = choice
        let startingHand = state.playerGameStates["player-1"]?.hand
        let startingDiscard = state.playerGameStates["player-1"]?.discardPile

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-blue-coral-ability",
                choiceId: choice.choiceId,
                resolution: .gainCoralFromAbility(diveSite: .blue)
            ),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(coralCount(.blue, in: state), 1)
        XCTAssertEqual(state.playerGameStates["player-1"]?.hand, startingHand)
        XCTAssertEqual(state.playerGameStates["player-1"]?.discardPile, startingDiscard)
        XCTAssertTrue(drafts.contains { draft in
            guard case let .pendingChoiceResolved(event) = draft else { return false }
            return event.appliedEffects == [
                .gainCoralFromAbility(playerId: "player-1", diveSite: .blue, sourceCardId: "sr.main.171")
            ]
        })
    }

    func testAnyGainCoralAbilityCanChooseAnyNotFullDiveSite() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        let choice = gainCoralAbilityPendingChoice(selector: .any, cardId: "sr.main.210")
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-any-coral-ability",
                choiceId: choice.choiceId,
                resolution: .gainCoralFromAbility(diveSite: .green)
            ),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(coralCount(.green, in: state), 1)
        XCTAssertEqual(coralCount(.blue, in: state), 0)
    }

    func testGainCoralAbilityRejectsFullCoralReef() {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.ocean.coralReefs = [
            CoralReefState(diveSite: .blue, coralCount: 6, maxCoral: 6, completionBonus: 6)
        ]
        let choice = gainCoralAbilityPendingChoice(selector: .blue, cardId: "sr.main.171")
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "resolve-full-coral-ability",
                    choiceId: choice.choiceId,
                    resolution: .gainCoralFromAbility(diveSite: .blue)
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
        }
    }

    func testSkippingGainCoralAbilityDoesNotChangeCoral() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        let choice = gainCoralAbilityPendingChoice(selector: .blue, cardId: "sr.main.171")
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "skip-coral-ability", choiceId: choice.choiceId, resolution: .skip),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(coralCount(.blue, in: state), 0)
    }

    func testIfActivatedGainCoralAbilityCreatesDiveQueuePendingChoice() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = abilityDiveState(cardId: "sr.main.171")
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-blue-coral-ability"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "skip-printed-before-coral-ability",
                    choiceId: printedChoice.choiceId,
                    resolution: .skip
                ),
                in: state
            ),
            to: state,
            using: engine
        )

        let abilityChoice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(abilityChoice.kind, .gainCoral)
        XCTAssertEqual(abilityChoice.expectedInput, .coralPlacement)
        XCTAssertEqual(abilityChoice.abilityDefinition?.abilityId, SharksAndReefsAbilityIDs.blueCoralIfActivated)
    }

    func testIfActivatedGainCoralAbilityResolveContinuesDiveQueue() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = abilityDiveState(cardId: "sr.main.171")
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-blue-coral-resolve"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "skip-printed-before-coral-resolve",
                    choiceId: printedChoice.choiceId,
                    resolution: .skip
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        let abilityChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-if-activated-coral",
                choiceId: abilityChoice.choiceId,
                resolution: .gainCoralFromAbility(diveSite: .blue)
            ),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(coralCount(.blue, in: state), 1)
        XCTAssertTrue(drafts.contains { draft in
            guard case let .pendingChoiceResolved(event) = draft else { return false }
            return event.diveQueueUpdate != nil
        })
    }

    func testCoralReefOverlayCannotUseFreeGainCoralAbilityResolution() throws {
        let engine = GameEngine()
        var state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-coral-free-rejected"), in: coralDiveState()),
            to: coralDiveState(),
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "reject-free-coral-overlay",
                    choiceId: choice.choiceId,
                    resolution: .gainCoralFromAbility(diveSite: .blue)
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
        }
    }

    func testScatterSchoolAbilityIdResolvesFromRealSharksAndReefsCatalog() throws {
        let catalog = try SharksAndReefsCardCatalog()
        let card = try XCTUnwrap(catalog.fishCards.first { $0.id == "sr.main.142" })

        let abilities = AbilityResolver().abilityDefinitions(for: card)

        XCTAssertEqual(card.name, "Blacktip Shark")
        XCTAssertEqual(card.abilityText, "[GreenCoral][UnSchoolFish]")
        XCTAssertEqual(card.abilityIds, [SharksAndReefsAbilityIDs.greenCoralScatterSchoolWhenPlayed])
        XCTAssertEqual(abilities.first?.trigger, .whenPlayed)
        XCTAssertEqual(
            abilities.first?.effects,
            [
                .gainCoral(selector: .green, count: 1),
                .scatterSchool(count: 1)
            ]
        )
    }

    func testConsumeFishFromHandAbilityIdsResolveFromRealSharksAndReefsCatalog() throws {
        let catalog = try SharksAndReefsCardCatalog()
        let whenPlayedCard = try XCTUnwrap(catalog.fishCards.first { $0.id == "sr.main.136" })
        let ifActivatedCard = try XCTUnwrap(catalog.fishCards.first { $0.id == "sr.main.152" })

        let whenPlayedAbilities = AbilityResolver().abilityDefinitions(for: whenPlayedCard)
        let ifActivatedAbilities = AbilityResolver().abilityDefinitions(for: ifActivatedCard)

        XCTAssertEqual(whenPlayedCard.name, "American Pocket Shark")
        XCTAssertEqual(whenPlayedCard.abilityText, "[FishFromHandConsume][FishFromHandConsume]")
        XCTAssertEqual(whenPlayedCard.abilityIds, [SharksAndReefsAbilityIDs.consumeFishFromHandTwiceWhenPlayed])
        XCTAssertEqual(whenPlayedAbilities.first?.trigger, .whenPlayed)
        XCTAssertEqual(
            whenPlayedAbilities.first?.effects,
            [.consumeFishFromHand(count: 1), .consumeFishFromHand(count: 1)]
        )
        XCTAssertEqual(ifActivatedCard.name, "Filetail Catshark")
        XCTAssertEqual(ifActivatedCard.abilityText, "[FishFromHandConsume]")
        XCTAssertEqual(ifActivatedCard.abilityIds, [SharksAndReefsAbilityIDs.consumeFishFromHandIfActivated])
        XCTAssertEqual(ifActivatedAbilities.first?.trigger, .ifActivated)
        XCTAssertEqual(ifActivatedAbilities.first?.effects, [.consumeFishFromHand(count: 1)])
    }

    func testWhenPlayedConsumeFishFromHandCreatesPendingChoice() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand.append("sr.main.136")
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        state = applying(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "play-consume-fish", cardId: "sr.main.136", targetSlot: target),
                in: state
            ),
            to: state,
            using: engine
        )
        let compoundChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "choose-consume-fish",
                choiceId: compoundChoice.choiceId,
                resolution: .chooseAbilityEffect(.consumeFishFromHand(count: 1))
            ),
            in: state
        )

        guard case let .pendingChoiceCreated(consumeChoice) = drafts.last else {
            return XCTFail("Expected consume fish from hand pending choice.")
        }
        XCTAssertEqual(consumeChoice.kind, .consumeFishFromHand)
        XCTAssertEqual(consumeChoice.expectedInput, .consumeFishConsumer)
        XCTAssertEqual(consumeChoice.selectedAbilityEffect, .consumeFishFromHand(count: 1))
    }

    func testIfActivatedConsumeFishFromHandCreatesDiveQueuePendingChoice() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = abilityDiveState(cardId: "sr.main.152")
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-if-consume"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-printed-before-consume", choiceId: printedChoice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )

        let consumeChoice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(consumeChoice.kind, .consumeFishFromHand)
        XCTAssertEqual(consumeChoice.expectedInput, .consumeFishConsumer)
        XCTAssertEqual(consumeChoice.abilityDefinition?.abilityId, SharksAndReefsAbilityIDs.consumeFishFromHandIfActivated)
    }

    func testConsumeFishFromHandRequiresVisibleFishCardConsumer() throws {
        let engine = GameEngine(cardCatalog: consumeFishCatalog())
        let consumer = consumeFishConsumerAddress()
        let empty = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        let forage = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 0)
        var state = consumeFishState(hand: ["consume.short"])
        setContent(
            .forageFish(
                ForageFish(
                    forageFishId: "fixture-forage",
                    name: "Fixture Forage",
                    lengthCm: 5,
                    diveSite: .green,
                    rowIndex: 0
                )
            ),
            at: forage,
            in: &state
        )
        let choice = consumeFishPendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "consume-empty", choiceId: choice.choiceId, resolution: .chooseConsumeFishConsumer(empty)),
                in: state
            )
        )
        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "consume-forage", choiceId: choice.choiceId, resolution: .chooseConsumeFishConsumer(forage)),
                in: state
            )
        )

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "consume-consumer", choiceId: choice.choiceId, resolution: .chooseConsumeFishConsumer(consumer)),
            in: state
        )
        guard case let .pendingChoiceCreated(nextChoice) = drafts.last else {
            return XCTFail("Expected hand-card pending choice.")
        }
        XCTAssertEqual(nextChoice.expectedInput, .consumeFishHandCard)
        XCTAssertEqual(nextChoice.consumeFishFromHandProgress?.consumerSlot, consumer)
    }

    func testConsumeFishFromHandOnlyAllowsShorterHandFish() throws {
        let engine = GameEngine(cardCatalog: consumeFishCatalog())
        let consumer = consumeFishConsumerAddress()
        var state = consumeFishState(hand: ["consume.short", "consume.same", "consume.long"])
        let choice = consumeFishPendingChoice(
            expectedInput: .consumeFishHandCard,
            progress: ConsumeFishFromHandProgress(consumerSlot: consumer)
        )
        state.pendingChoices[choice.choiceId] = choice

        for cardId in ["consume.same", "consume.long"] {
            XCTAssertThrowsError(
                try engine.makeEventDrafts(
                    for: resolveCommand(
                        commandId: "consume-invalid-\(cardId)",
                        choiceId: choice.choiceId,
                        resolution: .consumeFishFromHand(cardId)
                    ),
                    in: state
                )
            ) { error in
                XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
            }
        }

        XCTAssertNoThrow(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "consume-short",
                    choiceId: choice.choiceId,
                    resolution: .consumeFishFromHand("consume.short")
                ),
                in: state
            )
        )
    }

    func testConsumeFishFromHandRemovesHandCardAndAppendsConsumedFishWithoutDiscarding() throws {
        let engine = GameEngine(cardCatalog: consumeFishCatalog())
        let consumer = consumeFishConsumerAddress()
        var state = consumeFishState(hand: ["consume.short", "consume.long"])
        setConsumedFish([ConsumedFish(cardId: "already-consumed")], at: consumer, in: &state)
        state.playerGameStates["player-1"]?.discardPile = ["discard-existing"]
        let choice = consumeFishPendingChoice(
            expectedInput: .consumeFishHandCard,
            progress: ConsumeFishFromHandProgress(consumerSlot: consumer)
        )
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "consume-short-reducer",
                    choiceId: choice.choiceId,
                    resolution: .consumeFishFromHand("consume.short")
                ),
                in: state
            ),
            to: state,
            using: engine
        )

        let playerState = try XCTUnwrap(state.playerGameStates["player-1"])
        let slot = try XCTUnwrap(playerState.ocean.slots.first { $0.address == consumer })
        XCTAssertEqual(playerState.hand, ["consume.long"])
        XCTAssertEqual(playerState.discardPile, ["discard-existing"])
        XCTAssertEqual(slot.consumedFish.first, ConsumedFish(cardId: "already-consumed"))
        XCTAssertEqual(slot.consumedFish.last, ConsumedFish(cardId: "consume.short", lengthCm: 10))
    }

    func testSkippingConsumeFishFromHandDoesNotRemoveHandCardOrAppendConsumedFish() throws {
        let engine = GameEngine(cardCatalog: consumeFishCatalog())
        let consumer = consumeFishConsumerAddress()
        var state = consumeFishState(hand: ["consume.short"])
        setConsumedFish([ConsumedFish(cardId: "already-consumed")], at: consumer, in: &state)
        let choice = consumeFishPendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-consume", choiceId: choice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )

        let playerState = try XCTUnwrap(state.playerGameStates["player-1"])
        let slot = try XCTUnwrap(playerState.ocean.slots.first { $0.address == consumer })
        XCTAssertEqual(playerState.hand, ["consume.short"])
        XCTAssertEqual(slot.consumedFish, [ConsumedFish(cardId: "already-consumed")])
    }

    func testConsumeFishFromHandResolveContinuesDiveQueue() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        let consumer = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        var state = abilityDiveState(cardId: "sr.main.152")
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = []
        state.playerGameStates["player-1"]?.hand.append("fish-1")
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-consume-continues"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-before-consume-continues", choiceId: printedChoice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )
        var consumeChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "choose-consumer-continues",
                    choiceId: consumeChoice.choiceId,
                    resolution: .chooseConsumeFishConsumer(consumer)
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        consumeChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-consume-continues",
                choiceId: consumeChoice.choiceId,
                resolution: .consumeFishFromHand("fish-1")
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = drafts.first,
              case let .advanced(queue) = resolved.diveQueueUpdate,
              case let .pendingChoiceCreated(nextChoice) = drafts.last
        else {
            return XCTFail("Expected consume fish from hand to advance to the next dive queue step.")
        }
        XCTAssertEqual(queue.currentStep?.source, .bottomBonus)
        XCTAssertEqual(nextChoice.choiceId, queue.currentStep?.pendingChoice.choiceId)
    }

    func testPlayFishForFreeAbilityIdsResolveFromRealSharksAndReefsCatalog() throws {
        let catalog = try SharksAndReefsCardCatalog()
        let lollipop = try XCTUnwrap(catalog.fishCards.first { $0.id == "sr.main.170" })
        let swell = try XCTUnwrap(catalog.fishCards.first { $0.id == "sr.main.200" })

        let lollipopAbility = AbilityResolver().abilityDefinitions(for: lollipop).first
        let swellAbility = AbilityResolver().abilityDefinitions(for: swell).first

        XCTAssertEqual(lollipop.name, "Lollipop Catshark")
        XCTAssertEqual(lollipop.abilityText, "[FreePlayFishFromHand][FishLengthSmall] only")
        XCTAssertEqual(lollipopAbility?.effects, [.playFishForFree(filter: .lengthBucket(.small), count: 1)])
        XCTAssertEqual(swell.name, "Swell Shark")
        XCTAssertEqual(swell.abilityText, "[FreePlayFishFromHand][Camouflage] only")
        XCTAssertEqual(swellAbility?.effects, [.playFishForFree(filter: .tag("camouflage"), count: 1)])
    }

    func testWhenPlayedPlayFishForFreeCreatesPendingChoice() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand.append("sr.main.170")
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: playFishCommand(commandId: "play-free-ability", cardId: "sr.main.170", targetSlot: target),
            in: state
        )

        guard case let .pendingChoiceCreated(choice) = drafts.last else {
            return XCTFail("Expected play fish for free pending choice.")
        }
        XCTAssertEqual(choice.kind, .playFishForFree)
        XCTAssertEqual(choice.expectedInput, .freePlayHandCard)
        XCTAssertEqual(choice.abilityDefinition?.abilityId, SharksAndReefsAbilityIDs.freePlaySmallWhenPlayed)
    }

    func testIfActivatedPlayFishForFreeCreatesDiveQueuePendingChoice() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeIfActivatedCatalog(), abilityResolver: playFishForFreeIfActivatedResolver())
        var state = abilityDiveState(cardId: "fixture.if.free")
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-if-free"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-printed-before-free", choiceId: printedChoice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )

        let freeChoice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(freeChoice.kind, .playFishForFree)
        XCTAssertEqual(freeChoice.expectedInput, .freePlayHandCard)
    }

    func testPlayFishForFreeHandSelectionRequiresMatchingFilterAndCreatesTargetChoice() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeCatalog())
        var state = playFishForFreeState(hand: ["free.small", "free.medium"])
        let choice = playFishForFreePendingChoice(filter: .lengthBucket(.small))
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "free-medium-rejected", choiceId: choice.choiceId, resolution: .chooseFreePlayFish("free.medium")),
                in: state
            )
        )

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "free-small-selected", choiceId: choice.choiceId, resolution: .chooseFreePlayFish("free.small")),
            in: state
        )
        guard case let .pendingChoiceCreated(nextChoice) = drafts.last else {
            return XCTFail("Expected free play target choice.")
        }
        XCTAssertEqual(nextChoice.expectedInput, .freePlayTargetSlot)
        XCTAssertEqual(nextChoice.playFishForFreeProgress?.selectedCardId, "free.small")
    }

    func testPlayFishForFreeDoesNotPayCostsAndPlacesFish() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeCatalog())
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let eggSource = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3)
        var state = playFishForFreeState(hand: ["free.costly", "discard-candidate"])
        setResources([ResourceQuantity(kind: .egg, amount: 1), ResourceQuantity(kind: .young, amount: 1)], at: eggSource, in: &state)
        let choice = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.costly")
        )
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "free-costly",
                    choiceId: choice.choiceId,
                    resolution: .playFishForFree(cardId: "free.costly", targetSlot: target)
                ),
                in: state
            ),
            to: state,
            using: engine
        )

        let playerState = try XCTUnwrap(state.playerGameStates["player-1"])
        XCTAssertEqual(playerState.hand, ["discard-candidate"])
        XCTAssertEqual(playerState.discardPile, [])
        XCTAssertEqual(resourceAmount(.egg, at: eggSource, in: state), 1)
        XCTAssertEqual(resourceAmount(.young, at: eggSource, in: state), 1)
        XCTAssertEqual(playerState.ocean.slots.first { $0.address == target }?.content, .fishCard("free.costly"))
    }

    func testPlayFishForFreeStillChecksPlacementRules() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeCatalog())
        let twilight = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 3)
        let wrongColor = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let coverEmpty = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        var state = playFishForFreeState(hand: ["free.sunlight", "free.green", "free.cover"])
        let choice = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.sunlight")
        )
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "free-zone", choiceId: choice.choiceId, resolution: .playFishForFree(cardId: "free.sunlight", targetSlot: twilight)),
                in: state
            )
        )

        state.pendingChoices[choice.choiceId] = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.green")
        )
        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "free-color", choiceId: choice.choiceId, resolution: .playFishForFree(cardId: "free.green", targetSlot: wrongColor)),
                in: state
            )
        )

        state.pendingChoices[choice.choiceId] = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.cover")
        )
        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "free-cover", choiceId: choice.choiceId, resolution: .playFishForFree(cardId: "free.cover", targetSlot: coverEmpty)),
                in: state
            )
        )
    }

    func testPlayFishForFreeStillChecksCoralRequirement() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeCatalog())
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        var state = playFishForFreeState(hand: ["free.reef"])
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        let choice = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.reef")
        )
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "free-reef-insufficient", choiceId: choice.choiceId, resolution: .playFishForFree(cardId: "free.reef", targetSlot: target)),
                in: state
            )
        )

        state.playerGameStates["player-1"]?.ocean.coralReefs = [
            CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6)
        ]
        XCTAssertNoThrow(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "free-reef-ok", choiceId: choice.choiceId, resolution: .playFishForFree(cardId: "free.reef", targetSlot: target)),
                in: state
            )
        )
    }

    func testPlayFishForFreeCoveringShorterFishAppendsConsumedFish() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeCatalog())
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        var state = playFishForFreeState(hand: ["free.cover"])
        setContent(.fishCard("free.small"), at: target, in: &state)
        setConsumedFish([ConsumedFish(cardId: "already-consumed")], at: target, in: &state)
        let choice = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.cover")
        )
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "free-cover-consume", choiceId: choice.choiceId, resolution: .playFishForFree(cardId: "free.cover", targetSlot: target)),
                in: state
            ),
            to: state,
            using: engine
        )

        let slot = try XCTUnwrap(state.playerGameStates["player-1"]?.ocean.slots.first { $0.address == target })
        XCTAssertEqual(slot.content, .fishCard("free.cover"))
        XCTAssertEqual(slot.consumedFish.first, ConsumedFish(cardId: "already-consumed"))
        XCTAssertEqual(slot.consumedFish.last, ConsumedFish(cardId: "free.small", lengthCm: 10))
    }

    func testSkippingPlayFishForFreeDoesNotMoveHandCard() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeCatalog())
        var state = playFishForFreeState(hand: ["free.small"])
        let choice = playFishForFreePendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-free-play", choiceId: choice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(state.playerGameStates["player-1"]?.hand, ["free.small"])
        XCTAssertTrue(state.pendingChoices.isEmpty)
    }

    func testPlayFishForFreeTriggersWhenPlayedAbilityOfFreePlayedFish() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeCatalog(), abilityResolver: playFishForFreeResolver())
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        var state = playFishForFreeState(hand: ["free.withAbility"])
        let choice = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.withAbility")
        )
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "free-trigger-when-played",
                choiceId: choice.choiceId,
                resolution: .playFishForFree(cardId: "free.withAbility", targetSlot: target)
            ),
            in: state
        )

        guard case let .pendingChoiceCreated(nextChoice) = drafts.last else {
            return XCTFail("Expected free-played fish's WHEN PLAYED ability to trigger.")
        }
        XCTAssertEqual(nextChoice.kind, .drawFish)
        XCTAssertEqual(nextChoice.source, .fishAbility("free.withAbility"))
    }

    func testPlayFishForFreeResolveContinuesDiveQueue() throws {
        let engine = GameEngine(cardCatalog: playFishForFreeIfActivatedCatalog(), abilityResolver: playFishForFreeIfActivatedResolver())
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        var state = abilityDiveState(cardId: "fixture.if.free")
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = []
        state.playerGameStates["player-1"]?.hand.append("free.small")
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-free-continues"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-before-free-continues", choiceId: printedChoice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )
        var freeChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "choose-free-fish-continues", choiceId: freeChoice.choiceId, resolution: .chooseFreePlayFish("free.small")),
                in: state
            ),
            to: state,
            using: engine
        )
        freeChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-free-continues",
                choiceId: freeChoice.choiceId,
                resolution: .playFishForFree(cardId: "free.small", targetSlot: target)
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = drafts.first,
              case let .advanced(queue) = resolved.diveQueueUpdate,
              case let .pendingChoiceCreated(nextChoice) = drafts.last
        else {
            return XCTFail("Expected free play to advance to the next dive queue step.")
        }
        XCTAssertEqual(queue.currentStep?.source, .bottomBonus)
        XCTAssertEqual(nextChoice.choiceId, queue.currentStep?.pendingChoice.choiceId)
    }

    func testWhenPlayedScatterSchoolCreatesPendingChoice() throws {
        let engine = GameEngine(cardCatalog: sharksAndReefsAbilityCatalog())
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand.append("sr.main.142")
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        state = applying(
            try engine.makeEventDrafts(
                for: playFishCommand(commandId: "play-scatter-school", cardId: "sr.main.142", targetSlot: target),
                in: state
            ),
            to: state,
            using: engine
        )
        let compoundChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "choose-scatter-school",
                choiceId: compoundChoice.choiceId,
                resolution: .chooseAbilityEffect(.scatterSchool(count: 1))
            ),
            in: state
        )

        guard case let .pendingChoiceCreated(scatterChoice) = drafts.last else {
            return XCTFail("Expected scatter school pending choice.")
        }
        XCTAssertEqual(scatterChoice.kind, .scatterSchool)
        XCTAssertEqual(scatterChoice.expectedInput, .scatterSchoolSource)
        XCTAssertEqual(scatterChoice.selectedAbilityEffect, .scatterSchool(count: 1))
    }

    func testIfActivatedScatterSchoolCreatesDiveQueuePendingChoice() throws {
        let engine = GameEngine(cardCatalog: scatterSchoolIfActivatedCatalog(), abilityResolver: scatterSchoolIfActivatedResolver())
        var state = abilityDiveState(cardId: "fixture.if.scatter")
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-if-scatter"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-printed-before-scatter", choiceId: printedChoice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )

        let scatterChoice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(scatterChoice.kind, .scatterSchool)
        XCTAssertEqual(scatterChoice.abilityDefinition?.effects, [.scatterSchool(count: 1)])
    }

    func testScatterSchoolWithSchoolRequiresSchoolSourceAndRemovesIt() throws {
        let engine = GameEngine()
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 2)
        var state = playFishState()
        setResources([ResourceQuantity(kind: .school, amount: 1)], at: source, in: &state)
        let choice = scatterSchoolPendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "scatter-source", choiceId: choice.choiceId, resolution: .chooseScatterSchoolSource(source)),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(resourceAmount(.school, at: source, in: state), 0)
        let nextChoice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(nextChoice.expectedInput, .scatterSchoolYoungTarget)
        XCTAssertEqual(nextChoice.scatterSchoolProgress?.requiredTargetCount, 4)
        XCTAssertEqual(nextChoice.scatterSchoolProgress?.completedTargetCount, 0)
    }

    func testScatterSchoolWithSchoolPlacesYoungInFourDifferentSlotsAndCompletes() throws {
        let engine = GameEngine()
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 2)
        let targets = scatterSchoolTargets()
        var state = playFishState()
        setResources([ResourceQuantity(kind: .school, amount: 1)], at: source, in: &state)
        let choice = scatterSchoolPendingChoice()
        state.pendingChoices[choice.choiceId] = choice
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "scatter-source-four", choiceId: choice.choiceId, resolution: .chooseScatterSchoolSource(source)),
                in: state
            ),
            to: state,
            using: engine
        )

        for (index, target) in targets.enumerated() {
            let activeChoice = try XCTUnwrap(state.pendingChoices.values.first)
            state = applying(
                try engine.makeEventDrafts(
                    for: resolveCommand(
                        commandId: "scatter-young-\(index)",
                        choiceId: activeChoice.choiceId,
                        resolution: .placeScatterSchoolYoung(target)
                    ),
                    in: state
                ),
                to: state,
                using: engine
            )
        }

        for target in targets {
            XCTAssertEqual(resourceAmount(.young, at: target, in: state), 1)
        }
        XCTAssertTrue(state.pendingChoices.isEmpty)
    }

    func testScatterSchoolRejectsDuplicateYoungTarget() throws {
        let engine = GameEngine()
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 2)
        let target = scatterSchoolTargets()[0]
        var state = playFishState()
        setResources([ResourceQuantity(kind: .school, amount: 1)], at: source, in: &state)
        let choice = scatterSchoolPendingChoice()
        state.pendingChoices[choice.choiceId] = choice
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "scatter-source-duplicate", choiceId: choice.choiceId, resolution: .chooseScatterSchoolSource(source)),
                in: state
            ),
            to: state,
            using: engine
        )
        var activeChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "scatter-first-target", choiceId: activeChoice.choiceId, resolution: .placeScatterSchoolYoung(target)),
                in: state
            ),
            to: state,
            using: engine
        )
        activeChoice = try XCTUnwrap(state.pendingChoices.values.first)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "scatter-duplicate-target", choiceId: activeChoice.choiceId, resolution: .placeScatterSchoolYoung(target)),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(activeChoice.choiceId))
        }
    }

    func testScatterSchoolWithoutSchoolPlacesOneYoung() throws {
        let engine = GameEngine()
        let target = scatterSchoolTargets()[0]
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        let choice = scatterSchoolPendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "scatter-no-school", choiceId: choice.choiceId, resolution: .placeScatterSchoolYoung(target)),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(resourceAmount(.young, at: target, in: state), 1)
        XCTAssertTrue(state.pendingChoices.isEmpty)
    }

    func testSkippingScatterSchoolDoesNotRemoveSchoolOrPlaceYoung() throws {
        let engine = GameEngine()
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 2)
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        setResources([ResourceQuantity(kind: .school, amount: 1)], at: source, in: &state)
        let choice = scatterSchoolPendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-scatter", choiceId: choice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(resourceAmount(.school, at: source, in: state), 1)
        XCTAssertEqual(totalResourceAmount(.young, in: state), 0)
    }

    func testScatterSchoolYoungPlacementStillFormsSchoolAtThreeYoung() throws {
        let engine = GameEngine()
        let target = scatterSchoolTargets()[0]
        var state = playFishState()
        clearResources(for: "player-1", in: &state)
        setResources([ResourceQuantity(kind: .young, amount: 2)], at: target, in: &state)
        let choice = scatterSchoolPendingChoice()
        state.pendingChoices[choice.choiceId] = choice

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "scatter-form-school", choiceId: choice.choiceId, resolution: .placeScatterSchoolYoung(target)),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(resourceAmount(.young, at: target, in: state), 0)
        XCTAssertEqual(resourceAmount(.school, at: target, in: state), 1)
    }

    func testScatterSchoolResolveContinuesDiveQueue() throws {
        let engine = GameEngine(cardCatalog: scatterSchoolIfActivatedCatalog(), abilityResolver: scatterSchoolIfActivatedResolver())
        var state = abilityDiveState(cardId: "fixture.if.scatter")
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = []
        clearResources(for: "player-1", in: &state)
        state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-scatter-continues"), in: state),
            to: state,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-before-scatter-continues", choiceId: printedChoice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )
        let scatterChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-scatter-continues",
                choiceId: scatterChoice.choiceId,
                resolution: .placeScatterSchoolYoung(scatterSchoolTargets()[0])
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = drafts.first,
              case let .advanced(queue) = resolved.diveQueueUpdate,
              case let .pendingChoiceCreated(nextChoice) = drafts.last
        else {
            return XCTFail("Expected scatter school to advance to the next dive queue step.")
        }
        XCTAssertEqual(queue.currentStep?.source, .bottomBonus)
        XCTAssertEqual(nextChoice.choiceId, queue.currentStep?.pendingChoice.choiceId)
    }

    func testActiveDiveQueuePreventsPlayFishAndDive() throws {
        let engine = GameEngine()
        let initialState = blueDiveQueueState()
        let state = applying(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-queue-blocking"),
                in: initialState
            ),
            to: initialState,
            using: engine
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "play-during-dive-queue",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(cardId: "fish-6", targetSlot: target, payment: .empty)
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .unresolvedPendingChoices("player-1"))
        }

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-during-dive-queue"),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .unresolvedPendingChoices("player-1"))
        }
    }

    func testBaseGameDiveBonusLayoutMatchesPrintedBonuses() {
        let layout = DiveSiteBonusLayout.baseGame

        XCTAssertEqual(layout.bonuses(for: .blue), [
            DiveBonusDefinition(diveSite: .blue, position: .zone(.sunlit), kind: .drawFish, amount: 1),
            DiveBonusDefinition(diveSite: .blue, position: .zone(.twilight), kind: .drawFish, amount: 1),
            DiveBonusDefinition(diveSite: .blue, position: .zone(.midnight), kind: .drawFish, amount: 1),
            DiveBonusDefinition(diveSite: .blue, position: .bottom, kind: .recoverFromDiscardOrDraw, amount: 1)
        ])
        XCTAssertEqual(layout.bonuses(for: .green), [
            DiveBonusDefinition(diveSite: .green, position: .zone(.sunlit), kind: .hatchEgg, amount: 1),
            DiveBonusDefinition(diveSite: .green, position: .zone(.twilight), kind: .hatchEgg, amount: 1),
            DiveBonusDefinition(diveSite: .green, position: .zone(.midnight), kind: .moveYoungOrSchool, amount: 1),
            DiveBonusDefinition(diveSite: .green, position: .bottom, kind: .moveYoungOrSchool, amount: 1)
        ])
        XCTAssertEqual(layout.bonuses(for: .purple), [
            DiveBonusDefinition(diveSite: .purple, position: .zone(.sunlit), kind: .placeEgg, amount: 1),
            DiveBonusDefinition(diveSite: .purple, position: .zone(.twilight), kind: .placeEgg, amount: 1),
            DiveBonusDefinition(diveSite: .purple, position: .zone(.midnight), kind: .placeEgg, amount: 1),
            DiveBonusDefinition(diveSite: .purple, position: .bottom, kind: .placeEgg, amount: 1)
        ])
    }

    func testRecoverFromDiscardChoiceMovesSelectedCardToHand() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .recoverFromDiscardOrDraw)
        state.pendingChoices[choice.choiceId] = choice
        state.playerGameStates["player-1"]?.discardPile = ["fish-9"]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "recover-discard",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .recoverCard("fish-9")
                    )
                )
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(payload) = drafts.first else {
            return XCTFail("Expected pendingChoiceResolved.")
        }
        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(payload)
            )
        )

        XCTAssertEqual(payload.appliedEffects, [.recoverFromDiscard(playerId: "player-1", cardId: "fish-9")])
        XCTAssertTrue(nextState.playerGameStates["player-1"]?.hand.contains("fish-9") == true)
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.discardPile, [])
    }

    func testRecoverFromDiscardChoiceDrawsFromDeckWhenDiscardIsEmpty() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .recoverFromDiscardOrDraw)
        state.pendingChoices[choice.choiceId] = choice
        state.playerGameStates["player-1"]?.discardPile = []
        state.deckState.fishDrawPile = ["fish-9", "fish-10"]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "recover-draw",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .drawFromDeck
                    )
                )
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(payload) = drafts.first else {
            return XCTFail("Expected pendingChoiceResolved.")
        }
        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(payload)
            )
        )

        XCTAssertEqual(payload.appliedEffects, [.drawFish(playerId: "player-1", cardIds: ["fish-9"])])
        XCTAssertTrue(nextState.playerGameStates["player-1"]?.hand.contains("fish-9") == true)
        XCTAssertEqual(nextState.deckState.fishDrawPile, ["fish-10"])
    }

    func testSkipRecoverFromDiscardChoiceDoesNotChangeHandDiscardOrDeck() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .recoverFromDiscardOrDraw)
        state.pendingChoices[choice.choiceId] = choice
        state.playerGameStates["player-1"]?.discardPile = ["fish-9"]
        state.deckState.fishDrawPile = ["fish-10"]
        let startingHand = state.playerGameStates["player-1"]?.hand

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "recover-skip",
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

        guard case let .pendingChoiceResolved(payload) = drafts.first else {
            return XCTFail("Expected pendingChoiceResolved.")
        }
        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(payload)
            )
        )

        XCTAssertEqual(payload.appliedEffects, [.none])
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.hand, startingHand)
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.discardPile, ["fish-9"])
        XCTAssertEqual(nextState.deckState.fishDrawPile, ["fish-10"])
    }

    func testMoveYoungMovesOneYoungToTarget() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        state.pendingChoices[choice.choiceId] = choice
        setResources([ResourceQuantity(kind: .young, amount: 2)], at: source, in: &state)
        setResources([], at: target, in: &state)

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "move-young",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .moveResource(source: source, target: target, kind: .young)
                    )
                )
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(payload) = drafts.first else {
            return XCTFail("Expected pendingChoiceResolved.")
        }
        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(payload)
            )
        )

        XCTAssertEqual(resourceAmount(.young, at: source, in: nextState), 1)
        XCTAssertEqual(resourceAmount(.young, at: target, in: nextState), 1)
        XCTAssertEqual(resourceAmount(.school, at: target, in: nextState), 0)
    }

    func testMoveYoungCanFormSchoolAtTarget() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        state.pendingChoices[choice.choiceId] = choice
        setResources([ResourceQuantity(kind: .young, amount: 1)], at: source, in: &state)
        setResources([ResourceQuantity(kind: .young, amount: 2)], at: target, in: &state)

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "move-young",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .moveResource(source: source, target: target, kind: .young)
                    )
                )
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(payload) = drafts.first else {
            return XCTFail("Expected pendingChoiceResolved.")
        }
        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(payload)
            )
        )

        XCTAssertEqual(resourceAmount(.young, at: source, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.young, at: target, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.school, at: target, in: nextState), 1)
    }

    func testMoveSchoolRejectsTargetWithSchool() {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        state.pendingChoices[choice.choiceId] = choice
        setResources([ResourceQuantity(kind: .school, amount: 1)], at: source, in: &state)
        setResources([ResourceQuantity(kind: .school, amount: 1)], at: target, in: &state)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "move-school-invalid",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: choice.choiceId,
                            resolution: .moveResource(source: source, target: target, kind: .school)
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
        }
    }

    func testMoveYoungOrSchoolRejectsNonAdjacentMove() {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 5)
        state.pendingChoices[choice.choiceId] = choice
        setResources([ResourceQuantity(kind: .young, amount: 1)], at: source, in: &state)
        setResources([], at: target, in: &state)

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "move-young-non-adjacent",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: choice.choiceId,
                            resolution: .moveResource(source: source, target: target, kind: .young)
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
        }
    }

    func testMoveSchoolMovesOneSchoolToEmptySchoolTarget() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        state.pendingChoices[choice.choiceId] = choice
        setResources([ResourceQuantity(kind: .school, amount: 1)], at: source, in: &state)
        setResources([], at: target, in: &state)

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "move-school",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .moveResource(source: source, target: target, kind: .school)
                    )
                )
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(payload) = drafts.first else {
            return XCTFail("Expected pendingChoiceResolved.")
        }
        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(payload)
            )
        )

        XCTAssertEqual(resourceAmount(.school, at: source, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.school, at: target, in: nextState), 1)
    }

    func testFootballfishSchoolFeederMoveCreatesMovePendingChoice() throws {
        let catalog = try BaseGameCardCatalog()
        let engine = GameEngine(cardCatalog: catalog)
        var state = abilityDiveState(cardId: "base.main.048")
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0)
        setResources([ResourceQuantity(kind: .young, amount: 1)], at: source, in: &state)
        setResources([], at: target, in: &state)

        let diveDrafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-footballfish-move"),
            in: state
        )
        state = applying(diveDrafts, to: state, using: engine)

        let printedBonusChoice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(printedBonusChoice.kind, .drawFish)

        let skipDrafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "skip-footballfish-printed-bonus",
                choiceId: printedBonusChoice.choiceId,
                resolution: .skip
            ),
            in: state
        )

        guard case let .pendingChoiceCreated(choice) = skipDrafts.last else {
            return XCTFail("Expected Footballfish move pending choice.")
        }
        XCTAssertEqual(choice.kind, .moveYoungOrSchool)
        XCTAssertEqual(choice.expectedInput, .sourceAndTargetSlots)
        XCTAssertEqual(choice.abilityDefinition?.abilityId, "unsupported.base.ifActivated.card_048")
        XCTAssertEqual(choice.abilityDefinition?.effects, [.moveYoungOrSchool(count: 1)])
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
                ),
                .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: "player-1",
                        nextPlayerId: "player-2"
                    )
                )
            ]
        )
    }

    func testResolvePendingChoiceDoesNotAdvanceWhenPlayerStillHasPendingChoices() throws {
        let engine = GameEngine()
        var state = playFishState()
        let firstChoice = pendingChoice(choiceId: "choice-1", kind: .drawFish)
        let secondChoice = pendingChoice(choiceId: "choice-2", kind: .placeEgg)
        state.pendingChoices[firstChoice.choiceId] = firstChoice
        state.pendingChoices[secondChoice.choiceId] = secondChoice
        state.deckState.fishDrawPile = ["fish-9"]

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "resolve-first-pending-choice",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: firstChoice.choiceId,
                        resolution: .draw(count: 1)
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
                        choiceId: firstChoice.choiceId,
                        playerId: "player-1",
                        resolution: .draw(count: 1),
                        appliedEffects: [.drawFish(playerId: "player-1", cardIds: ["fish-9"])]
                    )
                )
            ]
        )
    }

    func testSkipLastPendingChoiceAdvancesActivePlayer() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(choiceId: "choice-1", kind: .placeEgg)
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "skip-last-pending-choice",
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
                ),
                .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: "player-1",
                        nextPlayerId: "player-2"
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

    func testResolveDrawFishChoiceDrawsFromDeckIntoHand() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .drawFish)
        state.pendingChoices[choice.choiceId] = choice
        state.deckState.fishDrawPile = ["fish-9", "fish-10"]
        let startingHand = state.playerGameStates["player-1"]?.hand

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "resolve-draw-fish",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .draw(count: 1)
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
                        resolution: .draw(count: 1),
                        appliedEffects: [.drawFish(playerId: "player-1", cardIds: ["fish-9"])]
                    )
                ),
                .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: "player-1",
                        nextPlayerId: "player-2"
                    )
                )
            ]
        )

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .draw(count: 1),
                        appliedEffects: [.drawFish(playerId: "player-1", cardIds: ["fish-9"])]
                    )
                )
            )
        )

        XCTAssertEqual(nextState.deckState.fishDrawPile, ["fish-10"])
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.hand, (startingHand ?? []) + ["fish-9"])
        XCTAssertNil(nextState.pendingChoices[choice.choiceId])
    }

    func testResolvePlaceEggChoiceAddsEggToLegalTarget() throws {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .placeEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 1)
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "resolve-place-egg",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .chooseTarget(target)
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
                        resolution: .chooseTarget(target),
                        appliedEffects: [.placeEgg(target: target, amount: 1)]
                    )
                ),
                .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: "player-1",
                        nextPlayerId: "player-2"
                    )
                )
            ]
        )

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .chooseTarget(target),
                        appliedEffects: [.placeEgg(target: target, amount: 1)]
                    )
                )
            )
        )

        XCTAssertEqual(resourceAmount(.egg, at: target, in: nextState), 1)
        XCTAssertNil(nextState.pendingChoices[choice.choiceId])
    }

    func testResolvePlaceEggChoiceRejectsEmptySlot() {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .placeEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "resolve-place-egg-empty",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: choice.choiceId,
                            resolution: .chooseTarget(target)
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
        }
    }

    func testResolvePlaceEggChoiceRejectsSlotWithEgg() {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .placeEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "resolve-place-egg-existing-egg",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: choice.choiceId,
                            resolution: .chooseTarget(target)
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
        }
    }

    func testResolveHatchEggChoiceTurnsEggIntoYoung() throws {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .hatchEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        state.pendingChoices[choice.choiceId] = choice

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "resolve-hatch-egg",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: choice.choiceId,
                        resolution: .chooseTarget(target)
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
                        resolution: .chooseTarget(target),
                        appliedEffects: [.hatchEgg(target: target, amount: 1)]
                    )
                ),
                .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: "player-1",
                        nextPlayerId: "player-2"
                    )
                )
            ]
        )

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .chooseTarget(target),
                        appliedEffects: [.hatchEgg(target: target, amount: 1)]
                    )
                )
            )
        )

        XCTAssertEqual(resourceAmount(.egg, at: target, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.young, at: target, in: nextState), 1)
        XCTAssertNil(nextState.pendingChoices[choice.choiceId])
    }

    func testResolvePlaceYoungChoiceAddsYoungToFishAndOpenSlot() throws {
        let engine = GameEngine()
        let fishTarget = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 1)
        let openTarget = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        for (index, target) in [fishTarget, openTarget].enumerated() {
            var state = playFishState()
            if target == fishTarget {
                setContent(.fishCard("fish-1"), at: target, in: &state)
            }
            setResources([], at: target, in: &state)
            let choice = pendingChoice(choiceId: "choice-place-young-\(index)", kind: .placeYoung)
            state.pendingChoices[choice.choiceId] = choice

            let drafts = try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "resolve-place-young-\(index)",
                    choiceId: choice.choiceId,
                    resolution: .chooseTarget(target)
                ),
                in: state
            )

            guard case let .pendingChoiceResolved(resolved) = drafts.first else {
                return XCTFail("Expected place young pending choice to resolve.")
            }
            XCTAssertEqual(resolved.appliedEffects, [.placeYoung(target: target, amount: 1)])
            state = applying(drafts, to: state, using: engine)
            XCTAssertEqual(resourceAmount(.young, at: target, in: state), 1)
        }
    }

    func testPlaceYoungFormsSchoolWhenYoungReachesThree() throws {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .placeYoung)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        state.pendingChoices[choice.choiceId] = choice
        setResources([ResourceQuantity(kind: .young, amount: 2)], at: target, in: &state)

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "resolve-place-young-school",
                    choiceId: choice.choiceId,
                    resolution: .chooseTarget(target)
                ),
                in: state
            ),
            to: state,
            using: engine
        )

        XCTAssertEqual(resourceAmount(.young, at: target, in: state), 0)
        XCTAssertEqual(resourceAmount(.school, at: target, in: state), 1)
    }

    func testResolveHatchEggChoiceRejectsSlotWithoutEgg() {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .hatchEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 1)
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "resolve-hatch-egg-no-egg",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: choice.choiceId,
                            resolution: .chooseTarget(target)
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .invalidPendingChoiceResolution(choice.choiceId))
        }
    }

    func testHatchEggFormsSchoolWhenYoungReachesThree() {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .hatchEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        state.pendingChoices[choice.choiceId] = choice
        setResources(
            [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 2)
            ],
            at: target,
            in: &state
        )

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .chooseTarget(target),
                        appliedEffects: [.hatchEgg(target: target, amount: 1)]
                    )
                )
            )
        )

        XCTAssertEqual(resourceAmount(.egg, at: target, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.young, at: target, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.school, at: target, in: nextState), 1)
    }

    func testHatchEggDoesNotFormSecondSchoolWhenSlotAlreadyHasSchool() {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .hatchEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        state.pendingChoices[choice.choiceId] = choice
        setResources(
            [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 2),
                ResourceQuantity(kind: .school, amount: 1)
            ],
            at: target,
            in: &state
        )

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .chooseTarget(target),
                        appliedEffects: [.hatchEgg(target: target, amount: 1)]
                    )
                )
            )
        )

        XCTAssertEqual(resourceAmount(.egg, at: target, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.young, at: target, in: nextState), 3)
        XCTAssertEqual(resourceAmount(.school, at: target, in: nextState), 1)
    }

    func testHatchEggDoesNotFormSchoolWhenYoungStaysBelowThree() {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .hatchEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        state.pendingChoices[choice.choiceId] = choice
        setResources(
            [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 1)
            ],
            at: target,
            in: &state
        )

        let nextState = engine.reduce(
            state: state,
            event: GameEvent(
                sequenceNumber: 10,
                roomId: roomId,
                timestamp: timestamp,
                payload: .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: choice.choiceId,
                        playerId: "player-1",
                        resolution: .chooseTarget(target),
                        appliedEffects: [.hatchEgg(target: target, amount: 1)]
                    )
                )
            )
        )

        XCTAssertEqual(resourceAmount(.egg, at: target, in: nextState), 0)
        XCTAssertEqual(resourceAmount(.young, at: target, in: nextState), 2)
        XCTAssertEqual(resourceAmount(.school, at: target, in: nextState), 0)
    }

    func testSkipPlaceEggAndHatchEggChoicesDoNotChangeOceanResources() {
        let engine = GameEngine()
        for kind in [PendingChoiceKind.placeEgg, .hatchEgg] {
            var state = playFishState(keepForageFish: true)
            let choice = pendingChoice(choiceId: "choice-\(kind.rawValue)", kind: kind)
            state.pendingChoices[choice.choiceId] = choice
            let startingOcean = state.playerGameStates["player-1"]?.ocean

            let nextState = engine.reduce(
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

            XCTAssertEqual(nextState.playerGameStates["player-1"]?.ocean, startingOcean)
            XCTAssertNil(nextState.pendingChoices[choice.choiceId])
        }
    }

    func testSkipHatchEggDoesNotTriggerSchoolFormation() {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let choice = pendingChoice(kind: .hatchEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4)
        state.pendingChoices[choice.choiceId] = choice
        setResources(
            [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 2)
            ],
            at: target,
            in: &state
        )

        let nextState = engine.reduce(
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

        XCTAssertEqual(resourceAmount(.egg, at: target, in: nextState), 1)
        XCTAssertEqual(resourceAmount(.young, at: target, in: nextState), 2)
        XCTAssertEqual(resourceAmount(.school, at: target, in: nextState), 0)
    }

    func testResolveTargetDoesNotAdvanceWhenPlayerStillHasPendingChoices() throws {
        let engine = GameEngine()
        var state = playFishState(keepForageFish: true)
        let firstChoice = pendingChoice(choiceId: "choice-place-egg", kind: .placeEgg)
        let secondChoice = pendingChoice(choiceId: "choice-hatch-egg", kind: .hatchEgg)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 1)
        state.pendingChoices[firstChoice.choiceId] = firstChoice
        state.pendingChoices[secondChoice.choiceId] = secondChoice

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "resolve-target-with-remaining-choice",
                playerId: "player-1",
                roomId: roomId,
                payload: .resolvePendingChoice(
                    ResolvePendingChoiceCommand(
                        choiceId: firstChoice.choiceId,
                        resolution: .chooseTarget(target)
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
                        choiceId: firstChoice.choiceId,
                        playerId: "player-1",
                        resolution: .chooseTarget(target),
                        appliedEffects: [.placeEgg(target: target, amount: 1)]
                    )
                )
            ]
        )
    }

    func testSkipPendingChoiceDoesNotChangeHandOrOceanResources() {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .drawFish)
        state.pendingChoices[choice.choiceId] = choice
        state.deckState.fishDrawPile = ["fish-9"]
        let startingHand = state.playerGameStates["player-1"]?.hand
        let startingOcean = state.playerGameStates["player-1"]?.ocean

        let nextState = engine.reduce(
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

        XCTAssertEqual(nextState.deckState.fishDrawPile, ["fish-9"])
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.hand, startingHand)
        XCTAssertEqual(nextState.playerGameStates["player-1"]?.ocean, startingOcean)
        XCTAssertNil(nextState.pendingChoices[choice.choiceId])
    }

    func testDiveQueueInsertsIfActivatedAbilityAfterPrintedBonus() throws {
        let engine = GameEngine()
        var state = abilityDiveState(cardId: "fish-30")

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-if-activated-order"),
            in: state
        )

        guard case let .diverMoved(event) = drafts.first,
              let queue = event.diveResolutionQueue
        else {
            return XCTFail("Expected dive queue.")
        }
        XCTAssertEqual(
            queue.steps.map(\.source),
            [
                .printedDiveBonus(.sunlit),
                .fishAbility(
                    cardId: "fish-30",
                    address: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
                )
            ]
        )
    }

    func testFishAIfActivatedAbilityUsesRegistryAbilityId() throws {
        let cardId = "registry-fish-a"
        let engine = GameEngine(
            cardCatalog: TestCardCatalog(
                fishCards: [
                    Card(
                        id: cardId,
                        name: "Registry Fish A",
                        abilityIds: [SampleAbilityIDs.fishAIfActivatedDrawFishOne],
                        printedPoints: 2,
                        lengthCm: 12
                    )
                ]
            )
        )
        let state = abilityDiveState(cardId: cardId)

        let drafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-registry-fish-a"),
            in: state
        )

        guard case let .diverMoved(event) = drafts.first,
              let abilityStep = event.diveResolutionQueue?.steps.first(where: {
                  if case .fishAbility = $0.source {
                      return true
                  }
                  return false
              })
        else {
            return XCTFail("Expected registry-backed Fish A ability step.")
        }

        XCTAssertEqual(abilityStep.pendingChoice.kind, .drawFish)
        XCTAssertEqual(abilityStep.pendingChoice.abilityDefinition?.abilityId, SampleAbilityIDs.fishAIfActivatedDrawFishOne)
    }

    func testFishBCompoundAbilityUsesRegistryAbilityId() throws {
        let engine = GameEngine()
        var state = try fishBCompoundSelectorState(engine: engine)
        let selector = try XCTUnwrap(state.pendingChoices.values.first)

        XCTAssertEqual(selector.kind, .compoundAbility)
        XCTAssertEqual(selector.abilityDefinition?.abilityId, SampleAbilityIDs.fishBIfActivatedPlaceTwoEggsHatchOne)
        XCTAssertEqual(
            selector.compoundAbilityProgress?.remainingEffects,
            [.placeEgg(count: 2), .hatchEgg(count: 1)]
        )
    }

    func testFishCWhenPlayedAbilityUsesRegistryAbilityId() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand = ["fish-32"]
        state.deckState.fishDrawPile = ["fish-9"]
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-c-registry",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(PlayFishCommand(cardId: "fish-32", targetSlot: target, payment: .empty))
            ),
            in: state
        )

        guard case let .pendingChoiceCreated(choice) = drafts.last else {
            return XCTFail("Expected registry-backed Fish C pending choice.")
        }
        XCTAssertEqual(choice.kind, .drawFish)
        XCTAssertEqual(choice.abilityDefinition?.abilityId, SampleAbilityIDs.fishCWhenPlayedDrawFishOne)
    }

    func testUnsupportedRegistryAbilityCreatesSkippablePendingChoice() throws {
        let unsupportedAbilityId: AbilityID = "test.unsupported.ifActivated"
        let engine = GameEngine(
            cardCatalog: TestCardCatalog(
                fishCards: [
                    Card(
                        id: "unsupported-fish",
                        name: "Unsupported Fish",
                        abilityIds: [unsupportedAbilityId],
                        printedPoints: 1,
                        lengthCm: 10
                    )
                ]
            ),
            abilityResolver: AbilityResolver(
                provider: AbilityRegistry(
                    definitions: [
                        AbilityDefinition(
                            abilityId: unsupportedAbilityId,
                            trigger: .ifActivated,
                            effects: [.unsupported],
                            isOptional: true
                        )
                    ]
                )
            )
        )
        var state = applying(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-unsupported-ability"),
                in: abilityDiveState(cardId: "unsupported-fish")
            ),
            to: abilityDiveState(cardId: "unsupported-fish"),
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "skip-unsupported-printed",
                    choiceId: printedChoice.choiceId,
                    resolution: .skip
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        let unsupportedChoice = try XCTUnwrap(state.pendingChoices.values.first)

        XCTAssertEqual(unsupportedChoice.kind, .unsupported)
        XCTAssertEqual(unsupportedChoice.abilityDefinition?.abilityId, unsupportedAbilityId)

        let skipDrafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "skip-unsupported-ability",
                choiceId: unsupportedChoice.choiceId,
                resolution: .skip
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = skipDrafts.first else {
            return XCTFail("Expected unsupported ability to be skippable.")
        }
        XCTAssertEqual(resolved.appliedEffects, [.none])
    }

    func testForageAndConsumedFishDoNotGenerateAbilitySteps() throws {
        let engine = GameEngine()
        var forageState = playFishState()
        forageState.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]
        clearOceanContent(for: "player-1", in: &forageState)
        setContent(
            .forageFish(
                ForageFish(
                    forageFishId: "forage-no-ability",
                    name: "印刷小鱼",
                    lengthCm: 1,
                    diveSite: .blue,
                    rowIndex: 0
                )
            ),
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            in: &forageState
        )

        let forageDrafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-forage-no-ability"),
            in: forageState
        )
        guard case let .diverMoved(forageEvent) = forageDrafts.first else {
            return XCTFail("Expected diver moved.")
        }
        XCTAssertEqual(forageEvent.diveResolutionQueue?.steps.map(\.source), [.printedDiveBonus(.sunlit)])

        var consumedState = playFishState()
        consumedState.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]
        clearOceanContent(for: "player-1", in: &consumedState)
        setConsumedFish(
            [ConsumedFish(cardId: "fish-30")],
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            in: &consumedState
        )

        let consumedDrafts = try engine.makeEventDrafts(
            for: diveCommand(commandId: "dive-consumed-no-ability"),
            in: consumedState
        )
        guard case let .diverMoved(consumedEvent) = consumedDrafts.first else {
            return XCTFail("Expected diver moved.")
        }
        XCTAssertNil(consumedEvent.diveResolutionQueue)
    }

    func testFishAAbilityResolveDrawsOneCardAndSkipDrawsNothing() throws {
        let engine = GameEngine()
        var state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-fish-a"), in: abilityDiveState(cardId: "fish-30")),
            to: abilityDiveState(cardId: "fish-30"),
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(commandId: "skip-printed-a", choiceId: printedChoice.choiceId, resolution: .skip),
                in: state
            ),
            to: state,
            using: engine
        )
        state.deckState.fishDrawPile = ["fish-9"]
        let abilityChoice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-fish-a",
                choiceId: abilityChoice.choiceId,
                resolution: .draw(count: 1)
            ),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = drafts.first else {
            return XCTFail("Expected resolved ability.")
        }
        XCTAssertEqual(resolved.appliedEffects, [.drawFish(playerId: "player-1", cardIds: ["fish-9"])])

        var skipState = state
        skipState.deckState.fishDrawPile = ["fish-10"]
        let skipDrafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "skip-fish-a",
                choiceId: abilityChoice.choiceId,
                resolution: .skip
            ),
            in: skipState
        )
        guard case let .pendingChoiceResolved(skipped) = skipDrafts.first else {
            return XCTFail("Expected skipped ability.")
        }
        XCTAssertEqual(skipped.appliedEffects, [.none])
        XCTAssertTrue(skipDrafts.contains(where: \.isTurnCompletion))
    }

    func testFishBCompoundAbilityCanPlaceEggThenHatchEggAndStayPendingUntilComplete() throws {
        let engine = GameEngine()
        var state = try fishBCompoundSelectorState(engine: engine)
        let selector = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(selector.kind, .compoundAbility)

        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "choose-place-egg",
                    choiceId: selector.choiceId,
                    resolution: .chooseAbilityEffect(.placeEgg(count: 1))
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        let targetChoice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(targetChoice.kind, .placeEgg)

        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let placeDrafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "place-egg-b", choiceId: targetChoice.choiceId, resolution: .chooseTarget(target)),
            in: state
        )
        guard case let .pendingChoiceResolved(placeResolved) = placeDrafts.first,
              case .updated = placeResolved.diveQueueUpdate
        else {
            return XCTFail("Expected compound progress update.")
        }
        XCTAssertEqual(placeResolved.appliedEffects, [.placeEgg(target: target, amount: 1)])
        state = applying(placeDrafts, to: state, using: engine)
        XCTAssertEqual(state.activePlayerId, "player-1")
        XCTAssertNotNil(state.activeDiveQueue)

        let nextSelector = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(nextSelector.kind, .compoundAbility)
        XCTAssertEqual(nextSelector.compoundAbilityProgress?.completedEffects, [.placeEgg(count: 1)])
        XCTAssertEqual(resourceAmount(.egg, at: target, in: state), 1)
    }

    func testFishBCompoundAbilityCanHatchEggThenPlaceEggAndCanEndPartial() throws {
        let engine = GameEngine()
        var state = try fishBCompoundSelectorState(engine: engine)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        setResources([ResourceQuantity(kind: .egg, amount: 1)], at: target, in: &state)

        let selector = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "choose-hatch-egg",
                    choiceId: selector.choiceId,
                    resolution: .chooseAbilityEffect(.hatchEgg(count: 1))
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        let hatchChoice = try XCTUnwrap(state.pendingChoices.values.first)
        let hatchDrafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "hatch-egg-b", choiceId: hatchChoice.choiceId, resolution: .chooseTarget(target)),
            in: state
        )
        state = applying(hatchDrafts, to: state, using: engine)
        XCTAssertEqual(resourceAmount(.egg, at: target, in: state), 0)
        XCTAssertEqual(resourceAmount(.young, at: target, in: state), 1)

        let partialSelector = try XCTUnwrap(state.pendingChoices.values.first)
        let finishDrafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "finish-partial-b", choiceId: partialSelector.choiceId, resolution: .finishAbility),
            in: state
        )
        guard case let .pendingChoiceResolved(resolved) = finishDrafts.first,
              case .completed = resolved.diveQueueUpdate
        else {
            return XCTFail("Expected compound ability to end and complete queue.")
        }
        XCTAssertTrue(finishDrafts.contains(where: \.isTurnCompletion))
    }

    func testFishBAllCompoundEffectsCompleteAdvancesQueue() throws {
        let engine = GameEngine()
        var state = try fishBCompoundSelectorState(engine: engine, addSecondFish: true)
        let firstTarget = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let secondTarget = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)

        for target in [firstTarget, secondTarget] {
            let selector = try XCTUnwrap(state.pendingChoices.values.first)
            state = applying(
                try engine.makeEventDrafts(
                    for: resolveCommand(
                        commandId: "choose-place-\(target.rowIndex)",
                        choiceId: selector.choiceId,
                        resolution: .chooseAbilityEffect(.placeEgg(count: 1))
                    ),
                    in: state
                ),
                to: state,
                using: engine
            )
            let placeChoice = try XCTUnwrap(state.pendingChoices.values.first)
            state = applying(
                try engine.makeEventDrafts(
                    for: resolveCommand(
                        commandId: "place-\(target.rowIndex)",
                        choiceId: placeChoice.choiceId,
                        resolution: .chooseTarget(target)
                    ),
                    in: state
                ),
                to: state,
                using: engine
            )
        }

        let selector = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "choose-final-hatch",
                    choiceId: selector.choiceId,
                    resolution: .chooseAbilityEffect(.hatchEgg(count: 1))
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        let hatchChoice = try XCTUnwrap(state.pendingChoices.values.first)
        let finalDrafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "hatch-final-b", choiceId: hatchChoice.choiceId, resolution: .chooseTarget(firstTarget)),
            in: state
        )

        guard case let .pendingChoiceResolved(resolved) = finalDrafts.first,
              case .completed = resolved.diveQueueUpdate
        else {
            return XCTFail("Expected all compound effects to complete queue.")
        }
        XCTAssertTrue(finalDrafts.contains(where: \.isTurnCompletion))
    }

    func testFishCWhenPlayedCreatesAbilityPendingChoiceAndAdvancesAfterResolve() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand = ["fish-32"]
        state.deckState.fishDrawPile = ["fish-9"]
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "play-fish-c",
                playerId: "player-1",
                roomId: roomId,
                payload: .playFish(PlayFishCommand(cardId: "fish-32", targetSlot: target, payment: .empty))
            ),
            in: state
        )

        XCTAssertEqual(drafts.count, 2)
        guard case let .pendingChoiceCreated(choice) = drafts.last else {
            return XCTFail("Expected when played pending choice.")
        }
        XCTAssertEqual(choice.kind, .drawFish)
        XCTAssertFalse(drafts.contains(where: \.isTurnCompletion))

        state = applying(drafts, to: state, using: engine)
        let resolveDrafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "resolve-fish-c", choiceId: choice.choiceId, resolution: .draw(count: 1)),
            in: state
        )
        XCTAssertTrue(resolveDrafts.contains(where: \.isTurnCompletion))
    }

    func testBlueLanternfishAbilityIdResolvesToDrawFour() throws {
        let catalog = try BaseGameCardCatalog()
        let card = try XCTUnwrap(catalog.starterFishCards.first { $0.id == "base.starter.127" })

        let abilities = AbilityResolver().abilityDefinitions(for: card)

        XCTAssertEqual(card.name, "Blue Lanternfish")
        XCTAssertEqual(card.abilityIds, [BaseGameAbilityIDs.blueLanternfishWhenPlayedDrawFour])
        XCTAssertEqual(abilities.map(\.abilityId), [BaseGameAbilityIDs.blueLanternfishWhenPlayedDrawFour])
        XCTAssertEqual(abilities.first?.trigger, .whenPlayed)
        XCTAssertEqual(abilities.first?.effects, [.drawFish(count: 4)])
    }

    func testBuiltInAbilityRegistryMapsBlueLanternfishToDrawFour() throws {
        let ability = try XCTUnwrap(
            AbilityRegistry.builtIn.abilityDefinition(
                for: BaseGameAbilityIDs.blueLanternfishWhenPlayedDrawFour
            )
        )

        XCTAssertEqual(ability.trigger, .whenPlayed)
        XCTAssertEqual(ability.effects, [.drawFish(count: 4)])
    }

    func testAbilityPatternParserMapsRealBaseGameIconPatterns() throws {
        let catalog = try BaseGameCardCatalog()
        let cards = catalog.starterFishCards + catalog.fishCards
        let resolver = AbilityResolver()

        let sailfish = try XCTUnwrap(cards.first { $0.id == "base.main.010" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: sailfish).first?.effects,
            [.drawFish(count: 3)]
        )

        let spiderfish = try XCTUnwrap(cards.first { $0.id == "base.main.003" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: spiderfish).first?.effects,
            [.hatchEgg(count: 1), .hatchEgg(count: 1), .hatchEgg(count: 1)]
        )

        let mackerel = try XCTUnwrap(cards.first { $0.id == "base.main.009" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: mackerel).first?.effects,
            [.placeEgg(count: 1), .placeEgg(count: 1)]
        )

        let carpetshark = try XCTUnwrap(cards.first { $0.id == "base.main.006" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: carpetshark).first?.effects,
            [.placeEggOnMatchingFish(filter: .tag("predator"), mode: .onEachEligibleFish)]
        )

        let devilRay = try XCTUnwrap(cards.first { $0.id == "base.main.049" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: devilRay).first?.effects,
            [.placeYoung(count: 1), .placeYoung(count: 1)]
        )
    }

    func testAbilityPatternParserMapsRealSharksAndReefsCoralPatterns() throws {
        let catalog = try SharksAndReefsCardCatalog()
        let cards = catalog.starterFishCards + catalog.fishCards
        let resolver = AbilityResolver()

        let surgeonfish = try XCTUnwrap(cards.first { $0.id == "sr.main.165" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: surgeonfish).first?.effects,
            [
                .gainCoral(selector: .blue, count: 1),
                .gainCoral(selector: .purple, count: 1)
            ]
        )
    }

    func testAbilityPatternParserMapsPass2ARealBaseGamePatterns() throws {
        let catalog = try BaseGameCardCatalog()
        let cards = catalog.starterFishCards + catalog.fishCards
        let resolver = AbilityResolver()

        let footballfish = try XCTUnwrap(cards.first { $0.id == "base.main.048" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: footballfish).first?.effects,
            [.moveYoungOrSchool(count: 1)]
        )

        let snaggletooth = try XCTUnwrap(cards.first { $0.id == "base.main.107" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: snaggletooth).first?.effects,
            [.moveYoungOrSchool(count: 1), .moveYoungOrSchool(count: 1)]
        )

        let abyssalHalosaur = try XCTUnwrap(cards.first { $0.id == "base.main.002" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: abyssalHalosaur).first?.effects,
            [.playFishFromHand(filter: .any, placement: .bottomRow, costMode: .payCost)]
        )

        let redLionfish = try XCTUnwrap(cards.first { $0.id == "base.main.095" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: redLionfish).first?.effects,
            [.playFishFromHand(filter: .any, placement: .sunlight, costMode: .payCost)]
        )

    }

    func testAbilityPatternParserMapsPass2ARealSharksAndReefsPatterns() throws {
        let catalog = try SharksAndReefsCardCatalog()
        let cards = catalog.starterFishCards + catalog.fishCards
        let resolver = AbilityResolver()

        let megamouth = try XCTUnwrap(cards.first { $0.id == "sr.main.173" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: megamouth).first?.effects,
            [.drawFish(count: 5)]
        )

        let lollipop = try XCTUnwrap(cards.first { $0.id == "sr.main.170" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: lollipop).first?.effects,
            [.playFishForFree(filter: .lengthBucket(.small), count: 1)]
        )

        let shortnose = try XCTUnwrap(cards.first { $0.id == "sr.main.192" })
        XCTAssertEqual(
            resolver.abilityDefinitions(for: shortnose).first?.effects,
            [.playFishForFree(filter: .lengthBucket(.medium), count: 1)]
        )
    }

    func testAbilityPatternParserKeepsConditionalCoralPlayFishUnsupported() throws {
        let catalog = try SharksAndReefsCardCatalog()
        let cards = catalog.starterFishCards + catalog.fishCards
        let resolver = AbilityResolver()

        let reefTriggerfish = try XCTUnwrap(cards.first { $0.id == "sr.main.182" })
        XCTAssertEqual(resolver.abilityDefinitions(for: reefTriggerfish).first?.effects, [.unsupported])

        let yokozuna = try XCTUnwrap(cards.first { $0.id == "sr.main.209" })
        XCTAssertEqual(resolver.abilityDefinitions(for: yokozuna).first?.effects, [.unsupported])
    }

    func testDeferredAbilityPatternsRemainUnsupportedUntilRuleConfirmation() throws {
        let baseCatalog = try BaseGameCardCatalog()
        let srCatalog = try SharksAndReefsCardCatalog()
        let resolver = AbilityResolver()
        let cards = baseCatalog.fishCards + baseCatalog.starterFishCards + srCatalog.fishCards + srCatalog.starterFishCards

        let deferredIds = [
            "base.main.050", // Giant Hatchetfish
            "base.main.111", // Spookfish
            "base.main.051", // Giant Hawkfish
            "base.main.101", // Shortspine African Angler
            "base.main.117", // Tripodfish
            "sr.main.182",   // Reef Triggerfish
            "sr.main.141",   // Blackmouth Angler
            "sr.main.209",   // Yokozuna Slickhead
            "sr.main.193"    // Sixgill Sawshark
        ]

        for cardId in deferredIds {
            let card = try XCTUnwrap(cards.first { $0.id == cardId })
            XCTAssertEqual(
                resolver.abilityDefinitions(for: card).first?.effects,
                [.unsupported],
                "Expected \(cardId) to remain unsupported until rules are confirmed."
            )
        }
    }

    func testBlueLanternfishWhenPlayedCreatesDrawFourPendingChoice() throws {
        let catalog = try BaseGameCardCatalog()
        let engine = GameEngine(cardCatalog: catalog)
        let state = blueLanternfishPlayState(deck: ["base.main.001"])

        let drafts = try engine.makeEventDrafts(
            for: blueLanternfishPlayCommand(commandId: "play-blue-lanternfish"),
            in: state
        )

        guard case let .pendingChoiceCreated(choice) = drafts.last else {
            return XCTFail("Expected Blue Lanternfish when-played pending choice.")
        }
        XCTAssertEqual(choice.kind, .drawFish)
        XCTAssertEqual(choice.abilityDefinition?.abilityId, BaseGameAbilityIDs.blueLanternfishWhenPlayedDrawFour)
        XCTAssertEqual(choice.abilityDefinition?.effects, [.drawFish(count: 4)])
        XCTAssertFalse(drafts.contains(where: \.isTurnCompletion))
    }

    func testBlueLanternfishResolveDrawsFourCards() throws {
        let catalog = try BaseGameCardCatalog()
        let engine = GameEngine(cardCatalog: catalog)
        var state = blueLanternfishPlayState(deck: [
            "base.main.001",
            "base.main.002",
            "base.main.003",
            "base.main.004",
            "base.main.005"
        ])
        state = applying(
            try engine.makeEventDrafts(
                for: blueLanternfishPlayCommand(commandId: "play-blue-lanternfish-draw-four"),
                in: state
            ),
            to: state,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-blue-lanternfish-draw-four",
                choiceId: choice.choiceId,
                resolution: .draw(count: 4)
            ),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(
            state.playerGameStates["player-1"]?.hand,
            ["base.main.001", "base.main.002", "base.main.003", "base.main.004"]
        )
        XCTAssertEqual(state.deckState.fishDrawPile, ["base.main.005"])
        XCTAssertTrue(drafts.contains { draft in
            guard case let .pendingChoiceResolved(event) = draft else { return false }
            return event.appliedEffects == [
                .drawFish(
                    playerId: "player-1",
                    cardIds: ["base.main.001", "base.main.002", "base.main.003", "base.main.004"]
                )
            ]
        })
    }

    func testBlueLanternfishSkipDoesNotDrawCards() throws {
        let catalog = try BaseGameCardCatalog()
        let engine = GameEngine(cardCatalog: catalog)
        var state = blueLanternfishPlayState(deck: [
            "base.main.001",
            "base.main.002",
            "base.main.003",
            "base.main.004"
        ])
        state = applying(
            try engine.makeEventDrafts(
                for: blueLanternfishPlayCommand(commandId: "play-blue-lanternfish-skip"),
                in: state
            ),
            to: state,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "skip-blue-lanternfish",
                choiceId: choice.choiceId,
                resolution: .skip
            ),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(state.playerGameStates["player-1"]?.hand, [])
        XCTAssertEqual(
            state.deckState.fishDrawPile,
            ["base.main.001", "base.main.002", "base.main.003", "base.main.004"]
        )
    }

    func testBlueLanternfishDrawFourWithShortDeckDrawsRemainingCards() throws {
        let catalog = try BaseGameCardCatalog()
        let engine = GameEngine(cardCatalog: catalog)
        var state = blueLanternfishPlayState(deck: ["base.main.001", "base.main.002"])
        state = applying(
            try engine.makeEventDrafts(
                for: blueLanternfishPlayCommand(commandId: "play-blue-lanternfish-short-deck"),
                in: state
            ),
            to: state,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)

        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-blue-lanternfish-short-deck",
                choiceId: choice.choiceId,
                resolution: .draw(count: 4)
            ),
            in: state
        )
        state = applying(drafts, to: state, using: engine)

        XCTAssertEqual(state.playerGameStates["player-1"]?.hand, ["base.main.001", "base.main.002"])
        XCTAssertTrue(state.deckState.fishDrawPile.isEmpty)
    }

    func testSampleDrawOneAbilityStillResolvesOneCard() throws {
        let ability = try XCTUnwrap(
            AbilityRegistry.builtIn.abilityDefinition(for: SampleAbilityIDs.fishCWhenPlayedDrawFishOne)
        )

        XCTAssertEqual(ability.effects, [.drawFish(count: 1)])
    }

    func testAbilityPendingChoiceBlocksNewPlayFishAndDive() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = PendingChoice(
            choiceId: "ability-choice",
            playerId: "player-1",
            source: .fishAbility("fish-30"),
            kind: .drawFish,
            options: [],
            expectedInput: .none,
            isOptional: true,
            createdAtSequence: 9
        )
        state.pendingChoices[choice.choiceId] = choice

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "play-blocked-by-ability",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(
                            cardId: "fish-6",
                            targetSlot: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
                            payment: .empty
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .unresolvedPendingChoices("player-1"))
        }

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-blocked-by-ability"),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .unresolvedPendingChoices("player-1"))
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

    private func playFishState(keepForageFish: Bool = false) -> GameState {
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
                    ocean: keepForageFish ? .baseGameInitial(for: "player-1") : emptyOcean(for: "player-1")
                ),
                "player-2": PlayerGameState(
                    playerId: "player-2",
                    hand: ["fish-1", "fish-6"],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: keepForageFish ? .baseGameInitial(for: "player-2") : emptyOcean(for: "player-2")
                )
            ],
            deckState: .empty
        )
    }

    private func emptyOcean(for playerId: PlayerID) -> OceanState {
        var ocean = OceanState.baseGameInitial(for: playerId)
        for index in ocean.slots.indices {
            ocean.slots[index].content = .empty
        }
        return ocean
    }

    private func playFishStateWithResourcesInDifferentSlot() -> GameState {
        var state = playFishState()
        let sourceSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .purple,
            rowIndex: 3
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

    private func blueDiveQueueState() -> GameState {
        diveQueueState(diveSite: .blue)
    }

    private func diveQueueState(diveSite: DiveSite) -> GameState {
        var state = playFishState()
        for rowIndex in [0, 3, 4] {
            setContent(
                .fishCard("fish-\(rowIndex + 10)"),
                at: OceanSlotAddress(playerId: "player-1", diveSite: diveSite, rowIndex: rowIndex),
                in: &state
            )
        }
        return state
    }

    private func coralDiveState(
        coralReefs: [CoralReefState] = CoralReefState.sharksAndReefsInitial,
        coralCount: Int = 0,
        includeBottomBonus: Bool = false
    ) -> GameState {
        var state = playFishState()
        clearOceanContent(for: "player-1", in: &state)
        clearResources(for: "player-1", in: &state)
        state.playerGameStates["player-1"]?.ocean.coralReefs = coralReefs.map { reef in
            guard reef.diveSite == .blue else { return reef }
            return CoralReefState(
                diveSite: reef.diveSite,
                coralCount: coralCount,
                maxCoral: reef.maxCoral,
                completionBonus: reef.completionBonus
            )
        }
        if !includeBottomBonus {
            state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]
        }
        return state
    }

    private func resolveFirstCoralOffer(
        resolution: PendingChoiceResolution,
        sourceResources: [ResourceQuantity]
    ) throws -> GameState {
        let engine = GameEngine()
        var initialState = coralDiveState()
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3)
        setResources(sourceResources, at: source, in: &initialState)
        var state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-coral-pay"), in: initialState),
            to: initialState,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)
        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(commandId: "resolve-coral-pay", choiceId: choice.choiceId, resolution: resolution),
            in: state
        )
        state = applying(drafts, to: state, using: engine)
        return state
    }

    private func resolveCoralOffer(
        diveActionSite: DiveActionSite,
        resolution: PendingChoiceResolution,
        source: OceanSlotAddress,
        sourceResources: [ResourceQuantity]
    ) throws -> GameState {
        let engine = GameEngine()
        var initialState = coralDiveState()
        setResources(sourceResources, at: source, in: &initialState)
        var state = applying(
            try engine.makeEventDrafts(
                for: diveCommand(commandId: "dive-coral-\(diveActionSite.rawValue)", diveSite: diveActionSite),
                in: initialState
            ),
            to: initialState,
            using: engine
        )
        let choice = try XCTUnwrap(state.pendingChoices.values.first)
        XCTAssertEqual(choice.source, .coralReef(DiveSite(rawValue: diveActionSite.rawValue)!))
        let drafts = try engine.makeEventDrafts(
            for: resolveCommand(
                commandId: "resolve-coral-\(diveActionSite.rawValue)",
                choiceId: choice.choiceId,
                resolution: resolution
            ),
            in: state
        )
        state = applying(drafts, to: state, using: engine)
        return state
    }

    private func coralCount(_ diveSite: DiveSite, in state: GameState) -> Int {
        state.playerGameStates["player-1"]?
            .ocean
            .coralReefs
            .first(where: { $0.diveSite == diveSite })?
            .coralCount ?? 0
    }

    private func abilityDiveState(cardId: CardID, addSecondFish: Bool = false) -> GameState {
        var state = playFishState()
        state.playerGameStates["player-1"]?.diveSitesReachedBottomThisWeek = [.blue]
        clearOceanContent(for: "player-1", in: &state)
        setContent(
            .fishCard(cardId),
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            in: &state
        )
        if addSecondFish {
            setContent(
                .fishCard("fish-6"),
                at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1),
                in: &state
            )
        }
        return state
    }

    private func gainCoralAbilityPendingChoice(
        selector: CoralDiveSiteSelector,
        cardId: CardID
    ) -> PendingChoice {
        let ability = AbilityDefinition(
            abilityId: "fixture-gain-coral-\(selector.rawValue)",
            trigger: .ifActivated,
            effects: [.gainCoral(selector: selector, count: 1)],
            isOptional: true,
            displayText: "发动时：获得 1 个珊瑚"
        )
        return PendingChoice(
            choiceId: "choice-gain-coral-\(selector.rawValue)",
            playerId: "player-1",
            source: .fishAbility(cardId),
            kind: .gainCoral,
            options: [],
            expectedInput: .coralPlacement,
            isOptional: true,
            abilityDefinition: ability,
            createdAtSequence: 10
        )
    }

    private func scatterSchoolPendingChoice() -> PendingChoice {
        let ability = AbilityDefinition(
            abilityId: "fixture-scatter-school",
            trigger: .whenPlayed,
            effects: [.scatterSchool(count: 1)],
            displayText: "打出时：打散鱼群"
        )
        return PendingChoice(
            choiceId: "choice-scatter-school",
            playerId: "player-1",
            source: .fishAbility("fixture.scatter"),
            kind: .scatterSchool,
            options: [],
            expectedInput: .scatterSchoolSource,
            isOptional: true,
            abilityDefinition: ability,
            selectedAbilityEffect: .scatterSchool(count: 1),
            createdAtSequence: 10
        )
    }

    private func consumeFishPendingChoice(
        expectedInput: PendingChoiceExpectedInput = .consumeFishConsumer,
        progress: ConsumeFishFromHandProgress? = nil
    ) -> PendingChoice {
        let ability = AbilityDefinition(
            abilityId: "fixture-consume-fish-from-hand",
            trigger: .whenPlayed,
            effects: [.consumeFishFromHand(count: 1)],
            isOptional: true,
            displayText: "打出时：吞噬手牌鱼"
        )
        return PendingChoice(
            choiceId: "choice-consume-fish-from-hand",
            playerId: "player-1",
            source: .fishAbility("consume.consumer"),
            kind: .consumeFishFromHand,
            options: [],
            expectedInput: expectedInput,
            isOptional: true,
            abilityDefinition: ability,
            consumeFishFromHandProgress: progress,
            selectedAbilityEffect: .consumeFishFromHand(count: 1),
            createdAtSequence: 10
        )
    }

    private func consumeFishConsumerAddress() -> OceanSlotAddress {
        OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
    }

    private func consumeFishState(hand: [CardID]) -> GameState {
        var state = playFishState()
        clearOceanContent(for: "player-1", in: &state)
        clearResources(for: "player-1", in: &state)
        state.playerGameStates["player-1"]?.hand = hand
        setContent(.fishCard("consume.consumer"), at: consumeFishConsumerAddress(), in: &state)
        return state
    }

    private func playFishForFreePendingChoice(
        filter: FreePlayFishFilter = .any,
        expectedInput: PendingChoiceExpectedInput = .freePlayHandCard,
        progress: PlayFishForFreeProgress? = nil
    ) -> PendingChoice {
        let ability = AbilityDefinition(
            abilityId: "fixture-play-fish-for-free",
            trigger: .whenPlayed,
            effects: [.playFishForFree(filter: filter, count: 1)],
            isOptional: true,
            displayText: "打出时：免费打出手牌鱼"
        )
        return PendingChoice(
            choiceId: "choice-play-fish-for-free",
            playerId: "player-1",
            source: .fishAbility("fixture.free"),
            kind: .playFishForFree,
            options: [],
            expectedInput: expectedInput,
            isOptional: true,
            abilityDefinition: ability,
            playFishForFreeProgress: progress,
            selectedAbilityEffect: .playFishForFree(filter: filter, count: 1),
            createdAtSequence: 10
        )
    }

    private func playFishForFreeState(hand: [CardID]) -> GameState {
        var state = playFishState()
        clearOceanContent(for: "player-1", in: &state)
        clearResources(for: "player-1", in: &state)
        state.playerGameStates["player-1"]?.hand = hand
        return state
    }

    private func scatterSchoolTargets() -> [OceanSlotAddress] {
        [
            OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1),
            OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 0),
            OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 0)
        ]
    }

    private func fishBCompoundSelectorState(
        engine: GameEngine,
        addSecondFish: Bool = false
    ) throws -> GameState {
        let initialState = abilityDiveState(cardId: "fish-31", addSecondFish: addSecondFish)
        var state = applying(
            try engine.makeEventDrafts(for: diveCommand(commandId: "dive-fish-b-\(addSecondFish)"), in: initialState),
            to: initialState,
            using: engine
        )
        let printedChoice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "skip-printed-b-\(addSecondFish)",
                    choiceId: printedChoice.choiceId,
                    resolution: .skip
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        return state
    }

    private func diveCommand(
        commandId: CommandID,
        diveSite: DiveActionSite = .blue
    ) -> PlayerCommand {
        PlayerCommand(
            commandId: commandId,
            playerId: "player-1",
            roomId: roomId,
            payload: .dive(DiveCommand(diveSite: diveSite))
        )
    }

    private func activateGameEndAbilityCommand(
        commandId: CommandID,
        source: GameEndAbilitySource
    ) -> PlayerCommand {
        PlayerCommand(
            commandId: commandId,
            playerId: source.playerId,
            roomId: roomId,
            payload: .activateGameEndAbility(ActivateGameEndAbilityCommand(source: source))
        )
    }

    private func finishGameEndAbilitiesCommand(commandId: CommandID) -> PlayerCommand {
        PlayerCommand(
            commandId: commandId,
            playerId: "player-1",
            roomId: roomId,
            payload: .finishGameEndAbilities(FinishGameEndAbilitiesCommand())
        )
    }

    private func playFishCommand(
        commandId: CommandID,
        cardId: CardID,
        targetSlot: OceanSlotAddress,
        payment: PlayFishPayment = .empty
    ) -> PlayerCommand {
        PlayerCommand(
            commandId: commandId,
            playerId: "player-1",
            roomId: roomId,
            payload: .playFish(
                PlayFishCommand(
                    cardId: cardId,
                    targetSlot: targetSlot,
                    payment: payment
                )
            )
        )
    }

    private func blueLanternfishPlayState(deck: [CardID]) -> GameState {
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand = [
            "base.starter.127",
            "base.main.010",
            "base.main.011"
        ]
        state.deckState.fishDrawPile = deck
        return state
    }

    private func blueLanternfishPlayCommand(commandId: CommandID) -> PlayerCommand {
        playFishCommand(
            commandId: commandId,
            cardId: "base.starter.127",
            targetSlot: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 3),
            payment: PlayFishPayment(
                discardedCardIds: ["base.main.010", "base.main.011"],
                eggSources: [],
                youngSources: []
            )
        )
    }

    private func resolveCommand(
        commandId: CommandID,
        choiceId: PendingChoiceID,
        resolution: PendingChoiceResolution
    ) -> PlayerCommand {
        PlayerCommand(
            commandId: commandId,
            playerId: "player-1",
            roomId: roomId,
            payload: .resolvePendingChoice(
                ResolvePendingChoiceCommand(
                    choiceId: choiceId,
                    resolution: resolution
                )
            )
        )
    }

    private func applying(
        _ drafts: [DomainEventDraft],
        to state: GameState,
        using engine: GameEngine
    ) -> GameState {
        var eventFactory = AuthoritativeEventFactory(
            roomId: roomId,
            nextSequenceNumber: state.eventSequence + 1,
            randomSeed: state.randomSeed ?? 0,
            timestampProvider: { self.timestamp }
        )
        return eventFactory
            .makeEvents(from: drafts, actorPlayerId: "player-1")
            .reduce(state) { currentState, event in
                engine.reduce(state: currentState, event: event)
            }
    }

    private func pendingChoice(
        choiceId: PendingChoiceID = "choice-1",
        kind: PendingChoiceKind = .bottomBonus,
        isOptional: Bool = true
    ) -> PendingChoice {
        PendingChoice(
            choiceId: choiceId,
            playerId: "player-1",
            source: .diveBonus(.blue),
            kind: kind,
            options: [],
            expectedInput: expectedInput(for: kind),
            isOptional: isOptional,
            createdAtSequence: 9
        )
    }

    private func expectedInput(for kind: PendingChoiceKind) -> PendingChoiceExpectedInput {
        switch kind {
        case .placeEgg,
             .placeYoung,
             .hatchEgg:
            return .targetSlot
        case .recoverFromDiscardOrDraw:
            return .cardSelection
        case .moveYoungOrSchool:
            return .sourceAndTargetSlots
        case .gainCoral:
            return .coralPayment
        case .scatterSchool:
            return .scatterSchoolSource
        case .consumeFishFromHand:
            return .consumeFishConsumer
        case .playFishForFree:
            return .freePlayHandCard
        case .placeEggOnMatchingFish:
            return .matchingEggTarget
        case .playFishFromHand:
            return .playFishFromHandCard
        case .drawFish,
             .compoundAbility,
             .bottomBonus,
             .placeholder,
             .unsupported:
            return .none
        }
    }

    private func resourceAmount(
        _ kind: ResourceKind,
        at address: OceanSlotAddress,
        in state: GameState
    ) -> Int {
        state.playerGameStates[address.playerId]?
            .ocean
            .slots
            .first(where: { $0.address == address })?
            .resources
            .first(where: { $0.kind == kind })?
            .amount ?? 0
    }

    private func totalResourceAmount(_ kind: ResourceKind, in state: GameState) -> Int {
        state.playerGameStates["player-1"]?
            .ocean
            .slots
            .map { slot in
                slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
            }
            .reduce(0, +) ?? 0
    }

    private func coverShorterFishState(keepForageFish: Bool = false) -> GameState {
        var state = playFishState(keepForageFish: keepForageFish)
        state.playerGameStates["player-1"]?.hand.append("cover-fish")
        return state
    }

    private func reefFishState(coralReefs: [CoralReefState]) -> GameState {
        var state = playFishState()
        state.playerGameStates["player-1"]?.hand.append(contentsOf: ["reef-fish", "purple-reef-fish"])
        state.playerGameStates["player-1"]?.ocean.coralReefs = coralReefs
        return state
    }

    private func coverShorterFishCatalog() -> TestCardCatalog {
        let sample = SampleCardCatalog()
        return TestCardCatalog(
            starterFishCards: sample.starterFishCards,
            fishCards: sample.fishCards + [
                Card(
                    id: "cover-fish",
                    name: "Cover Fish",
                    costs: [.coverShorterFish(count: 1)],
                    printedPoints: 5,
                    lengthCm: 30
                ),
                Card(
                    id: "same-length-fish",
                    name: "Same Length Fish",
                    printedPoints: 2,
                    lengthCm: 30
                )
            ]
        )
    }

    private func reefFishCatalog() -> TestCardCatalog {
        let sample = SampleCardCatalog()
        return TestCardCatalog(
            starterFishCards: sample.starterFishCards,
            fishCards: sample.fishCards + [
                Card(
                    id: "reef-fish",
                    name: "Reef Fish",
                    requirements: [
                        Requirement(coralRequirement: CoralRequirement(diveSite: .any, count: 2))
                    ],
                    printedPoints: 4,
                    lengthCm: 20
                ),
                Card(
                    id: "purple-reef-fish",
                    name: "Purple Reef Fish",
                    requirements: [
                        Requirement(coralRequirement: CoralRequirement(diveSite: .purple, count: 1))
                    ],
                    printedPoints: 4,
                    lengthCm: 20
                )
            ]
        )
    }

    private func sharksAndReefsAbilityCatalog() -> TestCardCatalog {
        let sample = SampleCardCatalog()
        return TestCardCatalog(
            starterFishCards: sample.starterFishCards,
            fishCards: sample.fishCards + [
                Card(
                    id: "sr.main.136",
                    name: "American Pocket Shark",
                    abilityIds: [SharksAndReefsAbilityIDs.consumeFishFromHandTwiceWhenPlayed],
                    abilityText: "[FishFromHandConsume][FishFromHandConsume]",
                    printedPoints: 4,
                    lengthCm: 50
                ),
                Card(
                    id: "sr.main.142",
                    name: "Blacktip Shark",
                    abilityIds: [SharksAndReefsAbilityIDs.greenCoralScatterSchoolWhenPlayed],
                    abilityText: "[GreenCoral][UnSchoolFish]",
                    printedPoints: 4,
                    lengthCm: 170
                ),
                Card(
                    id: "sr.main.152",
                    name: "Filetail Catshark",
                    abilityIds: [SharksAndReefsAbilityIDs.consumeFishFromHandIfActivated],
                    abilityText: "[FishFromHandConsume]",
                    printedPoints: 2,
                    lengthCm: 45
                ),
                Card(
                    id: "sr.main.170",
                    name: "Lollipop Catshark",
                    abilityIds: [SharksAndReefsAbilityIDs.freePlaySmallWhenPlayed],
                    abilityText: "[FreePlayFishFromHand][FishLengthSmall] only",
                    printedPoints: 3,
                    lengthCm: 29
                ),
                Card(
                    id: "sr.main.200",
                    name: "Swell Shark",
                    abilityIds: [SharksAndReefsAbilityIDs.freePlayCamouflageWhenPlayed],
                    abilityText: "[FreePlayFishFromHand][Camouflage] only",
                    tags: [CardTag(kind: "camouflage", count: 1)],
                    printedPoints: 4,
                    lengthCm: 110
                ),
                Card(
                    id: "sr.main.171",
                    name: "Blue Coral Ability Fish",
                    abilityIds: [SharksAndReefsAbilityIDs.blueCoralIfActivated],
                    printedPoints: 3,
                    lengthCm: 20
                ),
                Card(
                    id: "sr.main.194",
                    name: "Blue Purple Coral Ability Fish",
                    abilityIds: [SharksAndReefsAbilityIDs.bluePurpleCoralWhenPlayed],
                    printedPoints: 4,
                    lengthCm: 25
                ),
                Card(
                    id: "sr.main.210",
                    name: "Any Coral Ability Fish",
                    abilityIds: [SharksAndReefsAbilityIDs.anyCoralIfActivated],
                    printedPoints: 5,
                    lengthCm: 30
                )
            ]
        )
    }

    private func gameEndAbilityCatalog() -> TestCardCatalog {
        TestCardCatalog(
            fishCards: [
                Card(
                    id: "sr.gameEnd.anyCoral",
                    name: "Any Coral Game End Fish",
                    abilityIds: [SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd],
                    abilityText: "游戏结束：获得 2 个任意珊瑚",
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "sr.gameEnd.greenCoral",
                    name: "Green Coral Game End Fish",
                    abilityIds: [SharksAndReefsAbilityIDs.greenCoralThreeGameEnd],
                    abilityText: "游戏结束：获得 3 个绿色珊瑚",
                    printedPoints: 1,
                    lengthCm: 21
                ),
                Card(
                    id: "gameEnd.unsupported",
                    name: "Unsupported Game End Fish",
                    abilityIds: ["unsupported.test.gameEnd.card_999"],
                    abilityText: "游戏结束：未接入能力",
                    printedPoints: 1,
                    lengthCm: 22
                ),
                Card(
                    id: "gameEnd.noTokens",
                    name: "No Tokens Scoring Fish",
                    abilityIds: [BaseGameAbilityIDs.abyssalAnglerfishGameEnd],
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "gameEnd.youngTwo",
                    name: "Young Two Scoring Fish",
                    abilityIds: [BaseGameAbilityIDs.clownAnemonefishGameEnd],
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "gameEnd.bottomRow",
                    name: "Bottom Row Scoring Fish",
                    abilityIds: [BaseGameAbilityIDs.cookiecutterSharkGameEnd],
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "gameEnd.consumedOne",
                    name: "Consumed Scoring Fish",
                    abilityIds: [BaseGameAbilityIDs.commonFangtoothGameEnd],
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "gameEnd.allReefs3",
                    name: "All Reefs Scoring Fish",
                    abilityIds: [SharksAndReefsAbilityIDs.allDiveSitesCoralThreeGameEnd],
                    printedPoints: 0,
                    lengthCm: 20
                ),
                Card(
                    id: "gameEnd.anyReef5",
                    name: "Any Reef Scoring Fish",
                    abilityIds: [SharksAndReefsAbilityIDs.anyDiveSiteCoralFiveGameEnd],
                    printedPoints: 0,
                    lengthCm: 20
                ),
                Card(
                    id: "gameEnd.smallEgg",
                    name: "Small Egg Game End Fish",
                    abilityIds: [BaseGameAbilityIDs.binocularFishGameEnd],
                    printedPoints: 1,
                    lengthCm: 10
                ),
                Card(
                    id: "small.eligible",
                    name: "Small Eligible",
                    printedPoints: 1,
                    lengthCm: 10
                ),
                Card(
                    id: "small.hasEgg",
                    name: "Small Has Egg",
                    printedPoints: 1,
                    lengthCm: 10
                ),
                Card(
                    id: "medium.ineligible",
                    name: "Medium Ineligible",
                    printedPoints: 1,
                    lengthCm: 80
                ),
                Card(
                    id: "gameEnd.playBottom",
                    name: "Paid Bottom Game End Fish",
                    abilityIds: [BaseGameAbilityIDs.facelessCuskGameEnd],
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "paid.hand",
                    name: "Paid Hand Fish",
                    costs: [.discardCards(count: 1)],
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "payment.card",
                    name: "Payment Card",
                    printedPoints: 1,
                    lengthCm: 20
                )
            ]
        )
    }

    private func playFishForFreeCatalog() -> TestCardCatalog {
        TestCardCatalog(
            fishCards: [
                Card(id: "free.small", name: "Free Small", tags: [CardTag(kind: "camouflage", count: 1)], printedPoints: 1, lengthCm: 10),
                Card(id: "free.medium", name: "Free Medium", printedPoints: 1, lengthCm: 80),
                Card(
                    id: "free.costly",
                    name: "Free Costly",
                    costs: [.discardCards(count: 1), .resource(kind: .egg, count: 1), .resource(kind: .young, count: 1)],
                    printedPoints: 4,
                    lengthCm: 30
                ),
                Card(id: "discard-candidate", name: "Discard Candidate", printedPoints: 1, lengthCm: 5),
                Card(id: "free.sunlight", name: "Free Sunlight", allowedZones: [.sunlit], printedPoints: 2, lengthCm: 30),
                Card(id: "free.green", name: "Free Green", requiredDiveSiteColor: .green, printedPoints: 2, lengthCm: 30),
                Card(id: "free.cover", name: "Free Cover", costs: [.coverShorterFish(count: 1)], printedPoints: 5, lengthCm: 40),
                Card(
                    id: "free.reef",
                    name: "Free Reef",
                    requirements: [Requirement(coralRequirement: CoralRequirement(diveSite: .any, count: 2))],
                    printedPoints: 5,
                    lengthCm: 30
                ),
                Card(
                    id: "free.withAbility",
                    name: "Free With Ability",
                    abilityIds: ["fixture.free.whenPlayed.draw"],
                    printedPoints: 2,
                    lengthCm: 20
                )
            ]
        )
    }

    private func playFishForFreeResolver() -> AbilityResolver {
        AbilityResolver(
            provider: AbilityRegistry(
                definitions: [
                    AbilityDefinition(
                        abilityId: "fixture.free.whenPlayed.draw",
                        trigger: .whenPlayed,
                        effects: [.drawFish(count: 1)],
                        displayText: "打出时：抽 1 张鱼牌"
                    )
                ]
            )
        )
    }

    private func playFishForFreeIfActivatedCatalog() -> TestCardCatalog {
        TestCardCatalog(
            fishCards: playFishForFreeCatalog().fishCards + [
                Card(
                    id: "fixture.if.free",
                    name: "If Activated Free Play Fixture",
                    abilityIds: ["fixture.ifActivated.playFishForFree"],
                    printedPoints: 1,
                    lengthCm: 20
                )
            ]
        )
    }

    private func playFishForFreeIfActivatedResolver() -> AbilityResolver {
        AbilityResolver(
            provider: AbilityRegistry(
                definitions: [
                    AbilityDefinition(
                        abilityId: "fixture.ifActivated.playFishForFree",
                        trigger: .ifActivated,
                        effects: [.playFishForFree(filter: .any, count: 1)],
                        isOptional: true,
                        displayText: "发动时：免费打出手牌鱼"
                    )
                ]
            )
        )
    }

    private func consumeFishCatalog() -> TestCardCatalog {
        TestCardCatalog(
            fishCards: [
                Card(id: "consume.consumer", name: "Consumer Fish", printedPoints: 5, lengthCm: 40),
                Card(id: "consume.short", name: "Short Fish", printedPoints: 1, lengthCm: 10),
                Card(id: "consume.same", name: "Same Fish", printedPoints: 1, lengthCm: 40),
                Card(id: "consume.long", name: "Long Fish", printedPoints: 1, lengthCm: 60)
            ]
        )
    }

    private func scatterSchoolIfActivatedCatalog() -> TestCardCatalog {
        TestCardCatalog(
            fishCards: [
                Card(
                    id: "fixture.if.scatter",
                    name: "If Activated Scatter Fixture",
                    abilityIds: ["fixture.ifActivated.scatterSchool"],
                    printedPoints: 1,
                    lengthCm: 10
                )
            ]
        )
    }

    private func scatterSchoolIfActivatedResolver() -> AbilityResolver {
        AbilityResolver(
            provider: AbilityRegistry(
                definitions: [
                    AbilityDefinition(
                        abilityId: "fixture.ifActivated.scatterSchool",
                        trigger: .ifActivated,
                        effects: [.scatterSchool(count: 1)],
                        displayText: "发动时：打散鱼群"
                    )
                ]
            )
        )
    }

    private func setResources(
        _ resources: [ResourceQuantity],
        at address: OceanSlotAddress,
        in state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[address.playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == address })
        else {
            return
        }

        playerState.ocean.slots[slotIndex].resources = resources
        state.playerGameStates[address.playerId] = playerState
    }

    private func clearResources(for playerId: PlayerID, in state: inout GameState) {
        guard var playerState = state.playerGameStates[playerId] else {
            return
        }
        for index in playerState.ocean.slots.indices {
            playerState.ocean.slots[index].resources = []
        }
        state.playerGameStates[playerId] = playerState
    }

    private func clearOceanContent(for playerId: PlayerID, in state: inout GameState) {
        guard var playerState = state.playerGameStates[playerId] else {
            return
        }
        for index in playerState.ocean.slots.indices {
            playerState.ocean.slots[index].content = .empty
        }
        state.playerGameStates[playerId] = playerState
    }

    private func gameEndAbilityState(cardIds: [CardID]) -> GameState {
        var state = playFishState()
        state.phase = .endGamePending
        state.activePlayerId = nil
        state.pendingChoices = [:]
        state.playerGameStates["player-1"]?.ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        clearOceanContent(for: "player-1", in: &state)
        for (index, cardId) in cardIds.enumerated() {
            setContent(
                .fishCard(cardId),
                at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: index),
                in: &state
            )
        }
        return state
    }

    private func gameEndAbilitySource(
        cardId: CardID,
        abilityId: AbilityID,
        rowIndex: Int = 0
    ) -> GameEndAbilitySource {
        GameEndAbilitySource(
            playerId: "player-1",
            slotAddress: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: rowIndex),
            cardId: cardId,
            abilityId: abilityId
        )
    }

    private func resolveAnyCoralGameEndAbility(
        source: GameEndAbilitySource,
        in state: GameState,
        using engine: GameEngine
    ) throws -> GameState {
        var state = applying(
            try engine.makeEventDrafts(
                for: activateGameEndAbilityCommand(commandId: "activate-\(source.cardId)", source: source),
                in: state
            ),
            to: state,
            using: engine
        )
        var choice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "choose-first-\(source.cardId)",
                    choiceId: choice.choiceId,
                    resolution: .chooseAbilityEffect(.gainCoral(selector: .any, count: 1))
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        choice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "resolve-first-\(source.cardId)",
                    choiceId: choice.choiceId,
                    resolution: .gainCoralFromAbility(diveSite: .green)
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        choice = try XCTUnwrap(state.pendingChoices.values.first)
        state = applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "choose-second-\(source.cardId)",
                    choiceId: choice.choiceId,
                    resolution: .chooseAbilityEffect(.gainCoral(selector: .any, count: 1))
                ),
                in: state
            ),
            to: state,
            using: engine
        )
        choice = try XCTUnwrap(state.pendingChoices.values.first)
        return applying(
            try engine.makeEventDrafts(
                for: resolveCommand(
                    commandId: "resolve-second-\(source.cardId)",
                    choiceId: choice.choiceId,
                    resolution: .gainCoralFromAbility(diveSite: .blue)
                ),
                in: state
            ),
            to: state,
            using: engine
        )
    }

    private func setContent(
        _ content: OceanSlotContent,
        at address: OceanSlotAddress,
        in state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[address.playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == address })
        else {
            return
        }

        playerState.ocean.slots[slotIndex].content = content
        state.playerGameStates[address.playerId] = playerState
    }

    private func setConsumedFish(
        _ consumedFish: [ConsumedFish],
        at address: OceanSlotAddress,
        in state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[address.playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == address })
        else {
            return
        }

        playerState.ocean.slots[slotIndex].consumedFish = consumedFish
        state.playerGameStates[address.playerId] = playerState
    }

}

private struct TestCardCatalog: CardCatalog {
    var starterFishCards: [Card] = []
    var fishCards: [Card] = []
}

private extension DomainEventDraft {
    var isPendingChoiceCreated: Bool {
        if case .pendingChoiceCreated = self {
            return true
        }
        return false
    }

    var isTurnCompletion: Bool {
        switch self {
        case .turnAdvanced,
             .weekEnded:
            return true
        default:
            return false
        }
    }
}

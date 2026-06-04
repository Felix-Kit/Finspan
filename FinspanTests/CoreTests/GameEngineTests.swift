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

    func testActionEndsWeekWhenAllDiversUsedAndNoPendingChoices() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0

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

    func testFourthWeekEndAutomaticallyGeneratesGameEndedAndStoresFinalScore() throws {
        let engine = GameEngine()
        var state = playFishState()
        state.currentWeek = 4
        state.firstPlayerId = "player-1"
        state.playerGameStates["player-1"]?.availableDivers = 1
        state.playerGameStates["player-2"]?.availableDivers = 0

        let drafts = try engine.makeEventDrafts(
            for: PlayerCommand(
                commandId: "fourth-week-final-dive",
                playerId: "player-1",
                roomId: roomId,
                payload: .dive(DiveCommand(diveSite: .blue))
            ),
            in: state
        )

        guard case let .weekEnded(weekEnded) = drafts[drafts.count - 2],
              case let .gameEnded(gameEnded) = drafts.last
        else {
            return XCTFail("Expected weekEnded followed by gameEnded.")
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
        let gameEndedState = engine.reduce(
            state: endGamePendingState,
            event: GameEvent(
                sequenceNumber: 11,
                roomId: roomId,
                timestamp: timestamp,
                payload: .gameEnded(gameEnded)
            )
        )

        XCTAssertEqual(endGamePendingState.phase, .endGamePending)
        XCTAssertEqual(gameEndedState.phase, .gameEnded)
        XCTAssertEqual(gameEndedState.finalScoreResult, gameEnded.finalScoreResult)
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
            [ConsumedFish(cardId: "consumed-1"), ConsumedFish(cardId: "consumed-2")],
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
        XCTAssertEqual(playerResult?.totalPoints, 32)
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

    func testPlayFishRejectsForageFishTargetSlot() {
        let engine = GameEngine()
        let state = playFishState(keepForageFish: true)
        let targetSlot = OceanSlotAddress(
            playerId: "player-1",
            diveSite: .blue,
            rowIndex: 4
        )

        XCTAssertThrowsError(
            try engine.makeEventDrafts(
                for: PlayerCommand(
                    commandId: "play-fish-forage-target",
                    playerId: "player-1",
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(
                            cardId: "fish-1",
                            targetSlot: targetSlot,
                            payment: PlayFishPayment(
                                discardedCardIds: ["fish-6"],
                                eggSources: [],
                                youngSources: []
                            )
                        )
                    )
                ),
                in: state
            )
        ) { error in
            XCTAssertEqual(error as? CommandValidationError, .targetSlotOccupied(targetSlot))
        }
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

        XCTAssertEqual(
            drafts,
            [
                .diverMoved(
                    DiverMovedEvent(
                        playerId: "player-1",
                        diveSite: .blue,
                        bottomBonusAvailable: true,
                        bottomBonusClaimed: true,
                        nextActivePlayerId: nil
                    )
                ),
                .pendingChoiceCreated(
                    PendingChoice(
                        choiceId: "dive-blue-dive-bonus-3",
                        playerId: "player-1",
                        source: .diveBonus(.blue),
                        kind: .recoverFromDiscardOrDraw,
                        options: [],
                        expectedInput: .cardSelection,
                        isOptional: true,
                        createdAtSequence: 0
                    )
                )
            ]
        )
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
            drafts.contains(
                .pendingChoiceCreated(
                    PendingChoice(
                        choiceId: "dive-blue-zone-bonus-dive-bonus-0",
                        playerId: "player-1",
                        source: .diveBonus(.blue),
                        kind: .drawFish,
                        options: [],
                        expectedInput: .none,
                        isOptional: true,
                        createdAtSequence: 0
                    )
                )
            )
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
            drafts.contains(
                .pendingChoiceCreated(
                    PendingChoice(
                        choiceId: "dive-blue-forage-bonus-dive-bonus-2",
                        playerId: "player-1",
                        source: .diveBonus(.blue),
                        kind: .drawFish,
                        options: [],
                        expectedInput: .none,
                        isOptional: true,
                        createdAtSequence: 0
                    )
                )
            )
        )
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
            DiveBonusDefinition(diveSite: .green, position: .zone(.sunlit), kind: .placeEgg, amount: 1),
            DiveBonusDefinition(diveSite: .green, position: .zone(.twilight), kind: .placeEgg, amount: 1),
            DiveBonusDefinition(diveSite: .green, position: .zone(.midnight), kind: .placeEgg, amount: 1),
            DiveBonusDefinition(diveSite: .green, position: .bottom, kind: .placeEgg, amount: 1)
        ])
        XCTAssertEqual(layout.bonuses(for: .purple), [
            DiveBonusDefinition(diveSite: .purple, position: .zone(.sunlit), kind: .hatchEgg, amount: 1),
            DiveBonusDefinition(diveSite: .purple, position: .zone(.twilight), kind: .hatchEgg, amount: 1),
            DiveBonusDefinition(diveSite: .purple, position: .zone(.midnight), kind: .moveYoungOrSchool, amount: 1),
            DiveBonusDefinition(diveSite: .purple, position: .bottom, kind: .moveYoungOrSchool, amount: 1)
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
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 0)
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
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 0)
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
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 0)
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

    func testMoveSchoolMovesOneSchoolToEmptySchoolTarget() throws {
        let engine = GameEngine()
        var state = playFishState()
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let source = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .green, rowIndex: 0)
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
             .hatchEgg:
            return .targetSlot
        case .recoverFromDiscardOrDraw:
            return .cardSelection
        case .moveYoungOrSchool:
            return .sourceAndTargetSlots
        case .drawFish,
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

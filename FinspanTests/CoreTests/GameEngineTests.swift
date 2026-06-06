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
             .hatchEgg:
            return .targetSlot
        case .recoverFromDiscardOrDraw:
            return .cardSelection
        case .moveYoungOrSchool:
            return .sourceAndTargetSlots
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

    private func coverShorterFishState(keepForageFish: Bool = false) -> GameState {
        var state = playFishState(keepForageFish: keepForageFish)
        state.playerGameStates["player-1"]?.hand.append("cover-fish")
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

import XCTest
@testable import Finspan

@MainActor
final class GameBoardViewModelTests: XCTestCase {
    func testSubmitPlayFishBuildsPlayerCommandFromSelection() {
        let slotAddress = Self.slotAddress
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }

        XCTAssertEqual(service.submittedCommands.last?.playerId, "player-1")
        XCTAssertEqual(service.submittedCommands.last?.roomId, "room-1")
        XCTAssertEqual(payload.cardId, "starter-fish-1")
        XCTAssertEqual(payload.targetSlot, slotAddress)
        XCTAssertEqual(payload.payment, PlayFishPayment.empty)
    }

    func testUsesCatalogProviderForBaseGameCards() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(hand: ["base.main.057"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )

        XCTAssertEqual(viewModel.handCards.first?.title, "Great White Shark")

        viewModel.selectHandCard("base.main.057")

        XCTAssertEqual(viewModel.selectedFishCardDetails?.title, "Great White Shark")
        XCTAssertEqual(viewModel.selectedFishCardDetails?.lengthText, "600 厘米")
    }

    func testTopBarViewStateShowsCurrentWeek() {
        let service = makeService(hand: [], currentWeek: 1)
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.topBarViewState.weekText, "第 1 周")
    }

    func testTopBarViewStateShowsActivePlayerAndDivers() {
        let service = makeService(hand: [], availableDivers: 4)
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.topBarViewState.activePlayerText, "当前：玩家 1")
        XCTAssertEqual(viewModel.topBarViewState.diverText, "潜水员 4 / 6")
    }

    func testTopBarViewStateSummarizesActivePlayerResources() {
        let service = makeService(
            hand: [],
            resourceSourceResources: [
                ResourceQuantity(kind: .egg, amount: 2),
                ResourceQuantity(kind: .young, amount: 1),
                ResourceQuantity(kind: .school, amount: 3)
            ],
            clearAllSlotResources: true
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.topBarViewState.resourceSummaryText, "鱼卵 2 · 幼鱼 1 · 鱼群 3")
    }

    func testTopBarViewStateShowsPlayerCountAndLogEntry() {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.topBarViewState.playerCountText, "1 人")
        XCTAssertTrue(viewModel.topBarViewState.canShowLog)
        XCTAssertEqual(viewModel.topBarViewState.logButtonText, "日志")
    }

    func testGameHudViewStateShowsPlayerAvatarsAndActivePlayer() {
        let service = makeService(
            hand: [],
            additionalPlayers: [
                RoomPlayer(playerId: "player-2", displayName: "玩家 2", color: .green)
            ]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let playerHud = viewModel.gameHudViewState.playerHud

        XCTAssertEqual(playerHud.players.map(\.playerId), ["player-1", "player-2"])
        XCTAssertEqual(playerHud.players.map(\.avatarText), ["1", "2"])
        XCTAssertEqual(playerHud.players.first { $0.playerId == "player-1" }?.isActive, true)
        XCTAssertEqual(playerHud.players.first { $0.playerId == "player-2" }?.isActive, false)
        XCTAssertEqual(playerHud.playerCountText, "2 人")
    }

    func testGameHudTopPlayerHudDoesNotExposeDiversOrResources() {
        let service = makeService(hand: [], availableDivers: 4)
        let viewModel = GameBoardViewModel(roomService: service)
        let hudText = viewModel.gameHudViewState.playerHud.players
            .flatMap { [$0.displayName, $0.avatarText, $0.colorName ?? ""] }
            .joined(separator: " ")

        XCTAssertFalse(hudText.contains("潜水员"))
        XCTAssertFalse(hudText.contains("鱼卵"))
        XCTAssertFalse(hudText.contains("幼鱼"))
        XCTAssertFalse(hudText.contains("鱼群"))
    }

    func testLastActionSummaryShowsFishPlayedCardName() {
        let event = gameEvent(
            .fishPlayed(
                FishPlayedEvent(
                    playerId: "player-1",
                    cardId: "starter-fish-1",
                    targetSlot: Self.slotAddress,
                    payment: .empty,
                    nextActivePlayerId: "player-1"
                )
            )
        )
        let service = makeService(hand: [], eventLog: [event])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.lastActionSummaryText, "玩家 1 打出：Starter Fish 1")
    }

    func testLastActionSummaryShowsDiveSiteName() {
        let event = gameEvent(
            .diverMoved(
                DiverMovedEvent(
                    playerId: "player-1",
                    diveSite: .green,
                    bottomBonusAvailable: false,
                    bottomBonusClaimed: false,
                    nextActivePlayerId: "player-1"
                )
            )
        )
        let service = makeService(hand: [], eventLog: [event])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.lastActionSummaryText, "玩家 1 潜水：绿色潜水点")
    }

    func testLastActionSummaryShowsResolvedRewardType() {
        let event = gameEvent(
            .pendingChoiceResolved(
                PendingChoiceResolvedEvent(
                    choiceId: "choice-1",
                    playerId: "player-1",
                    resolution: .chooseTarget(Self.slotAddress),
                    appliedEffects: [.placeEgg(target: Self.slotAddress, amount: 1)]
                )
            )
        )
        let service = makeService(hand: [], eventLog: [event])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.lastActionSummaryText, "玩家 1 放置鱼卵")
    }

    func testLastActionSummaryShowsWeekEnded() {
        let event = gameEvent(
            .weekEnded(
                WeekEndedEvent(
                    endedWeek: 2,
                    nextWeek: 3,
                    previousFirstPlayerId: "player-1",
                    nextFirstPlayerId: "player-1",
                    nextActivePlayerId: "player-1",
                    isGameEndTriggered: false
                )
            )
        )
        let service = makeService(hand: [], eventLog: [event])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.lastActionSummaryText, "第 2 周结束")
    }

    func testLastActionSummaryShowsGameEnded() {
        let event = gameEvent(
            .gameEnded(GameEndedEvent(finalScoreResult: emptyFinalScoreResult()))
        )
        let service = makeService(hand: [], eventLog: [event])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.lastActionSummaryText, "游戏结束，进入结算")
    }

    func testHudToastShowsGameStartedSummaryAndAutoDismisses() async throws {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.hudToastViewState?.text, AppStrings.GameBoard.gameStartedSummary)

        try await Task.sleep(nanoseconds: 2_000_000_000)

        XCTAssertNil(viewModel.hudToastViewState)
    }

    func testSelectingOpponentAvatarOnlyRecordsPreviewState() {
        let service = makeService(
            hand: [],
            additionalPlayers: [
                RoomPlayer(playerId: "player-2", displayName: "玩家 2", color: .green)
            ]
        )
        let originalState = service.gameState
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectPlayerAvatar("player-2")

        XCTAssertEqual(service.gameState, originalState)
        XCTAssertEqual(viewModel.selectedViewedPlayerId, "player-2")
        XCTAssertEqual(viewModel.opponentBoardPreviewMessage, AppStrings.GameBoard.opponentBoardPreviewUnavailable)
        XCTAssertEqual(viewModel.state.activePlayerId, "player-1")
    }

    func testSidePlayerInfoViewStateShowsActivePlayerResourcesAndDivers() {
        let service = makeService(
            hand: ["starter-fish-1", "fish-2"],
            availableDivers: 4,
            resourceSourceResources: [
                ResourceQuantity(kind: .egg, amount: 2),
                ResourceQuantity(kind: .young, amount: 1),
                ResourceQuantity(kind: .school, amount: 3)
            ],
            clearAllSlotResources: true
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let info = viewModel.sidePlayerInfoViewState

        XCTAssertEqual(info.playerName, "玩家 1")
        XCTAssertEqual(info.diverSummaryText, "潜水员 4 / 6")
        XCTAssertEqual(info.eggCount, 2)
        XCTAssertEqual(info.youngCount, 1)
        XCTAssertEqual(info.schoolCount, 3)
    }

    func testRightActionPanelShowsPlayFishConfirmationWhenTargetSelected() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("starter-fish-1")
        viewModel.selectTargetSlot(Self.slotAddress)

        let action = viewModel.rightActionPanelViewState
        XCTAssertEqual(action.actionKind, .playFishPayment)
        XCTAssertEqual(action.primaryButtonTitle, AppStrings.GameBoard.confirmPlayFish)
        XCTAssertTrue(action.isPrimaryButtonEnabled)
        XCTAssertEqual(action.secondaryButtonTitle, AppStrings.GameBoard.cancelPlayFish)
        XCTAssertTrue(action.isSecondaryButtonVisible)
        XCTAssertEqual(viewModel.rightSidePanelViewState.presentation, .expanded)
    }

    func testRightSidePanelIsCompactWhenThereIsNoPendingActionOrReward() {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.rightActionPanelViewState.actionKind, .none)
        XCTAssertFalse(viewModel.rewardPoolViewState.isActive)
        XCTAssertEqual(viewModel.rightSidePanelViewState.presentation, .compact)
        XCTAssertEqual(viewModel.rightSidePanelViewState.compactSubtitle, AppStrings.GameBoard.compactRightPanelEmpty)
    }

    func testRightActionPanelDisablesPlayFishConfirmationUntilPaymentComplete() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)

        let incompleteAction = viewModel.rightActionPanelViewState
        XCTAssertEqual(incompleteAction.actionKind, .playFishPayment)
        XCTAssertFalse(incompleteAction.isPrimaryButtonEnabled)

        viewModel.toggleEggSource(Self.resourceSourceAddress)

        XCTAssertTrue(viewModel.rightActionPanelViewState.isPrimaryButtonEnabled)
    }

    func testRightActionPanelShowsPendingChoiceAndSkipAction() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: [], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let action = viewModel.rightActionPanelViewState

        XCTAssertEqual(action.actionKind, .pendingChoice)
        XCTAssertEqual(action.pendingChoiceId, choice.choiceId)
        XCTAssertEqual(action.primaryButtonTitle, AppStrings.GameBoard.skipChoice)
        XCTAssertTrue(action.isPrimaryButtonEnabled)
        XCTAssertEqual(viewModel.rightSidePanelViewState.presentation, .expanded)
    }

    func testRewardTokenSelectionUpdatesRightActionPanelSummary() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        guard let token = viewModel.rewardPoolViewState.rewards.first else {
            return XCTFail("Expected reward token.")
        }

        viewModel.selectRewardToken(token.id)

        let action = viewModel.rightActionPanelViewState
        XCTAssertEqual(action.actionKind, .rewardSelection)
        XCTAssertTrue(action.summaryLines.contains(AppStrings.GameBoard.choosePlaceEggTarget))
    }

    func testWeeklyGoalHudShowsFourBoxesAndCurrentWeek() {
        let service = makeService(hand: [], currentWeek: 3)
        let viewModel = GameBoardViewModel(roomService: service)
        let boxes = viewModel.weeklyGoalHudViewState.boxes

        XCTAssertEqual(boxes.count, 4)
        XCTAssertEqual(boxes.map(\.index), [1, 2, 3, 4])
        XCTAssertEqual(boxes.first { $0.index == 3 }?.isCurrent, true)
        XCTAssertEqual(boxes.first { $0.index == 4 }?.isGameEndBox, true)
    }

    func testWeeklyGoalHudHighlightsFourthBoxDuringEndGameWeek() {
        let service = makeService(hand: [], phase: .endGamePending, currentWeek: 4)
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.weeklyGoalHudViewState.boxes.first { $0.index == 4 }?.isCurrent, true)
    }

    func testSelectingWeeklyGoalBoxOpensDetailWithOnlyFirstThreeWeeklyScores() {
        let result = WeeklyAchievementResult(
            week: 1,
            kind: .eggsAndYoung,
            playerId: "player-1",
            quantity: 4,
            points: 4
        )
        let service = makeService(
            hand: [],
            weeklyAchievementResults: [result]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectWeeklyGoalBox(4)

        guard let detail = viewModel.weeklyGoalDetailViewState else {
            return XCTFail("Expected weekly goal detail.")
        }
        XCTAssertEqual(detail.weeklyScoreItems.map(\.index), [1, 2, 3])
        XCTAssertEqual(detail.gameEndInfo.title, AppStrings.GameBoard.gameEndGoalTitle)
        XCTAssertEqual(detail.noteText, AppStrings.GameBoard.finalScoreHiddenHint)
        XCTAssertEqual(detail.weeklyScoreItems.first?.playerScores.first?.scoreText, "4 分")
    }

    func testEventLogButtonTogglesPresentedState() {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.isEventLogPresented)

        viewModel.showEventLog()
        XCTAssertTrue(viewModel.isEventLogPresented)

        viewModel.hideEventLog()
        XCTAssertFalse(viewModel.isEventLogPresented)
    }

    func testHudLeftControlsContainSettingsAndLogButtons() {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)
        let controls = viewModel.gameHudViewState.leftControls

        XCTAssertEqual(controls.placement, .topLeft)
        XCTAssertEqual(controls.settingsButtonText, AppStrings.GameBoard.settings)
        XCTAssertEqual(controls.logButtonText, AppStrings.GameBoard.logButton)
        XCTAssertTrue(controls.canShowLog)
        XCTAssertEqual(viewModel.gameHudViewState.weeklyGoalHud.boxes.count, 4)
    }

    func testSettingsMenuViewStateShowsTemporaryExitAndDissolveActions() {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)
        let settings = viewModel.settingsMenuViewState

        XCTAssertEqual(settings.title, AppStrings.GameBoard.settings)
        XCTAssertEqual(
            settings.temporarilyExitGameAndReturnHomeText,
            AppStrings.GameBoard.temporarilyExitGameAndReturnHome
        )
        XCTAssertEqual(
            settings.dissolveCurrentGameAndReturnHomeText,
            AppStrings.GameBoard.dissolveCurrentGameAndReturnHome
        )
        XCTAssertEqual(
            settings.dissolveConfirmationTitle,
            AppStrings.GameBoard.dissolveCurrentGameConfirmTitle
        )
        XCTAssertEqual(settings.cancelText, AppStrings.GameBoard.cancel)
    }

    func testDiveActionBarViewStateShowsThreeDiveButtons() {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)
        let buttons = viewModel.diveActionBarViewState.buttons

        XCTAssertEqual(viewModel.diveActionBarViewState.title, AppStrings.GameBoard.divePanel)
        XCTAssertEqual(buttons.map(\.diveSite), [.blue, .purple, .green])
        XCTAssertEqual(buttons.map(\.title), [
            AppStrings.diveActionSiteName(.blue),
            AppStrings.diveActionSiteName(.purple),
            AppStrings.diveActionSiteName(.green)
        ])
        XCTAssertTrue(buttons.allSatisfy(\.isEnabled))
        XCTAssertTrue(buttons.allSatisfy { $0.disabledReasonText == nil })
    }

    func testDiveActionBarDisablesButtonsWhenNoDiversRemain() {
        let service = makeService(hand: [], availableDivers: 0)
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.diveActionBarViewState.buttons.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(viewModel.diveActionBarViewState.buttons.allSatisfy {
            $0.disabledReasonText == AppStrings.GameBoard.diversUsedThisWeek
        })
    }

    func testDiveActionBarDisablesButtonsDuringPendingChoice() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: [], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.diveActionBarViewState.buttons.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(viewModel.diveActionBarViewState.buttons.allSatisfy {
            $0.disabledReasonText == AppStrings.GameBoard.resolveCurrentRewardFirst
        })
    }

    func testDiveActionBarDisablesButtonsDuringActiveDiveQueue() {
        let queue = activeDiveQueue(diveSite: .blue, source: .printedDiveBonus(.sunlit))
        let service = makeService(hand: [], activeDiveQueue: queue)
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.canDive)
        XCTAssertTrue(viewModel.diveActionBarViewState.buttons.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(viewModel.diveActionBarViewState.buttons.allSatisfy {
            $0.disabledReasonText == AppStrings.GameBoard.resolveCurrentDiveRewardFirst
        })
    }

    func testSubmitPlayFishIncludesSelectedEggSources() {
        let slotAddress = Self.slotAddress
        let sourceAddress = Self.resourceSourceAddress
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.toggleEggSource(sourceAddress)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }

        XCTAssertEqual(payload.cardId, "fish-2")
        XCTAssertEqual(payload.targetSlot, slotAddress)
        XCTAssertEqual(payload.payment.eggSources, [sourceAddress])
        XCTAssertEqual(payload.payment.youngSources, [])
        XCTAssertEqual(payload.payment.discardedCardIds, [])
    }

    func testSubmitPlayFishIncludesSelectedYoungSources() {
        let slotAddress = Self.slotAddress
        let sourceAddress = Self.resourceSourceAddress
        let service = makeService(hand: ["fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-3")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.toggleYoungSource(sourceAddress)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }

        XCTAssertEqual(payload.cardId, "fish-3")
        XCTAssertEqual(payload.targetSlot, slotAddress)
        XCTAssertEqual(payload.payment.eggSources, [])
        XCTAssertEqual(payload.payment.youngSources, [sourceAddress])
        XCTAssertEqual(payload.payment.discardedCardIds, [])
    }

    func testResourceSourceOptionsAreNotFilteredByTargetSlot() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)

        XCTAssertTrue(
            viewModel.eggSourceOptions.contains { $0.address == Self.resourceSourceAddress }
        )
        XCTAssertNotEqual(Self.slotAddress, Self.resourceSourceAddress)
    }

    func testHandViewStateIsGeneratedFromActivePlayerHand() {
        let service = makeService(hand: ["starter-fish-1", "fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.handViewState.cards.map(\.cardId), ["starter-fish-1", "fish-1"])
        XCTAssertEqual(viewModel.handViewState.cards.first?.costSummaryText, AppStrings.GameBoard.noCost)
        XCTAssertEqual(viewModel.handViewState.cards.first?.abilitySummaryText, AppStrings.GameBoard.unsupportedAbilityInUI)
    }

    func testHandCardFaceUsesSharedCardAspectRatio() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)
        let card = viewModel.handViewState.cards.first

        XCTAssertEqual(CardRenderMetrics.cardAspectRatio, 61.0 / 40.0)
        XCTAssertEqual(card?.cardFace.kind, .fishCard)
        XCTAssertEqual(card?.cardFace.displayName, "Starter Fish 1")
        XCTAssertEqual(card?.cardFace.aspectRatio, CardRenderMetrics.cardAspectRatio)
        XCTAssertEqual(card?.cardWidth, CardRenderMetrics.handCardWidth)
        XCTAssertEqual(card?.cardHeight, CardRenderMetrics.handCardHeight)
        XCTAssertEqual(card?.scale, 1)
    }

    func testHandSlotAndDiscardPileReuseSameCompleteFishCardFaceData() {
        let service = makeService(
            hand: ["fish-4"],
            emptySlots: [Self.slotAddress],
            discardPile: ["fish-4"]
        )
        setContent(.fishCard("fish-4"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(roomService: service)

        let handFace = viewModel.handViewState.cards.first?.cardFace
        let slotFace = oceanSlot(in: viewModel, address: Self.slotAddress).cardFace
        let discardFace = viewModel.discardPileViewState.topCards.first

        XCTAssertEqual(handFace, slotFace)
        XCTAssertEqual(handFace, discardFace)
        XCTAssertEqual(handFace?.backgroundAssetPrefix, "green")
        XCTAssertEqual(handFace?.zoneIcons.map { $0.assetName }, ["Dusk"])
        XCTAssertEqual(handFace?.costIcons.map { $0.assetName }, ["NoCost"])
    }

    func testCardFaceBackgroundAssetUsesDiveSiteBandOrBase() {
        let service = makeService(hand: ["starter-fish-1", "fish-4"])
        let viewModel = GameBoardViewModel(roomService: service)
        let faces = Dictionary(uniqueKeysWithValues: viewModel.handViewState.cards.map { ($0.cardId, $0.cardFace) })

        XCTAssertEqual(faces["starter-fish-1"]?.backgroundAssetPrefix, "base")
        XCTAssertEqual(faces["fish-4"]?.backgroundAssetPrefix, "green")
    }

    func testCardFaceAbilityTokenParserRecognizesKnownTokensAndUsesSafeUnknownFallback() {
        let segments = FishCardAbilityTokenParser.parse("[FishEgg] [YoungFish] [School] [Card] [Wave] {ArrowDown} {PlayFishBottomRow} [Mystery]")

        XCTAssertEqual(
            segments,
            [
                .icon(FishCardFaceIconViewState(assetName: "FishEgg", fallbackText: "卵", accessibilityText: "鱼卵")),
                .icon(FishCardFaceIconViewState(assetName: "YoungFish", fallbackText: "幼", accessibilityText: "幼鱼")),
                .icon(FishCardFaceIconViewState(assetName: "SchoolFish", fallbackText: "群", accessibilityText: "鱼群")),
                .icon(FishCardFaceIconViewState(assetName: "FishFromHand", fallbackText: "手牌", accessibilityText: "从手牌打出鱼")),
                .icon(FishCardFaceIconViewState(assetName: "Wave", fallbackText: "分", accessibilityText: "分数")),
                .icon(FishCardFaceIconViewState(assetName: "ArrowDown", fallbackText: "向下", accessibilityText: "向下")),
                .icon(FishCardFaceIconViewState(assetName: "PlayFishBottomRow", fallbackText: "底行出鱼", accessibilityText: "底行出鱼")),
                .icon(FishCardFaceIconViewState(assetName: "UnknownToken", fallbackText: "?", accessibilityText: "未知图标 Mystery"))
            ]
        )
    }

    func testBaseGameCardFaceUsesLocalFishImageSourceIdAndTokenizedAbility() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(hand: ["base.main.001"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )
        let cardFace = viewModel.handViewState.cards.first?.cardFace

        XCTAssertEqual(cardFace?.localFishImagePrefix, "1")
        XCTAssertFalse(cardFace?.backgroundAssetPrefix.contains("http") ?? true)
        XCTAssertTrue(cardFace?.abilitySegments.contains(.icon(FishCardFaceIconViewState(assetName: "Wave", fallbackText: "分", accessibilityText: "分数"))) ?? false)
    }

    func testScannedRuntimeAbilityTokensAreCoveredByCardFaceParser() {
        let scannedRuntimeTokens: Set<String> = [
            "AllPlayers",
            "ArrowDown",
            "ConsumeFish1",
            "ConsumeFish2",
            "ConsumeFish3",
            "Discard",
            "DrawCard",
            "Estuary",
            "FishEgg",
            "FishFromHand",
            "FishHatch",
            "FishLengthLarge",
            "FishLengthMedium",
            "FishLengthSmall",
            "FlipperBlue",
            "FlipperGreen",
            "FlipperPurple",
            "PlayFishBottomRow",
            "Predator",
            "SchoolFeederMove",
            "SchoolFish",
            "Sun",
            "Wave",
            "YoungFish"
        ]

        XCTAssertTrue(scannedRuntimeTokens.isSubset(of: FishCardAbilityTokenParser.supportedTokenNames))
    }

    func testAbyssalHalosaurCardFaceMapsRealTokensToIcons() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(hand: ["base.main.002"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )
        let cardFace = try XCTUnwrap(viewModel.handViewState.cards.first?.cardFace)

        XCTAssertEqual(cardFace.displayName, "Abyssal Halosaur")
        XCTAssertEqual(cardFace.localFishImagePrefix, "2")
        XCTAssertEqual(cardFace.backgroundAssetPrefix, "base")
        XCTAssertEqual(cardFace.costIcons.map(\.assetName), ["YoungFish"])
        XCTAssertEqual(cardFace.zoneIcons.map(\.assetName), ["Night"])
        XCTAssertEqual(cardFace.sizeClassIcon.assetName, "FishLengthMedium")
        XCTAssertEqual(cardFace.abilityPanelStyle, .none)
        XCTAssertEqual(cardFace.printedPointsText, "3分")
        XCTAssertEqual(cardFace.lengthText, "90 厘米")
        XCTAssertEqual(cardFace.abilityTriggerText, AppStrings.GameBoard.abilityTriggerWhenPlayed)
        XCTAssertEqual(
            cardFace.abilitySegments,
            [
                .icon(FishCardFaceIconViewState(assetName: "FishFromHand", fallbackText: "手牌", accessibilityText: "从手牌打出鱼")),
                .icon(FishCardFaceIconViewState(assetName: "ArrowDown", fallbackText: "向下", accessibilityText: "向下")),
                .icon(FishCardFaceIconViewState(assetName: "PlayFishBottomRow", fallbackText: "底行出鱼", accessibilityText: "底行出鱼"))
            ]
        )
        XCTAssertFalse(cardFace.abilitySegments.containsRawToken("ArrowDown"))
        XCTAssertFalse(cardFace.abilitySegments.containsRawToken("PlayFishBottomRow"))
        XCTAssertFalse(cardFace.abilitySegments.containsText("牌"))
    }

    func testBluespineUnicornfishUsesIfActivatedTanAbilityPanel() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(hand: ["base.main.025"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )
        let cardFace = try XCTUnwrap(viewModel.handViewState.cards.first?.cardFace)

        XCTAssertEqual(cardFace.displayName, "Bluespine Unicornfish")
        XCTAssertEqual(cardFace.abilityTriggerText, AppStrings.GameBoard.abilityTriggerIfActivated)
        XCTAssertEqual(cardFace.abilityPanelStyle, .tanBrush)
        XCTAssertEqual(cardFace.abilityStripAssetPrefix, "IfActivated")
        XCTAssertTrue(cardFace.abilitySegments.contains(.text("(all players)")))
        XCTAssertTrue(cardFace.abilitySegments.contains(.icon(FishCardFaceIconViewState(assetName: "FishHatch", fallbackText: "孵", accessibilityText: "孵化"))))
        XCTAssertTrue(cardFace.abilitySegments.contains(.icon(FishCardFaceIconViewState(assetName: "AllPlayers", fallbackText: "全员", accessibilityText: "所有玩家"))))
    }

    func testClownAnemonefishUsesGameEndYellowAbilityPanel() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(hand: ["base.main.030"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )
        let cardFace = try XCTUnwrap(viewModel.handViewState.cards.first?.cardFace)

        XCTAssertEqual(cardFace.displayName, "Clown Anemonefish")
        XCTAssertEqual(cardFace.abilityTriggerText, AppStrings.GameBoard.abilityTriggerGameEnd)
        XCTAssertEqual(cardFace.abilityPanelStyle, .yellowBrush)
        XCTAssertEqual(cardFace.abilityStripAssetPrefix, "GameEnd")
        XCTAssertTrue(cardFace.abilitySegments.contains(.icon(FishCardFaceIconViewState(assetName: "Wave", fallbackText: "分", accessibilityText: "分数"))))
        XCTAssertEqual(cardFace.abilitySegments.filterYoungFishIconCount, 2)
    }

    func testCardFaceLayoutMetricsUseFinsearchCqwCoordinates() {
        XCTAssertEqual(CardRenderMetrics.cardAspectRatio, 61.0 / 40.0)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.costTop, 3)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.zonesTop, 11.5)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.silhouetteLeft, 22)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.silhouetteTop, 19)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.pointsTop, 37)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.lengthTop, 48)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.abilityWidth, 30)
    }

    func testAbyssalHalosaurHandSlotAndDiscardPileReuseSameCardFace() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(
            hand: ["base.main.002"],
            emptySlots: [Self.slotAddress],
            discardPile: ["base.main.002"]
        )
        setContent(.fishCard("base.main.002"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )

        let handFace = try XCTUnwrap(viewModel.handViewState.cards.first?.cardFace)
        XCTAssertEqual(oceanSlot(in: viewModel, address: Self.slotAddress).cardFace, handFace)
        XCTAssertEqual(viewModel.discardPileViewState.topCards.first, handFace)
    }

    func testMediumLengthBucketMapsToMediumSizeIcon() {
        let card = Card(
            id: "size-class-card",
            name: "Size Class Card",
            allowedZones: [.midnight],
            printedPoints: 1,
            lengthCm: 90
        )
        let service = makeService(hand: ["size-class-card"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { TestCardCatalog(fishCards: [card]) }
        )

        XCTAssertEqual(viewModel.handViewState.cards.first?.cardFace.sizeClassIcon.assetName, "FishLengthMedium")
    }

    func testBaseGameHandCardFaceInfersLocalFishImagePrefix() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(hand: ["base.main.057"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )
        let cardFace = viewModel.handViewState.cards.first?.cardFace

        XCTAssertEqual(cardFace?.displayName, "Great White Shark")
        XCTAssertEqual(cardFace?.scientificName, "Carcharodon carcharias")
        XCTAssertEqual(cardFace?.lengthText, "600 厘米")
        XCTAssertEqual(cardFace?.printedPointsText, "10分")
        XCTAssertEqual(cardFace?.localFishImagePrefix, "57")
    }

    func testGameBoardViewModelHidesCoralReefsWhenNotInitialized() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.oceanColumns.allSatisfy { $0.coralReef == nil })
    }

    func testGameBoardViewModelShowsSharksAndReefsCoralReefs() {
        let service = makeService(
            hand: ["starter-fish-1"],
            enabledExpansions: [.sharksAndReefs],
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let reefs = viewModel.oceanColumns.compactMap(\.coralReef)

        XCTAssertEqual(reefs.count, 3)
        XCTAssertEqual(reefs.map(\.diveSite), [.blue, .purple, .green])
        XCTAssertEqual(reefs.map(\.coralCount), [0, 0, 0])
        XCTAssertEqual(reefs.map(\.maxCoral), [6, 6, 6])
        XCTAssertEqual(reefs.map(\.completionBonus), [6, 8, 5])
        XCTAssertEqual(reefs.map(\.progressText), ["0/6", "0/6", "0/6"])
        XCTAssertEqual(reefs.map(\.completionBonusText), ["+6", "+8", "+5"])
    }

    func testOceanSlotCardFaceShowsFishCardAndUsesSharedAspectRatio() {
        let service = makeService(hand: ["starter-fish-1"])
        setContent(.fishCard("starter-fish-1"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(roomService: service)
        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)

        XCTAssertEqual(slot.cardFace.kind, .fishCard)
        XCTAssertEqual(slot.cardFace.displayName, "Starter Fish 1")
        XCTAssertEqual(slot.cardFace.aspectRatio, CardRenderMetrics.cardAspectRatio)
        XCTAssertEqual(slot.aspectRatio, CardRenderMetrics.cardAspectRatio)
    }

    func testOceanSlotCardFaceShowsEmptyForageAndUnknownPlaceholders() {
        let service = makeService(hand: ["starter-fish-1"])
        setContent(.fishCard("missing-card"), at: Self.resourceSourceAddress, in: service)
        let viewModel = GameBoardViewModel(roomService: service)

        let emptySlot = oceanSlot(in: viewModel, address: Self.slotAddress)
        let forageSlot = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        let unknownSlot = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)

        XCTAssertEqual(emptySlot.cardFace.kind, .empty)
        XCTAssertEqual(forageSlot.cardFace.kind, .forageFish)
        XCTAssertEqual(unknownSlot.cardFace.kind, .placeholder)
        XCTAssertEqual(unknownSlot.cardFace.cardId, "missing-card")
    }

    func testOceanSlotCardFaceDoesNotRemoveResourceTokens() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)
        let slot = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)

        XCTAssertFalse(slot.resourceTokens.isEmpty)
        XCTAssertEqual(slot.cardFace.aspectRatio, CardRenderMetrics.cardAspectRatio)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
    }

    func testDiscardPileViewStateIsEmptyWhenCurrentPlayerHasNoDiscard() {
        let service = makeService(hand: ["starter-fish-1"], discardPile: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.discardPileViewState.isEmpty)
        XCTAssertEqual(viewModel.discardPileViewState.count, 0)
        XCTAssertEqual(viewModel.discardPileViewState.emptyText, AppStrings.GameBoard.discardPileEmpty)
        XCTAssertEqual(viewModel.discardPileViewState.countText, "弃牌 0")
        XCTAssertEqual(viewModel.discardPileViewState.badgeText, "0")
        XCTAssertTrue(viewModel.discardPileViewState.usesCardStackPreview)
        XCTAssertTrue(viewModel.discardPileViewState.usesOverlayBadge)
        XCTAssertTrue(viewModel.discardPileViewState.topCards.isEmpty)
    }

    func testDiscardPileViewStateCountsDiscardCards() {
        let service = makeService(
            hand: ["starter-fish-1"],
            discardPile: ["fish-1", "fish-2", "fish-3"]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.discardPileViewState.isEmpty)
        XCTAssertEqual(viewModel.discardPileViewState.count, 3)
        XCTAssertEqual(viewModel.discardPileViewState.countText, "弃牌 3")
        XCTAssertEqual(viewModel.discardPileViewState.badgeText, "3")
        XCTAssertTrue(viewModel.discardPileViewState.usesOverlayBadge)
    }

    func testDiscardPileTopCardsShowsAtMostThreeMostRecentDiscards() {
        let service = makeService(
            hand: ["starter-fish-1"],
            discardPile: ["fish-1", "fish-2", "fish-3", "fish-4"]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.discardPileViewState.topCards.count, 3)
        XCTAssertEqual(
            viewModel.discardPileViewState.topCards.map(\.cardId),
            ["fish-4", "fish-3", "fish-2"]
        )
    }

    func testShowingDiscardPilePresentsDetailWithAllCardsAndFourColumns() {
        let service = makeService(
            hand: ["starter-fish-1"],
            discardPile: ["fish-1", "fish-2", "fish-3", "fish-4", "fish-5"]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.discardPileViewState.isDetailPresented)
        XCTAssertNil(viewModel.discardPileDetailViewState)

        viewModel.showDiscardPile()

        XCTAssertTrue(viewModel.discardPileViewState.isDetailPresented)
        XCTAssertEqual(viewModel.discardPileDetailViewState?.cards.count, 5)
        XCTAssertEqual(viewModel.discardPileDetailViewState?.cards.map(\.cardId), ["fish-5", "fish-4", "fish-3", "fish-2", "fish-1"])
        XCTAssertEqual(viewModel.discardPileDetailViewState?.maxCardsPerRow, 4)
        XCTAssertEqual(viewModel.discardPileDetailViewState?.countText, "共 5 张")
        XCTAssertEqual(viewModel.discardPileDetailViewState?.presentationStyle, .fullScreenOverlay)
        XCTAssertEqual(viewModel.discardPileDetailViewState?.isReadOnly, true)
    }

    func testHidingDiscardPileDismissesDetail() {
        let service = makeService(hand: ["starter-fish-1"], discardPile: ["fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.showDiscardPile()
        viewModel.hideDiscardPile()

        XCTAssertFalse(viewModel.discardPileViewState.isDetailPresented)
        XCTAssertNil(viewModel.discardPileDetailViewState)
    }

    func testDiscardPileDetailShowsEmptyTextWhenPresentedWithoutCards() {
        let service = makeService(hand: ["starter-fish-1"], discardPile: [])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.showDiscardPile()

        XCTAssertEqual(viewModel.discardPileDetailViewState?.emptyText, AppStrings.GameBoard.discardPileEmpty)
        XCTAssertTrue(viewModel.discardPileDetailViewState?.cards.isEmpty ?? false)
    }

    func testDiscardPileCardFaceResolvesRealBaseGameCard() throws {
        let catalog = try BaseGameCardCatalog()
        let service = makeService(hand: ["starter-fish-1"], discardPile: ["base.main.057"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )

        let cardFace = viewModel.discardPileViewState.topCards.first

        XCTAssertEqual(cardFace?.kind, .fishCard)
        XCTAssertEqual(cardFace?.displayName, "Great White Shark")
        XCTAssertEqual(cardFace?.scientificName, "Carcharodon carcharias")
        XCTAssertEqual(cardFace?.localFishImagePrefix, "57")
    }

    func testDiscardPileCardFaceUsesPlaceholderForMissingCard() {
        let service = makeService(hand: ["starter-fish-1"], discardPile: ["missing-card"])
        let viewModel = GameBoardViewModel(roomService: service)

        let cardFace = viewModel.discardPileViewState.topCards.first

        XCTAssertEqual(cardFace?.kind, .placeholder)
        XCTAssertEqual(cardFace?.cardId, "missing-card")
        XCTAssertEqual(cardFace?.displayName, AppStrings.GameBoard.cardFaceUnknownCard)
    }

    func testHandViewStateShowsRegistryAbilityCopy() {
        let service = makeService(hand: ["fish-30"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(
            viewModel.handViewState.cards.first?.abilitySummaryText,
            "发动时：抽 1 张鱼牌"
        )
    }

    func testHandViewStateShowsUnsupportedAbilityCopyForUnknownAbilityId() {
        let card = Card(
            id: "unknown-ability-fish",
            name: "Unknown Ability Fish",
            abilityIds: ["test.unknown.ability"],
            printedPoints: 1,
            lengthCm: 9
        )
        let service = makeService(hand: [card.id])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: TestCardCatalog(fishCards: [card])
        )

        XCTAssertEqual(
            viewModel.handViewState.cards.first?.abilitySummaryText,
            AppStrings.GameBoard.abilityUnsupported
        )
    }

    func testHandViewStateUsesStackedPresentationByDefault() {
        let service = makeService(hand: ["starter-fish-1", "fish-2", "fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)
        let hand = viewModel.handViewState

        XCTAssertTrue(hand.isStackedPresentation)
        XCTAssertNil(hand.pulledOutCardId)
        XCTAssertEqual(hand.cards.map(\.stackIndex), [0, 1, 2])
        XCTAssertEqual(hand.cards.map(\.stackOffsetX), [0, 74, 148])
        XCTAssertEqual(hand.cards.map(\.stackOffsetY), [46, 46, 46])
        XCTAssertEqual(hand.cards.map(\.stackZIndex), [0, 1, 2])
        XCTAssertTrue(hand.cards.allSatisfy { !$0.isPulledOutFromStack })
        XCTAssertTrue(hand.cards.allSatisfy { $0.visibleHeightRatio == 0.68 })
    }

    func testSelectedHandCardIsPulledOutFromSameStackCard() {
        let service = makeService(hand: ["starter-fish-1", "fish-2", "fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-2")

        let hand = viewModel.handViewState
        let selectedCardsInStack = hand.cards.filter { $0.cardId == "fish-2" }
        XCTAssertEqual(hand.cards.count, 3)
        XCTAssertEqual(selectedCardsInStack.count, 1)
        XCTAssertEqual(hand.selectedCard?.cardId, "fish-2")
        XCTAssertEqual(hand.pulledOutCardId, "fish-2")
        XCTAssertTrue(selectedCardsInStack[0].isPulledOutFromStack)
        XCTAssertEqual(selectedCardsInStack[0].stackOffsetY, -18)
        XCTAssertEqual(selectedCardsInStack[0].stackZIndex, 1_000)
        XCTAssertEqual(selectedCardsInStack[0].visibleHeightRatio, 1)
        XCTAssertTrue(hand.cards.allSatisfy { $0.cardWidth == HandCardViewState.fixedCardWidth })
        XCTAssertTrue(hand.cards.allSatisfy { $0.cardHeight == HandCardViewState.fixedCardHeight })
        XCTAssertTrue(hand.cards.allSatisfy { $0.scale == HandCardViewState.fixedScale })
    }

    func testSwitchingSelectedHandCardReturnsOldCardAndPullsOutNewCard() {
        let service = makeService(hand: ["starter-fish-1", "fish-2", "fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-2")
        viewModel.selectHandCard("fish-3")

        let cards = Dictionary(uniqueKeysWithValues: viewModel.handViewState.cards.map { ($0.cardId, $0) })
        XCTAssertEqual(viewModel.handViewState.pulledOutCardId, "fish-3")
        XCTAssertFalse(cards["fish-2"]?.isPulledOutFromStack ?? true)
        XCTAssertEqual(cards["fish-2"]?.stackOffsetY, 46)
        XCTAssertTrue(cards["fish-3"]?.isPulledOutFromStack ?? false)
        XCTAssertEqual(cards["fish-3"]?.stackOffsetY, -18)
    }

    func testCancelingSelectionReturnsHandToDefaultStack() {
        let service = makeService(hand: ["starter-fish-1", "fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-2")
        viewModel.cancelPlayFishSelection()

        XCTAssertNil(viewModel.handViewState.pulledOutCardId)
        XCTAssertNil(viewModel.handViewState.selectedCard)
        XCTAssertTrue(viewModel.handViewState.cards.allSatisfy { !$0.isPulledOutFromStack })
        XCTAssertEqual(viewModel.handViewState.cards.map(\.stackOffsetY), [46, 46])
    }

    func testBeginDraggingHandCardSelectsCardAndClearsTargetAndPaymentSelection() {
        let service = makeService(hand: ["fish-2", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)

        XCTAssertTrue(viewModel.beginDraggingHandCard("fish-6"))

        XCTAssertEqual(viewModel.selectedCardId, "fish-6")
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertTrue(viewModel.selectedYoungSources.isEmpty)
        XCTAssertEqual(viewModel.draggingHandCardId, "fish-6")
    }

    func testHoveringLegalEmptySlotUpdatesDragHoverSlotAddress() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("fish-1"))
        viewModel.updateDragTarget(Self.slotAddress)

        XCTAssertEqual(viewModel.dragHoverSlotAddress, Self.slotAddress)
        let hoverSlot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertTrue(hoverSlot.isDropTarget)
        XCTAssertTrue(hoverSlot.isValidDropTarget)
        XCTAssertEqual(hoverSlot.dropTargetReasonText, AppStrings.GameBoard.dragToPlayHere)
    }

    func testHoveringLegalShorterForageFishSlotShowsCoverMessage() {
        let service = makeService(hand: ["fish-6"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("fish-6"))
        viewModel.updateDragTarget(Self.forageTargetAddress)

        XCTAssertEqual(viewModel.dragHoverSlotAddress, Self.forageTargetAddress)
        let hoverSlot = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        XCTAssertTrue(hoverSlot.isDropTarget)
        XCTAssertTrue(hoverSlot.isValidDropTarget)
        XCTAssertEqual(hoverSlot.dropTargetReasonText, AppStrings.GameBoard.canCoverShorterFish)
    }

    func testHoveringLegalShorterFishCardSlotShowsCoverMessage() {
        let service = makeService(hand: ["fish-6"], emptySlots: [Self.slotAddress])
        setContent(.fishCard("starter-fish-1"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("fish-6"))
        viewModel.updateDragTarget(Self.slotAddress)

        XCTAssertEqual(viewModel.dragHoverSlotAddress, Self.slotAddress)
        let hoverSlot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertTrue(hoverSlot.isDropTarget)
        XCTAssertTrue(hoverSlot.isValidDropTarget)
        XCTAssertEqual(hoverSlot.dropTargetReasonText, AppStrings.GameBoard.canCoverShorterFish)
    }

    func testHoveringIllegalOccupiedSlotShowsReason() {
        let service = makeService(hand: ["starter-fish-1"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("starter-fish-1"))
        viewModel.updateDragTarget(Self.forageYoungAddress)

        XCTAssertEqual(viewModel.dragHoverSlotAddress, Self.forageYoungAddress)
        let hoverSlot = oceanSlot(in: viewModel, address: Self.forageYoungAddress)
        XCTAssertTrue(hoverSlot.isDropTarget)
        XCTAssertFalse(hoverSlot.isValidDropTarget)
        XCTAssertEqual(
            hoverSlot.dropTargetReasonText,
            "\(AppStrings.GameBoard.slotCannotPlayHere)：\(AppStrings.GameBoard.cannotCoverLongerOrSameFish)"
        )
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.cannotCoverLongerOrSameFish)
    }

    func testDroppingHandCardOnLegalSlotSelectsTargetSlot() {
        let service = makeService(hand: ["fish-6"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("fish-6"))

        let dropTarget = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        XCTAssertTrue(dropTarget.isDropTarget)
        XCTAssertTrue(dropTarget.isValidDropTarget)
        XCTAssertEqual(dropTarget.dropTargetReasonText, AppStrings.GameBoard.canCoverShorterFish)

        XCTAssertTrue(viewModel.dropHandCard(targetAddress: Self.forageTargetAddress))

        XCTAssertEqual(viewModel.selectedCardId, "fish-6")
        XCTAssertEqual(viewModel.selectedTargetSlot, Self.forageTargetAddress)
        XCTAssertNil(viewModel.draggingHandCardId)
    }

    func testDroppingHandCardOnLegalSlotDoesNotSubmitPlayFishCommand() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("starter-fish-1"))
        XCTAssertTrue(viewModel.dropHandCard(targetAddress: Self.slotAddress))

        XCTAssertEqual(viewModel.selectedTargetSlot, Self.slotAddress)
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    func testDroppingHandCardOnIllegalSlotKeepsCardSelectedWithoutTarget() {
        let service = makeService(hand: ["starter-fish-1"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("starter-fish-1"))

        let dropTarget = oceanSlot(in: viewModel, address: Self.forageYoungAddress)
        XCTAssertTrue(dropTarget.isDropTarget)
        XCTAssertFalse(dropTarget.isValidDropTarget)
        XCTAssertEqual(
            dropTarget.dropTargetReasonText,
            "\(AppStrings.GameBoard.slotCannotPlayHere)：\(AppStrings.GameBoard.cannotCoverLongerOrSameFish)"
        )

        XCTAssertFalse(viewModel.dropHandCard(targetAddress: Self.forageYoungAddress))

        XCTAssertEqual(viewModel.selectedCardId, "starter-fish-1")
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertNil(viewModel.draggingHandCardId)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.cannotCoverLongerOrSameFish)
    }

    func testPendingChoicePreventsDragPlayStart() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.beginDraggingHandCard("starter-fish-1"))

        XCTAssertNil(viewModel.selectedCardId)
        XCTAssertNil(viewModel.draggingHandCardId)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.resolveCurrentRewardFirst)
    }

    func testActiveDiveQueuePreventsDragPlayStart() {
        let service = makeService(
            hand: ["starter-fish-1"],
            activeDiveQueue: activeDiveQueue(diveSite: .blue, source: .printedDiveBonus(.sunlit))
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.beginDraggingHandCard("starter-fish-1"))

        XCTAssertNil(viewModel.selectedCardId)
        XCTAssertNil(viewModel.draggingHandCardId)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.resolveCurrentDiveRewardFirst)
    }

    func testHandCardsCanBeSelectedWithoutPendingChoice() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.handViewState.canSelectCards)
        XCTAssertNil(viewModel.handViewState.blockingMessage)
    }

    func testHandCardsCannotBeSelectedWithPendingChoice() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.handViewState.canSelectCards)
        XCTAssertEqual(viewModel.handViewState.blockingMessage, AppStrings.GameBoard.resolveCurrentRewardFirst)

        viewModel.selectCard("starter-fish-1")

        XCTAssertNil(viewModel.selectedCardId)
    }

    func testPendingChoicePreventsDiscardPaymentSelection() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-1", "fish-6"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        viewModel.selectedCardId = "fish-1"

        viewModel.toggleDiscardPaymentCard("fish-6")

        XCTAssertTrue(viewModel.selectedDiscardCardIds.isEmpty)
    }

    func testHandCardsCannotBeSelectedWithActiveDiveQueue() {
        let service = makeService(
            hand: ["starter-fish-1"],
            activeDiveQueue: activeDiveQueue(diveSite: .blue, source: .printedDiveBonus(.sunlit))
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.handViewState.canSelectCards)
        XCTAssertEqual(viewModel.handViewState.blockingMessage, AppStrings.GameBoard.resolveCurrentDiveRewardFirst)

        viewModel.selectCard("starter-fish-1")

        XCTAssertNil(viewModel.selectedCardId)
    }

    func testActiveDiveQueuePreventsDiscardPaymentSelection() {
        let service = makeService(
            hand: ["fish-1", "fish-6"],
            activeDiveQueue: activeDiveQueue(diveSite: .blue, source: .printedDiveBonus(.sunlit))
        )
        let viewModel = GameBoardViewModel(roomService: service)
        viewModel.selectedCardId = "fish-1"

        viewModel.toggleDiscardPaymentCard("fish-6")

        XCTAssertTrue(viewModel.selectedDiscardCardIds.isEmpty)
    }

    func testPlayableHandCardIsMarkedPlayable() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        let card = viewModel.handViewState.cards.first

        XCTAssertEqual(card?.isPlayable, true)
        XCTAssertEqual(card?.highlightStyle, .playable)
        XCTAssertNil(card?.unavailableReasonText)
    }

    func testUnavailableHandCardHasReason() {
        let service = makeService(hand: ["fish-5"])
        let viewModel = GameBoardViewModel(roomService: service)

        let card = viewModel.handViewState.cards.first

        XCTAssertEqual(card?.isPlayable, false)
        XCTAssertEqual(card?.highlightStyle, .unavailable)
        XCTAssertEqual(card?.unavailableReasonText, AppStrings.GameBoard.unsupportedRequirementInUI)
    }

    func testSelectingHandCardUpdatesSelectedCard() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")

        XCTAssertEqual(viewModel.selectedCardId, "starter-fish-1")
        XCTAssertEqual(viewModel.handViewState.selectedCard?.cardId, "starter-fish-1")
        XCTAssertEqual(viewModel.handViewState.cards.first?.highlightStyle, .selected)
    }

    func testSelectingMainCardInitializesTargetAndPaymentSelection() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")

        XCTAssertEqual(viewModel.selectedCardId, "fish-2")
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertTrue(viewModel.selectedDiscardCardIds.isEmpty)
        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertTrue(viewModel.selectedYoungSources.isEmpty)
    }

    func testDiscardCostCardMarksOtherHandCardsAsDiscardPaymentSelectable() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")

        let cards = Dictionary(uniqueKeysWithValues: viewModel.handViewState.cards.map { ($0.cardId, $0) })
        XCTAssertFalse(cards["fish-1"]?.isDiscardPaymentSelectable ?? true)
        XCTAssertTrue(cards["fish-6"]?.isDiscardPaymentSelectable ?? false)
        XCTAssertEqual(cards["fish-6"]?.overlayMarkerText, nil)
    }

    func testClickingOtherHandCardSelectsAndCancelsDiscardPayment() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-1")
        viewModel.selectHandCard("fish-6")

        XCTAssertEqual(viewModel.selectedDiscardCardIds, ["fish-6"])
        XCTAssertTrue(viewModel.handViewState.cards.first { $0.cardId == "fish-6" }?.isSelectedForDiscardPayment ?? false)
        XCTAssertEqual(viewModel.handViewState.cards.first { $0.cardId == "fish-6" }?.overlayMarkerText, AppStrings.GameBoard.paymentSelectionMarker)

        viewModel.selectHandCard("fish-6")

        XCTAssertTrue(viewModel.selectedDiscardCardIds.isEmpty)
    }

    func testDiscardPaymentSelectionCannotExceedCost() {
        let service = makeService(hand: ["fish-1", "fish-6", "starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-1")
        viewModel.selectHandCard("fish-6")
        viewModel.selectHandCard("starter-fish-1")

        XCTAssertEqual(viewModel.selectedDiscardCardIds.count, 1)
    }

    func testDiscardPaymentShortagePreventsPlayableCard() {
        let service = makeService(hand: ["fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        let card = viewModel.handViewState.cards.first

        XCTAssertEqual(card?.isPlayable, false)
        XCTAssertEqual(card?.unavailableReasonText, AppStrings.GameBoard.discardPaymentInsufficient)
    }

    func testDiscardPaymentProgressShowsSelectedCount() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-1")
        viewModel.selectHandCard("fish-6")

        XCTAssertEqual(
            viewModel.paymentProgressViewState?.discardProgress?.progressText,
            AppStrings.GameBoard.discardPaymentProgressText(selectedCount: 1, requiredCount: 1)
        )
        XCTAssertEqual(viewModel.paymentProgressViewState?.discardProgress?.isComplete, true)
    }

    func testUnifiedPaymentPanelShowsResourceProgress() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-2")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)

        XCTAssertEqual(
            viewModel.paymentProgressViewState?.resourceProgress.map(\.progressText),
            [AppStrings.GameBoard.resourcePaymentProgressText(resourceName: "鱼卵", selectedCount: 1, requiredCount: 1)]
        )
    }

    func testUnifiedPaymentPanelTargetProgressUpdatesAfterSlotSelection() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("starter-fish-1")
        XCTAssertEqual(viewModel.paymentProgressViewState?.targetText, AppStrings.GameBoard.noTargetSelected)
        XCTAssertEqual(viewModel.paymentProgressViewState?.isTargetSelected, false)

        viewModel.selectTargetSlot(Self.slotAddress)

        XCTAssertEqual(viewModel.paymentProgressViewState?.targetText, "蓝色潜水点 · 阳光层 1 / 顶行")
        XCTAssertEqual(viewModel.paymentProgressViewState?.isTargetSelected, true)
    }

    func testSelectingDifferentHandCardClearsTargetSlotAndPaymentSelection() {
        let service = makeService(hand: ["fish-2", "fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)

        viewModel.selectCard("fish-3")

        XCTAssertEqual(viewModel.selectedCardId, "fish-3")
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertTrue(viewModel.selectedYoungSources.isEmpty)
    }

    func testSelectingDifferentMainCardClearsDiscardAndResourcePaymentSelection() {
        let service = makeService(hand: ["fish-2", "fish-3", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.selectedDiscardCardIds = ["fish-6"]
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)

        viewModel.selectHandCard("fish-3")

        XCTAssertEqual(viewModel.selectedCardId, "fish-3")
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertTrue(viewModel.selectedDiscardCardIds.isEmpty)
        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertTrue(viewModel.selectedYoungSources.isEmpty)
    }

    func testTargetDiscardAndResourcePaymentsCompleteEnablesPlayFish() {
        let cardCatalog = TestCardCatalog(
            fishCards: [
                Card(
                    id: "fish-mixed-payment",
                    name: "Fish Mixed Payment",
                    costs: [
                        .discardCards(count: 1),
                        .resource(kind: .egg, count: 1),
                        .resource(kind: .young, count: 1)
                    ],
                    allowedZones: [.sunlit]
                )
            ]
        )
        let service = makeService(hand: ["fish-mixed-payment", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: cardCatalog)

        viewModel.selectHandCard("fish-mixed-payment")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.selectHandCard("fish-6")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .young, tokenIndex: 0)

        XCTAssertTrue(viewModel.canSubmitPlayFish)
        XCTAssertEqual(viewModel.paymentProgressViewState?.canConfirm, true)
    }

    func testSubmitPlayFishBuildsDiscardEggAndYoungPaymentFromUnifiedSelection() {
        let cardCatalog = TestCardCatalog(
            fishCards: [
                Card(
                    id: "fish-mixed-payment",
                    name: "Fish Mixed Payment",
                    costs: [
                        .discardCards(count: 1),
                        .resource(kind: .egg, count: 1),
                        .resource(kind: .young, count: 1)
                    ],
                    allowedZones: [.sunlit]
                )
            ]
        )
        let service = makeService(hand: ["fish-mixed-payment", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: cardCatalog)

        viewModel.selectHandCard("fish-mixed-payment")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.selectHandCard("fish-6")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .young, tokenIndex: 0)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }
        XCTAssertEqual(payload.cardId, "fish-mixed-payment")
        XCTAssertEqual(payload.targetSlot, Self.slotAddress)
        XCTAssertEqual(payload.payment.discardedCardIds, ["fish-6"])
        XCTAssertEqual(payload.payment.eggSources, [Self.resourceSourceAddress])
        XCTAssertEqual(payload.payment.youngSources, [Self.resourceSourceAddress])
    }

    func testCancelingHandSelectionClearsCardTargetAndPaymentSelection() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)
        viewModel.cancelPlayFishSelection()

        XCTAssertNil(viewModel.selectedCardId)
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertTrue(viewModel.selectedYoungSources.isEmpty)
        XCTAssertNil(viewModel.handViewState.selectedCard)
    }

    func testSelectedHandCardStillDrivesSlotPreview() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertTrue(slot.playFishPreview.isSelectable)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.slotAvailable)
    }

    func testSubmitPlayFishClearsHandSelection() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.submitPlayFish()

        XCTAssertNil(viewModel.selectedCardId)
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertNil(viewModel.handViewState.selectedCard)
    }

    func testDiscardCostCardKeepsLegalEmptySlotAvailable() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertTrue(slot.playFishPreview.isSelectable)
    }

    func testTogglingDiscardPaymentKeepsLegalEmptySlotAvailable() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.toggleDiscardPaymentCard("fish-6")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertTrue(slot.playFishPreview.isSelectable)
        XCTAssertEqual(viewModel.selectedTargetSlot, Self.slotAddress)
    }

    func testForageFishSlotPreviewIsAvailableWhenSelectedFishIsLonger() {
        let service = makeService(hand: ["fish-6"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-6")

        let slot = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertNil(slot.playFishPreview.unavailableReason)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.canCoverShorterFish)
    }

    func testForageFishSlotPreviewIsUnavailableWhenSelectedFishIsNotLonger() {
        let service = makeService(hand: ["starter-fish-1"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.forageYoungAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .coverLengthTooShort)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.cannotCoverLongerOrSameFish)
    }

    func testFishCardSlotPreviewIsAvailableWhenSelectedFishIsLonger() {
        let service = makeService(hand: ["fish-6"], emptySlots: [Self.slotAddress])
        setContent(.fishCard("starter-fish-1"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-6")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.canCoverShorterFish)
    }

    func testFishCardSlotPreviewIsUnavailableWhenSelectedFishIsNotLonger() {
        let service = makeService(hand: ["starter-fish-1"], emptySlots: [Self.slotAddress])
        setContent(.fishCard("fish-6"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .coverLengthTooShort)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.cannotCoverLongerOrSameFish)
    }

    func testCoverShorterFishCostSlotPreviewRejectsEmptySlot() {
        let service = makeService(hand: ["cover-fish"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: coverShorterFishCatalog()
        )

        viewModel.selectCard("cover-fish")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .mustCoverShorterFish)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.mustCoverShorterFish)

        viewModel.selectTargetSlot(Self.slotAddress)
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.mustCoverShorterFish)
    }

    func testCoverShorterFishCostSlotPreviewAllowsShorterForageFish() {
        let service = makeService(hand: ["cover-fish"], emptySlots: [])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: coverShorterFishCatalog()
        )

        viewModel.selectCard("cover-fish")

        let slot = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.canCoverShorterFish)
    }

    func testCoverShorterFishCostSlotPreviewAllowsShorterFishCard() {
        let service = makeService(hand: ["cover-fish"], emptySlots: [Self.slotAddress])
        setContent(.fishCard("starter-fish-1"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: coverShorterFishCatalog()
        )

        viewModel.selectCard("cover-fish")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.canCoverShorterFish)
    }

    func testCoverShorterFishCostSlotPreviewRejectsSameLengthFishCard() {
        let service = makeService(hand: ["cover-fish"], emptySlots: [Self.slotAddress])
        setContent(.fishCard("same-length-fish"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: coverShorterFishCatalog()
        )

        viewModel.selectCard("cover-fish")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .coverLengthTooShort)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.cannotCoverLongerOrSameFish)
    }

    func testCoverShorterFishCostDragPreviewUsesSameEmptySlotReason() {
        let service = makeService(hand: ["cover-fish"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: coverShorterFishCatalog()
        )

        XCTAssertTrue(viewModel.beginDraggingHandCard("cover-fish"))
        viewModel.updateDragTarget(Self.slotAddress)

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertTrue(slot.isDropTarget)
        XCTAssertFalse(slot.isValidDropTarget)
        XCTAssertEqual(
            slot.dropTargetReasonText,
            "\(AppStrings.GameBoard.slotCannotPlayHere)：\(AppStrings.GameBoard.mustCoverShorterFish)"
        )
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.mustCoverShorterFish)
        XCTAssertFalse(viewModel.dropHandCard(targetAddress: Self.slotAddress))
        XCTAssertNil(viewModel.selectedTargetSlot)
    }

    func testZoneMismatchPreviewIsUnavailable() {
        let service = makeService(hand: ["fish-1"], emptySlots: [Self.slotAddress, Self.resourceSourceAddress])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .zoneMismatch)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.slotZoneMismatch)
    }

    func testRequiredDiveSiteColorMismatchPreviewIsUnavailable() {
        let service = makeService(hand: ["fish-4"], emptySlots: [Self.slotAddress])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-4")

        let slot = oceanSlot(in: viewModel, address: Self.blueTwilightSlotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .diveSiteMismatch)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.slotDiveSiteMismatch)
    }

    func testReefFishCoralRequirementPreviewRejectsNonSunlightSlot() {
        let service = makeService(
            hand: ["reef-fish"],
            coralReefs: [CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6)]
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: reefFishCatalog())

        viewModel.selectCard("reef-fish")

        let slot = oceanSlot(in: viewModel, address: Self.blueTwilightSlotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .reefFishMustBeSunlit)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.reefFishMustBeSunlit)
    }

    func testReefFishCoralRequirementPreviewRejectsInsufficientCoral() {
        let service = makeService(
            hand: ["reef-fish"],
            coralReefs: [CoralReefState(diveSite: .blue, coralCount: 1, maxCoral: 6, completionBonus: 6)]
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: reefFishCatalog())

        viewModel.selectCard("reef-fish")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .coralInsufficient)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.coralInsufficient)
    }

    func testReefFishCoralRequirementPreviewAllowsSunlightWithEnoughCoral() {
        let service = makeService(
            hand: ["reef-fish"],
            coralReefs: [CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6)]
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: reefFishCatalog())

        viewModel.selectCard("reef-fish")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.slotAvailable)
    }

    func testReefFishDragPreviewUsesCoralRequirementReason() {
        let service = makeService(
            hand: ["reef-fish"],
            coralReefs: [CoralReefState(diveSite: .blue, coralCount: 1, maxCoral: 6, completionBonus: 6)]
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: reefFishCatalog())

        XCTAssertTrue(viewModel.beginDraggingHandCard("reef-fish"))
        viewModel.updateDragTarget(Self.slotAddress)

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertTrue(slot.isDropTarget)
        XCTAssertFalse(slot.isValidDropTarget)
        XCTAssertEqual(
            slot.dropTargetReasonText,
            "\(AppStrings.GameBoard.slotCannotPlayHere)：\(AppStrings.GameBoard.coralInsufficient)"
        )
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.coralInsufficient)
        XCTAssertFalse(viewModel.dropHandCard(targetAddress: Self.slotAddress))
        XCTAssertNil(viewModel.selectedTargetSlot)
    }

    func testSelectingFishMarksDiveUnavailableDuringPlayFishSelection() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.canDive)

        viewModel.selectCard("fish-1")

        XCTAssertTrue(viewModel.isSelectingPlayFish)
        XCTAssertFalse(viewModel.canDive)
    }

    func testOceanSlotPreviewsUseBaseGameEighteenSlotLayout() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.oceanSlots.count, 18)
        XCTAssertTrue(viewModel.oceanSlots.allSatisfy { $0.aspectRatio == CardRenderMetrics.cardAspectRatio })
        XCTAssertEqual(viewModel.oceanColumns.count, 3)
        XCTAssertEqual(viewModel.oceanColumns.map(\.slots.count), [6, 6, 6])
        XCTAssertEqual(viewModel.oceanColumns[0].diveSite, .blue)
        XCTAssertEqual(viewModel.oceanColumns[1].diveSite, .purple)
        XCTAssertEqual(viewModel.oceanColumns[2].diveSite, .green)
        XCTAssertEqual(
            Set(viewModel.oceanSlots.filter { $0.address.rowTrait == .topRow }.map(\.address.rowIndex)),
            [0]
        )
        XCTAssertEqual(
            Set(viewModel.oceanSlots.filter { $0.address.rowTrait == .bottomRow }.map(\.address.rowIndex)),
            [5]
        )

        let blueBottomRowAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 5)
        XCTAssertEqual(
            oceanSlot(in: viewModel, address: blueBottomRowAddress).title,
            "深海层 2 / 底行"
        )
        XCTAssertEqual(viewModel.bottomAreas.count, 3)
    }

    func testBottomAreaViewStatesUseBaseGameBottomBonusLayout() {
        let service = makeService(
            hand: ["fish-1", "fish-6"],
            diveSitesReachedBottomThisWeek: [.green]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let bottomAreas = Dictionary(uniqueKeysWithValues: viewModel.bottomAreas.map { ($0.diveSite, $0) })

        XCTAssertEqual(viewModel.bottomAreas.map(\.diveSite), [.blue, .purple, .green])
        XCTAssertEqual(bottomAreas[.blue]?.bonusKind, .recoverFromDiscardOrDraw)
        XCTAssertEqual(bottomAreas[.blue]?.bonusTitle, AppStrings.GameBoard.recoverFromDiscardOrDraw)
        XCTAssertEqual(bottomAreas[.blue]?.bonusDetailText, AppStrings.GameBoard.discardPileEmptyDrawAlternative)
        XCTAssertEqual(bottomAreas[.purple]?.bonusKind, .placeEgg)
        XCTAssertEqual(bottomAreas[.purple]?.bonusTitle, AppStrings.GameBoard.gainOneEgg)
        XCTAssertEqual(bottomAreas[.green]?.bonusKind, .moveYoungOrSchool)
        XCTAssertEqual(bottomAreas[.green]?.bonusTitle, AppStrings.GameBoard.moveYoungOrSchool)
        XCTAssertEqual(bottomAreas[.green]?.statusText, AppStrings.GameBoard.bottomBonusClaimedThisWeek)
        XCTAssertEqual(bottomAreas[.green]?.isAlreadyReachedThisWeek, true)
        XCTAssertEqual(bottomAreas[.green]?.isFirstBottomThisWeekAvailable, false)
        XCTAssertEqual(bottomAreas[.blue]?.statusText, AppStrings.GameBoard.bottomBonusAvailableThisWeek)
    }

    func testBottomBonusQueueStepHighlightsOnlyMatchingBottomArea() {
        let service = makeService(
            hand: ["fish-1", "fish-6"],
            activeDiveQueue: activeDiveQueue(diveSite: .purple, source: .bottomBonus)
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.highlightedBottomBonusDiveSite, .purple)
        XCTAssertEqual(
            viewModel.bottomAreas.first { $0.diveSite == .purple }?.isHighlightedByDiveQueue,
            true
        )
        XCTAssertEqual(
            viewModel.bottomAreas.first { $0.diveSite == .purple }?.highlightReasonText,
            AppStrings.GameBoard.triggeringFirstBottomBonus
        )
        XCTAssertFalse(
            viewModel.bottomAreas
                .filter { $0.diveSite != .purple }
                .contains { $0.isHighlightedByDiveQueue }
        )
        XCTAssertFalse(
            viewModel.oceanSlots
                .filter { $0.address.rowIndex == 5 }
                .contains { $0.isHighlightedByDiveQueue }
        )
    }

    func testMidnightPrintedDiveBonusHighlightsRowsFourAndFiveWithoutBottomArea() {
        let service = makeService(
            hand: ["fish-1", "fish-6"],
            activeDiveQueue: activeDiveQueue(diveSite: .blue, source: .printedDiveBonus(.midnight))
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let highlightedRows = viewModel.oceanSlots
            .filter { $0.address.diveSite == .blue && $0.isHighlightedByDiveQueue }
            .map(\.address.rowIndex)

        XCTAssertEqual(Set(highlightedRows), [4, 5])
        XCTAssertNil(viewModel.highlightedBottomBonusDiveSite)
        XCTAssertFalse(viewModel.bottomAreas.contains { $0.isHighlightedByDiveQueue })
    }

    func testPendingChoiceSlotTargetsNeverIncludeBottomArea() {
        let choices = [
            pendingChoice(kind: .placeEgg),
            pendingChoice(kind: .hatchEgg),
            pendingChoice(kind: .moveYoungOrSchool)
        ]
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: Dictionary(uniqueKeysWithValues: choices.map { ($0.choiceId, $0) })
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let oceanSlotAddresses = Set(viewModel.oceanSlots.map(\.address))

        XCTAssertTrue(
            viewModel.pendingChoiceTargets(for: choices[0])
                .map(\.address)
                .allSatisfy { oceanSlotAddresses.contains($0) }
        )
        XCTAssertTrue(
            viewModel.pendingChoiceTargets(for: choices[1])
                .map(\.address)
                .allSatisfy { oceanSlotAddresses.contains($0) }
        )
        XCTAssertTrue(
            viewModel.pendingChoiceMoveTargets(for: choices[2])
                .allSatisfy {
                    oceanSlotAddresses.contains($0.source)
                        && oceanSlotAddresses.contains($0.target)
                }
        )
    }

    func testOceanSlotResourceTokensShowEggYoungAndSchool() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)
        let slot = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)

        XCTAssertEqual(slot.resourceTokens.map(\.kind), [.egg, .young, .school])
        XCTAssertEqual(slot.resourceTokens.map(\.title), ["鱼卵", "幼鱼", "鱼群"])
        XCTAssertEqual(slot.resourceTokens.map(\.tokenIndex), [0, 0, 0])
    }

    func testMultipleEggsProduceSingleTokenWithWarning() {
        let service = makeService(
            hand: ["fish-2"],
            resourceSourceResources: [ResourceQuantity(kind: .egg, amount: 2)]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let eggTokens = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)
            .resourceTokens
            .filter { $0.kind == .egg }

        XCTAssertEqual(eggTokens.count, 1)
        XCTAssertEqual(eggTokens.first?.warningText, AppStrings.GameBoard.resourceTokenIllegalMultipleEggs)
    }

    func testTwoYoungWithoutSchoolProduceTwoIndependentYoungTokens() {
        let service = makeService(
            hand: ["fish-3"],
            resourceSourceResources: [ResourceQuantity(kind: .young, amount: 2)]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let youngTokens = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)
            .resourceTokens
            .filter { $0.kind == .young }

        XCTAssertEqual(youngTokens.map(\.tokenIndex), [0, 1])
        XCTAssertEqual(youngTokens.map(\.id), ["young-0", "young-1"])
    }

    func testFormedSchoolStateDoesNotDisplayThreeYoungTokens() {
        let service = makeService(
            hand: ["fish-3"],
            resourceSourceResources: [ResourceQuantity(kind: .school, amount: 1)]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let tokens = oceanSlot(in: viewModel, address: Self.resourceSourceAddress).resourceTokens

        XCTAssertEqual(tokens.filter { $0.kind == .young }.count, 0)
        XCTAssertEqual(tokens.filter { $0.kind == .school }.count, 1)
    }

    func testExistingSchoolCanDisplayOneSchoolAndExtraYoungTokens() {
        let service = makeService(
            hand: ["fish-3"],
            resourceSourceResources: [
                ResourceQuantity(kind: .young, amount: 3),
                ResourceQuantity(kind: .school, amount: 1)
            ]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let tokens = oceanSlot(in: viewModel, address: Self.resourceSourceAddress).resourceTokens

        XCTAssertEqual(tokens.filter { $0.kind == .school }.count, 1)
        XCTAssertEqual(tokens.filter { $0.kind == .young }.map(\.tokenIndex), [0, 1, 2])
    }

    func testMultipleSchoolsProduceSingleTokenWithWarning() {
        let service = makeService(
            hand: ["fish-3"],
            resourceSourceResources: [ResourceQuantity(kind: .school, amount: 2)]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let schoolTokens = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)
            .resourceTokens
            .filter { $0.kind == .school }

        XCTAssertEqual(schoolTokens.count, 1)
        XCTAssertEqual(schoolTokens.first?.warningText, AppStrings.GameBoard.resourceTokenIllegalMultipleSchools)
    }

    func testEggResourceTokenIsSelectableWhenSelectedFishRequiresEggPayment() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")

        let token = resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .egg)
        XCTAssertTrue(token.isSelectable)
        XCTAssertFalse(token.isSelectedForPayment)
    }

    func testClickingEggResourceTokenSelectsAndThenClearsSelection() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)

        XCTAssertEqual(viewModel.selectedEggSources, [Self.resourceSourceAddress])
        XCTAssertTrue(resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .egg).isSelectedForPayment)

        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)

        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertFalse(resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .egg).isSelectedForPayment)
    }

    func testResourceTokenSelectionDoesNotExceedAvailableCountForSlot() {
        let cardCatalog = TestCardCatalog(
            fishCards: [
                Card(
                    id: "fish-egg-2",
                    name: "Fish Egg 2",
                    costs: [.resource(kind: .egg, count: 2)],
                    allowedZones: [.sunlit]
                )
            ]
        )
        let service = makeService(
            hand: ["fish-egg-2"],
            resourceSourceResources: [ResourceQuantity(kind: .egg, amount: 1)]
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: cardCatalog)

        viewModel.selectCard("fish-egg-2")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 1)

        XCTAssertLessThanOrEqual(viewModel.selectedEggSources.count, 1)
    }

    func testEnoughEggPaymentAllowsPlayFishSubmission() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)
        XCTAssertFalse(viewModel.canSubmitPlayFish)

        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)

        XCTAssertTrue(viewModel.canSubmitPlayFish)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }
        XCTAssertEqual(payload.payment.eggSources, [Self.resourceSourceAddress])
    }

    func testYoungResourcePaymentUsesIndependentTokenSelection() {
        let service = makeService(hand: ["fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-3")
        viewModel.selectTargetSlot(Self.slotAddress)
        XCTAssertFalse(viewModel.canSubmitPlayFish)

        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .young, tokenIndex: 0)

        XCTAssertEqual(viewModel.selectedYoungSources, [Self.resourceSourceAddress])
        XCTAssertTrue(viewModel.canSubmitPlayFish)
        XCTAssertEqual(
            viewModel.resourcePaymentProgress.map(\.progressText),
            ["幼鱼：已选择 1 / 1"]
        )
    }

    func testTwoYoungTokensCanBeSelectedIndependentlyFromSameSlot() {
        let cardCatalog = TestCardCatalog(
            fishCards: [
                Card(
                    id: "fish-young-2",
                    name: "Fish Young 2",
                    costs: [.resource(kind: .young, count: 2)],
                    allowedZones: [.sunlit]
                )
            ]
        )
        let service = makeService(
            hand: ["fish-young-2"],
            resourceSourceResources: [ResourceQuantity(kind: .young, amount: 2)]
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: cardCatalog)

        viewModel.selectCard("fish-young-2")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .young, tokenIndex: 0)

        XCTAssertTrue(resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .young, tokenIndex: 0).isSelectedForPayment)
        XCTAssertFalse(resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .young, tokenIndex: 1).isSelectedForPayment)
        XCTAssertFalse(viewModel.canSubmitPlayFish)

        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .young, tokenIndex: 1)

        XCTAssertEqual(viewModel.selectedYoungSources, [Self.resourceSourceAddress, Self.resourceSourceAddress])
        XCTAssertTrue(resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .young, tokenIndex: 1).isSelectedForPayment)
    }

    func testSelectingAnotherFishClearsResourcePaymentSelection() {
        let service = makeService(hand: ["fish-2", "fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)
        viewModel.selectCard("fish-3")

        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertTrue(viewModel.selectedYoungSources.isEmpty)
        XCTAssertEqual(
            resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .egg).isSelectedForPayment,
            false
        )
    }

    func testCancelPlayFishSelectionClearsResourcePaymentSelection() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg, tokenIndex: 0)
        viewModel.cancelPlayFishSelection()

        XCTAssertNil(viewModel.selectedCardId)
        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertEqual(
            resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .egg).isSelectedForPayment,
            false
        )
    }

    func testPendingChoicePreventsResourcePaymentTokenSelection() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        viewModel.selectedCardId = "fish-2"

        viewModel.toggleResourcePayment(address: Self.resourceSourceAddress, kind: .egg)

        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertFalse(
            resourceToken(in: viewModel, address: Self.resourceSourceAddress, kind: .egg).isSelectable
        )
    }

    func testNormalAbilityPendingChoiceShowsFishAbilityCopy() {
        let choice = abilityPendingChoice(cardId: "fish-30", kind: .drawFish)
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let pendingChoice = viewModel.pendingChoices.first

        XCTAssertEqual(pendingChoice?.title, AppStrings.GameBoard.triggeringFishAbility(cardName: "Fish A"))
        XCTAssertEqual(
            pendingChoice?.actions.map(\.title),
            [AppStrings.GameBoard.drawOneFishCard, AppStrings.GameBoard.skipChoice]
        )
    }

    func testCompoundAbilityPendingChoiceShowsProgressAndActions() {
        let choice = compoundAbilityPendingChoice()
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let pendingChoice = viewModel.pendingChoices.first

        XCTAssertEqual(pendingChoice?.title, AppStrings.GameBoard.triggeringFishAbility(cardName: "Fish B"))
        XCTAssertEqual(
            pendingChoice?.progressLines,
            [
                AppStrings.GameBoard.compoundAbilityProgressText(
                    title: AppStrings.GameBoard.placeEggAbilityAction,
                    completedCount: 0,
                    totalCount: 2
                ),
                AppStrings.GameBoard.compoundAbilityProgressText(
                    title: AppStrings.GameBoard.hatchEggAbilityAction,
                    completedCount: 0,
                    totalCount: 1
                )
            ]
        )
        XCTAssertEqual(
            pendingChoice?.actions.map(\.title),
            [
                AppStrings.GameBoard.placeEggAbilityAction,
                AppStrings.GameBoard.hatchEggAbilityAction,
                AppStrings.GameBoard.finishAbility,
                AppStrings.GameBoard.skipChoice
            ]
        )
    }

    func testChoosingCompoundPlaceEggAndHatchEggSubeffectsBuildsResolveCommands() {
        let choice = compoundAbilityPendingChoice()
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.performPendingChoiceAction(.choosePlaceEggAbilityEffect, for: choice.choiceId)
        viewModel.performPendingChoiceAction(.chooseHatchEggAbilityEffect, for: choice.choiceId)

        guard service.submittedCommands.count == 2,
              case let .resolvePendingChoice(placePayload) = service.submittedCommands[0].payload,
              case let .resolvePendingChoice(hatchPayload) = service.submittedCommands[1].payload
        else {
            return XCTFail("Expected resolvePendingChoice commands.")
        }
        XCTAssertEqual(placePayload.resolution, .chooseAbilityEffect(.placeEgg(count: 1)))
        XCTAssertEqual(hatchPayload.resolution, .chooseAbilityEffect(.hatchEgg(count: 1)))
    }

    func testFinishingCompoundAbilityBuildsFinishAbilityCommand() {
        let choice = compoundAbilityPendingChoice()
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.performPendingChoiceAction(.finishAbility, for: choice.choiceId)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.resolution, .finishAbility)
    }

    func testAbilityPendingChoiceBlocksSelectingNewHandCard() {
        let choice = abilityPendingChoice(cardId: "fish-30", kind: .drawFish)
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("starter-fish-1")

        XCTAssertNil(viewModel.selectedCardId)
        XCTAssertEqual(viewModel.handViewState.canSelectCards, false)
        XCTAssertEqual(viewModel.handViewState.blockingMessage, AppStrings.GameBoard.resolveCurrentRewardFirst)
    }

    func testSubmitDiveBuildsPlayerCommand() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.submitDive(to: .purple)

        guard case let .dive(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected dive command.")
        }

        XCTAssertEqual(service.submittedCommands.last?.playerId, "player-1")
        XCTAssertEqual(service.submittedCommands.last?.roomId, "room-1")
        XCTAssertEqual(payload.diveSite, .purple)
    }

    func testSubmitPlayFishDoesNotSubmitWhenResourceSourcesAreIncomplete() {
        let slotAddress = Self.slotAddress
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.submitPlayFish()

        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.eggPaymentIncomplete)
    }

    func testSkipPendingChoiceBuildsResolvePendingChoiceCommand() {
        let choice = PendingChoice(
            choiceId: "choice-1",
            playerId: "player-1",
            source: .diveBonus(.blue),
            kind: .bottomBonus,
            options: [],
            expectedInput: .none,
            isOptional: true,
            createdAtSequence: 2
        )
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.skipPendingChoice(choice.choiceId)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }

        XCTAssertEqual(service.submittedCommands.last?.playerId, "player-1")
        XCTAssertEqual(service.submittedCommands.last?.roomId, "room-1")
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .skip)
    }

    func testBlockingPendingChoicePreventsPlayFishAndDiveSubmission() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.submitPlayFish()
        viewModel.cancelPlayFishSelection()
        viewModel.submitDive(to: .blue)

        XCTAssertTrue(viewModel.hasBlockingPendingChoices)
        XCTAssertFalse(viewModel.canSubmitPlayFish)
        XCTAssertFalse(viewModel.canDive)
        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.resolveCurrentRewardFirst)
    }

    func testNoAvailableDiversPreventsPlayFishAndDiveSubmission() {
        let playFishService = makeService(hand: ["starter-fish-1"], availableDivers: 0)
        let playFishViewModel = GameBoardViewModel(roomService: playFishService)

        playFishViewModel.selectCard("starter-fish-1")
        playFishViewModel.selectTargetSlot(Self.slotAddress)
        playFishViewModel.submitPlayFish()

        XCTAssertFalse(playFishViewModel.canSubmitPlayFish)
        XCTAssertEqual(playFishViewModel.diverAvailabilityWarning, AppStrings.GameBoard.diversUsedThisWeek)
        XCTAssertTrue(playFishService.submittedCommands.isEmpty)
        XCTAssertEqual(playFishViewModel.errorMessage, AppStrings.GameBoard.diversUsedThisWeek)

        let diveService = makeService(hand: ["starter-fish-1"], availableDivers: 0)
        let diveViewModel = GameBoardViewModel(roomService: diveService)

        diveViewModel.submitDive(to: .blue)

        XCTAssertFalse(diveViewModel.canDive)
        XCTAssertEqual(diveViewModel.diverAvailabilityWarning, AppStrings.GameBoard.diversUsedThisWeek)
        XCTAssertTrue(diveService.submittedCommands.isEmpty)
        XCTAssertEqual(diveViewModel.errorMessage, AppStrings.GameBoard.diversUsedThisWeek)
    }

    func testPendingChoicesTakePriorityOverNoAvailableDiversWarning() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(
            hand: ["starter-fish-1"],
            pendingChoices: [choice.choiceId: choice],
            availableDivers: 0
        )
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")
        viewModel.submitDive(to: .blue)

        XCTAssertTrue(viewModel.hasBlockingPendingChoices)
        XCTAssertNil(viewModel.diverAvailabilityWarning)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.resolveCurrentRewardFirst)
    }

    func testMainActionPromptAsksForPlayFishOrDive() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.mainActionPrompt, AppStrings.GameBoard.chooseMainAction)
    }

    func testMainActionPromptPrioritizesPendingChoice() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(
            hand: ["starter-fish-1"],
            pendingChoices: [choice.choiceId: choice]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.mainActionPrompt, AppStrings.GameBoard.resolveCurrentRewardFirst)
    }

    func testDisplaysCurrentWeekAndEndGamePendingPhase() {
        let service = makeService(
            hand: ["starter-fish-1"],
            phase: .endGamePending,
            currentWeek: 4,
            activePlayerId: nil
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.currentWeekText, "4")
        XCTAssertEqual(AppStrings.phaseName(viewModel.state.phase), "游戏结束能力")
    }

    func testGameEndAbilityPhaseViewStateShowsAbilityRowsAndStatuses() throws {
        let catalog = gameEndAbilityCatalog()
        let service = makeService(
            hand: [],
            phase: .endGamePending,
            currentWeek: 4,
            activePlayerId: nil
        )
        setContent(.fishCard("sr.gameEnd.anyCoral"), at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0), in: service)
        setContent(.fishCard("sr.gameEnd.greenCoral"), at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1), in: service)
        setContent(.fishCard("gameEnd.unsupported"), at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 2), in: service)
        setContent(
            .forageFish(
                ForageFish(
                    forageFishId: "forage-game-end",
                    name: "测试饵鱼",
                    lengthCm: 5,
                    diveSite: .blue,
                    rowIndex: 3
                )
            ),
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 3),
            in: service
        )
        setConsumedFish(
            [ConsumedFish(cardId: "sr.gameEnd.anyCoral")],
            at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 4),
            in: service
        )
        let activatedSource = GameEndAbilitySource(
            playerId: "player-1",
            slotAddress: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            cardId: "sr.gameEnd.anyCoral",
            abilityId: SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd
        )
        setActivatedGameEndAbilitySources([activatedSource.id], in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )

        let phase = try XCTUnwrap(viewModel.gameEndAbilityPhaseViewState)
        XCTAssertEqual(phase.title, AppStrings.GameBoard.gameEndAbilityPhaseTitle)
        XCTAssertEqual(phase.finishButtonTitle, AppStrings.GameBoard.finishGameEndAbilities)
        XCTAssertTrue(phase.canFinish)
        XCTAssertEqual(phase.abilityRows.map(\.fishName), [
            "Any Coral Game End Fish",
            "Green Coral Game End Fish",
            "Unsupported Game End Fish"
        ])

        let activatedRow = try XCTUnwrap(phase.abilityRows.first { $0.fishName == "Any Coral Game End Fish" })
        XCTAssertEqual(activatedRow.statusText, AppStrings.GameBoard.gameEndAbilityActivated)
        XCTAssertFalse(activatedRow.canActivate)

        let availableRow = try XCTUnwrap(phase.abilityRows.first { $0.fishName == "Green Coral Game End Fish" })
        XCTAssertEqual(availableRow.statusText, AppStrings.GameBoard.gameEndAbilityAvailable)
        XCTAssertTrue(availableRow.canActivate)

        let unsupportedRow = try XCTUnwrap(phase.abilityRows.first { $0.fishName == "Unsupported Game End Fish" })
        XCTAssertEqual(unsupportedRow.statusText, AppStrings.GameBoard.gameEndAbilityUnsupported)
        XCTAssertFalse(unsupportedRow.isSupported)
        XCTAssertFalse(unsupportedRow.canActivate)
    }

    func testGameEndAbilityPhaseShowsAutomaticScoringRows() throws {
        let catalog = gameEndAbilityCatalog()
        let service = makeService(
            hand: [],
            phase: .endGamePending,
            currentWeek: 4,
            activePlayerId: nil
        )
        setContent(.fishCard("gameEnd.scoring"), at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0), in: service)
        setContent(.fishCard("sr.gameEnd.greenCoral"), at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1), in: service)
        setContent(.fishCard("gameEnd.unsupported"), at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 2), in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )

        let phase = try XCTUnwrap(viewModel.gameEndAbilityPhaseViewState)
        let scoringRow = try XCTUnwrap(phase.abilityRows.first { $0.fishName == "Scoring Game End Fish" })
        let executableRow = try XCTUnwrap(phase.abilityRows.first { $0.fishName == "Green Coral Game End Fish" })
        let unsupportedRow = try XCTUnwrap(phase.abilityRows.first { $0.fishName == "Unsupported Game End Fish" })

        XCTAssertEqual(scoringRow.statusText, AppStrings.GameBoard.gameEndAbilityAutomaticScoring)
        XCTAssertFalse(scoringRow.isSupported)
        XCTAssertFalse(scoringRow.canActivate)
        XCTAssertEqual(executableRow.statusText, AppStrings.GameBoard.gameEndAbilityAvailable)
        XCTAssertTrue(executableRow.canActivate)
        XCTAssertEqual(unsupportedRow.statusText, AppStrings.GameBoard.gameEndAbilityUnsupported)
        XCTAssertFalse(unsupportedRow.canActivate)
        XCTAssertTrue(phase.canFinish)
    }

    func testGameEndAbilityPhaseActionsSubmitCommands() throws {
        let catalog = gameEndAbilityCatalog()
        let service = makeService(
            hand: [],
            phase: .endGamePending,
            currentWeek: 4,
            activePlayerId: nil
        )
        setContent(.fishCard("sr.gameEnd.greenCoral"), at: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0), in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { catalog }
        )
        let row = try XCTUnwrap(viewModel.gameEndAbilityPhaseViewState?.abilityRows.first)

        viewModel.activateGameEndAbility(row.source)

        guard case let .activateGameEndAbility(activation) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected activateGameEndAbility command.")
        }
        XCTAssertEqual(activation.source, row.source)

        viewModel.finishGameEndAbilities()

        guard case .finishGameEndAbilities = service.submittedCommands.last?.payload else {
            return XCTFail("Expected finishGameEndAbilities command.")
        }
    }

    func testWeekEndedEventSummaryShowsNextWeek() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)
        let event = GameEvent(
            sequenceNumber: 3,
            roomId: "room-1",
            timestamp: Date(timeIntervalSince1970: 1_000),
            payload: .weekEnded(
                WeekEndedEvent(
                    endedWeek: 1,
                    nextWeek: 2,
                    previousFirstPlayerId: "player-1",
                    nextFirstPlayerId: "player-1",
                    nextActivePlayerId: "player-1",
                    isGameEndTriggered: false
                )
            )
        )

        XCTAssertEqual(viewModel.eventSummary(event), "#3 第 1 周结束，进入第 2 周")
    }

    func testWeeklyAchievementResultsGenerateChineseViewData() {
        let result = WeeklyAchievementResult(
            week: 2,
            kind: .rowsOfFish,
            playerId: "player-1",
            quantity: 3,
            points: 6
        )
        let service = makeService(
            hand: ["starter-fish-1"],
            weeklyAchievementResults: [result]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(
            viewModel.weeklyAchievementResults,
            [
                WeeklyAchievementResultViewData(
                    week: 2,
                    playerId: "player-1",
                    kind: .rowsOfFish,
                    title: "第 2 周 · 玩家 1",
                    subtitle: "鱼的行 3 行，得 6 分"
                )
            ]
        )
    }

    func testWeekEndedEventSummaryIncludesAchievementPoints() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)
        let event = GameEvent(
            sequenceNumber: 3,
            roomId: "room-1",
            timestamp: Date(timeIntervalSince1970: 1_000),
            payload: .weekEnded(
                WeekEndedEvent(
                    endedWeek: 1,
                    nextWeek: 2,
                    previousFirstPlayerId: "player-1",
                    nextFirstPlayerId: "player-1",
                    nextActivePlayerId: "player-1",
                    isGameEndTriggered: false,
                    achievementResults: [
                        WeeklyAchievementResult(
                            week: 1,
                            kind: .eggsAndYoung,
                            playerId: "player-1",
                            quantity: 7,
                            points: 7
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(
            viewModel.eventSummary(event),
            "#3 第 1 周结束：玩家 1 成就得 7 分，进入第 2 周"
        )
    }

    func testNoWeeklyAchievementResultsReturnsEmptyViewData() {
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.weeklyAchievementResults.isEmpty)
    }

    func testFinalScoreResultGeneratesChineseViewStateWithWinnerRowsSegmentsAndLegend() {
        let playerOneScore = FinalScoreBreakdown(
            playerId: "player-1",
            weeklyAchievementPoints: 3,
            fishPrintedPoints: 4,
            gameEndAbilityPoints: 0,
            eggPoints: 1,
            youngPoints: 1,
            schoolPoints: 0,
            consumedFishPoints: 1,
            totalPoints: 10
        )
        let playerTwoScore = FinalScoreBreakdown(
            playerId: "player-2",
            weeklyAchievementPoints: 6,
            fishPrintedPoints: 5,
            gameEndAbilityPoints: 0,
            eggPoints: 2,
            youngPoints: 1,
            schoolPoints: 6,
            consumedFishPoints: 0,
            totalPoints: 20
        )
        let service = makeService(
            hand: [],
            phase: .gameEnded,
            activePlayerId: nil,
            finalScoreResult: FinalScoreResult(
                results: [playerOneScore, playerTwoScore],
                winnerPlayerIds: ["player-2"],
                isTie: false
            )
        )
        service.gameRoom?.players.append(
            RoomPlayer(playerId: "player-2", displayName: "玩家 2", color: .green)
        )
        service.gameState.players.append(Player(id: "player-2", name: "玩家 2"))
        let viewModel = GameBoardViewModel(roomService: service)

        guard let finalScoreViewState = viewModel.finalScoreViewState else {
            return XCTFail("Expected final score view state.")
        }

        XCTAssertEqual(finalScoreViewState.title, AppStrings.GameBoard.finalScoreTitle)
        XCTAssertEqual(finalScoreViewState.winnerText, "获胜玩家：玩家 2")
        XCTAssertEqual(finalScoreViewState.maxTotalPoints, 20)
        XCTAssertEqual(finalScoreViewState.playerRows.count, 2)
        XCTAssertEqual(finalScoreViewState.playerRows[0].avatarText, "玩")
        XCTAssertEqual(finalScoreViewState.playerRows[0].playerDisplayName, "玩家 1")
        XCTAssertEqual(finalScoreViewState.playerRows[0].totalPoints, 10)
        XCTAssertEqual(finalScoreViewState.playerRows[0].totalText, "最终得分 10 分")
        XCTAssertEqual(finalScoreViewState.playerRows[0].totalWidthRatioRelativeToMaxTotal, 0.5, accuracy: 0.0001)
        XCTAssertEqual(finalScoreViewState.playerRows[0].segments.count, 6)
        XCTAssertEqual(finalScoreViewState.playerRows[0].segments.map(\.category), [
            .weeklyAchievements,
            .fishPrintedPoints,
            .gameEndAbilityPoints,
            .eggsAndYoung,
            .schools,
            .consumedFish
        ])
        XCTAssertEqual(finalScoreViewState.playerRows[0].segments[0].widthRatioRelativeToMaxTotal, 0.15, accuracy: 0.0001)
        XCTAssertTrue(finalScoreViewState.playerRows[1].isWinner)
        XCTAssertEqual(finalScoreViewState.playerRows[1].totalWidthRatioRelativeToMaxTotal, 1, accuracy: 0.0001)
        XCTAssertEqual(finalScoreViewState.legendItems.count, 6)
        XCTAssertEqual(Set(finalScoreViewState.legendItems.map(\.displayColorKey)).count, 6)
        XCTAssertGreaterThan(Set(finalScoreViewState.playerRows[1].segments.map(\.displayColorKey)).count, 1)
    }

    func testFinalScoreSegmentsUseSharedMaximumTotalScaleAcrossPlayers() {
        let playerOneScore = FinalScoreBreakdown(
            playerId: "player-1",
            weeklyAchievementPoints: 2,
            fishPrintedPoints: 2,
            gameEndAbilityPoints: 0,
            eggPoints: 0,
            youngPoints: 0,
            schoolPoints: 6,
            consumedFishPoints: 0,
            totalPoints: 10
        )
        let playerTwoScore = FinalScoreBreakdown(
            playerId: "player-2",
            weeklyAchievementPoints: 4,
            fishPrintedPoints: 8,
            gameEndAbilityPoints: 0,
            eggPoints: 0,
            youngPoints: 0,
            schoolPoints: 6,
            consumedFishPoints: 2,
            totalPoints: 20
        )
        let service = makeService(
            hand: [],
            phase: .gameEnded,
            activePlayerId: nil,
            finalScoreResult: FinalScoreResult(
                results: [playerOneScore, playerTwoScore],
                winnerPlayerIds: ["player-2"],
                isTie: false
            )
        )
        service.gameRoom?.players.append(RoomPlayer(playerId: "player-2", displayName: "玩家 2"))
        service.gameState.players.append(Player(id: "player-2", name: "玩家 2"))
        let viewModel = GameBoardViewModel(roomService: service)

        guard let viewState = viewModel.finalScoreViewState else {
            return XCTFail("Expected final score view state.")
        }
        let lowerRow = viewState.playerRows[0]
        let higherRow = viewState.playerRows[1]
        let lowerSchool = lowerRow.segments.first { $0.category == .schools }
        let higherSchool = higherRow.segments.first { $0.category == .schools }

        XCTAssertEqual(viewState.maxTotalPoints, 20)
        XCTAssertEqual(lowerSchool?.points, 6)
        XCTAssertEqual(higherSchool?.points, 6)
        XCTAssertEqual(lowerSchool?.widthRatioRelativeToMaxTotal ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(higherSchool?.widthRatioRelativeToMaxTotal ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(
            lowerRow.segments.reduce(0) { $0 + $1.widthRatioRelativeToMaxTotal },
            lowerRow.totalWidthRatioRelativeToMaxTotal,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            higherRow.segments.reduce(0) { $0 + $1.widthRatioRelativeToMaxTotal },
            higherRow.totalWidthRatioRelativeToMaxTotal,
            accuracy: 0.0001
        )
        XCTAssertLessThan(lowerRow.totalWidthRatioRelativeToMaxTotal, higherRow.totalWidthRatioRelativeToMaxTotal)
        XCTAssertEqual(higherRow.totalWidthRatioRelativeToMaxTotal, 1, accuracy: 0.0001)
    }

    func testFinalScoreViewStateShowsSharksAndReefsCoralScoreSegmentsAndLegend() {
        let score = FinalScoreBreakdown(
            playerId: "player-1",
            weeklyAchievementPoints: 0,
            fishPrintedPoints: 0,
            gameEndAbilityPoints: 0,
            eggPoints: 0,
            youngPoints: 0,
            schoolPoints: 0,
            consumedFishPoints: 0,
            coralPoints: 7,
            completeReefBonusPoints: 11,
            totalPoints: 18
        )
        let service = makeService(
            hand: [],
            phase: .gameEnded,
            activePlayerId: nil,
            finalScoreResult: FinalScoreResult(
                results: [score],
                winnerPlayerIds: ["player-1"],
                isTie: false
            ),
            enabledExpansions: [.sharksAndReefs],
            coralReefs: [
                CoralReefState(diveSite: .blue, coralCount: 6, maxCoral: 6, completionBonus: 6),
                CoralReefState(diveSite: .purple, coralCount: 5, maxCoral: 6, completionBonus: 8),
                CoralReefState(diveSite: .green, coralCount: 6, maxCoral: 6, completionBonus: 5)
            ]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        guard let row = viewModel.finalScoreViewState?.playerRows.first else {
            return XCTFail("Expected final score row.")
        }

        XCTAssertEqual(row.segments.map(\.category), [
            .weeklyAchievements,
            .fishPrintedPoints,
            .gameEndAbilityPoints,
            .eggsAndYoung,
            .schools,
            .consumedFish,
            .coral,
            .completeReefBonus
        ])
        XCTAssertEqual(row.segments.first { $0.category == .coral }?.title, "珊瑚")
        XCTAssertEqual(row.segments.first { $0.category == .coral }?.points, 7)
        XCTAssertEqual(row.segments.first { $0.category == .completeReefBonus }?.title, "完整珊瑚礁奖励")
        XCTAssertEqual(row.segments.first { $0.category == .completeReefBonus }?.points, 11)
        XCTAssertEqual(
            Array(viewModel.finalScoreViewState?.legendItems.map(\.title).suffix(2) ?? []),
            ["珊瑚", "完整珊瑚礁奖励"]
        )
    }

    func testSampleModeFinalScoreWithoutCoralReefsDoesNotShowSharksAndReefsScoreSegments() {
        let score = FinalScoreBreakdown(
            playerId: "player-1",
            weeklyAchievementPoints: 0,
            fishPrintedPoints: 1,
            gameEndAbilityPoints: 0,
            eggPoints: 0,
            youngPoints: 0,
            schoolPoints: 0,
            consumedFishPoints: 0,
            totalPoints: 1
        )
        let service = makeService(
            hand: [],
            phase: .gameEnded,
            activePlayerId: nil,
            finalScoreResult: FinalScoreResult(
                results: [score],
                winnerPlayerIds: ["player-1"],
                isTie: false
            ),
            enabledExpansions: [.sharksAndReefs],
            coralReefs: []
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.finalScoreViewState?.playerRows.first?.segments.count, 6)
        XCTAssertFalse(viewModel.finalScoreViewState?.legendItems.map(\.title).contains("珊瑚") ?? true)
    }

    func testFinalScoreViewStateDoesNotShowCoralScoresWhenSharksAndReefsIsDisabled() {
        let score = FinalScoreBreakdown(
            playerId: "player-1",
            weeklyAchievementPoints: 0,
            fishPrintedPoints: 0,
            gameEndAbilityPoints: 0,
            eggPoints: 0,
            youngPoints: 0,
            schoolPoints: 0,
            consumedFishPoints: 0,
            coralPoints: 6,
            completeReefBonusPoints: 6,
            totalPoints: 12
        )
        let service = makeService(
            hand: [],
            phase: .gameEnded,
            activePlayerId: nil,
            finalScoreResult: FinalScoreResult(
                results: [score],
                winnerPlayerIds: ["player-1"],
                isTie: false
            ),
            enabledExpansions: [],
            coralReefs: [
                CoralReefState(diveSite: .blue, coralCount: 6, maxCoral: 6, completionBonus: 6)
            ]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.finalScoreViewState?.playerRows.first?.segments.count, 6)
        XCTAssertFalse(viewModel.finalScoreViewState?.legendItems.map(\.title).contains("珊瑚") ?? true)
    }

    func testFinalScoreZeroCategoriesDoNotBreakProportionCalculation() {
        let service = makeService(
            hand: [],
            phase: .gameEnded,
            activePlayerId: nil,
            finalScoreResult: FinalScoreResult(
                results: [
                    FinalScoreBreakdown(
                        playerId: "player-1",
                        weeklyAchievementPoints: 0,
                        fishPrintedPoints: 0,
                        gameEndAbilityPoints: 0,
                        eggPoints: 0,
                        youngPoints: 0,
                        schoolPoints: 0,
                        consumedFishPoints: 0,
                        totalPoints: 0
                    )
                ],
                winnerPlayerIds: ["player-1"],
                isTie: false
            )
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let proportions = viewModel.finalScoreViewState?.playerRows[0].segments.map(\.widthRatioRelativeToMaxTotal)

        XCTAssertEqual(proportions, [0, 0, 0, 0, 0, 0])
        XCTAssertEqual(viewModel.finalScoreViewState?.maxTotalPoints, 0)
        XCTAssertEqual(viewModel.finalScoreViewState?.playerRows[0].totalWidthRatioRelativeToMaxTotal, 0)
    }

    func testGameEndedPhasePreventsPlayFishAndDiveSubmission() {
        let service = makeService(
            hand: ["starter-fish-1"],
            phase: .gameEnded,
            activePlayerId: nil,
            finalScoreResult: FinalScoreResult(
                results: [],
                winnerPlayerIds: [],
                isTie: false
            )
        )
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.submitDive(to: .blue)
        viewModel.submitPlayFish()

        XCTAssertFalse(viewModel.canDive)
        XCTAssertFalse(viewModel.canSubmitPlayFish)
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    func testGameEndedEventSummaryShowsWinner() {
        let service = makeService(hand: [])
        let viewModel = GameBoardViewModel(roomService: service)
        let event = GameEvent(
            sequenceNumber: 12,
            roomId: "room-1",
            timestamp: Date(timeIntervalSince1970: 1_000),
            payload: .gameEnded(
                GameEndedEvent(
                    finalScoreResult: FinalScoreResult(
                        results: [],
                        winnerPlayerIds: ["player-1"],
                        isTie: false
                    )
                )
            )
        )

        XCTAssertEqual(viewModel.eventSummary(event), "#12 游戏结束，获胜玩家：玩家 1")
    }

    func testDrawFishPendingChoiceShowsDrawAndSkipActions() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertTrue(pendingChoice.canResolve)
        XCTAssertEqual(pendingChoice.title, AppStrings.pendingChoiceKindName(.drawFish))
        XCTAssertEqual(pendingChoice.actions.map(\.title), [
            AppStrings.GameBoard.drawOneFishCard,
            AppStrings.GameBoard.skipChoice
        ])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [true, true])
    }

    func testPrintedDiveBonusPendingChoiceTitlesUseChineseCopy() {
        let choices = [
            pendingChoice(kind: .drawFish, source: .diveBonus(.blue)),
            pendingChoice(kind: .placeEgg, source: .diveBonus(.green)),
            pendingChoice(kind: .moveYoungOrSchool, source: .diveBonus(.purple))
        ]
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: Dictionary(uniqueKeysWithValues: choices.map { ($0.choiceId, $0) })
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: viewModel.pendingChoices.map { ($0.choiceId, $0.title) }),
            [
                "choice-drawFish": AppStrings.pendingChoiceKindName(.drawFish),
                "choice-placeEgg": AppStrings.pendingChoiceKindName(.placeEgg),
                "choice-moveYoungOrSchool": AppStrings.GameBoard.moveYoungOrSchool
            ]
        )
    }

    func testRecoverFromDiscardPendingChoiceListsDiscardCards() {
        let choice = pendingChoice(kind: .recoverFromDiscardOrDraw)
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            discardPile: ["fish-9"]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.targetPrompt, AppStrings.GameBoard.chooseDiscardCardToRecover)
        XCTAssertEqual(pendingChoice.cardTargets.map(\.cardId), ["fish-9"])
        XCTAssertEqual(pendingChoice.cardTargets.map(\.subtitle), [AppStrings.GameBoard.recoverFromDiscardOrDraw])
        XCTAssertEqual(pendingChoice.actions.map(\.title), [AppStrings.GameBoard.skipChoice])
    }

    func testRecoverFromDiscardPendingChoiceOffersDeckDrawWhenDiscardIsEmpty() {
        let choice = pendingChoice(kind: .recoverFromDiscardOrDraw)
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            discardPile: [],
            fishDrawPile: ["fish-9"]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.targetPrompt, AppStrings.GameBoard.discardPileEmptyDrawHint)
        XCTAssertTrue(pendingChoice.cardTargets.isEmpty)
        XCTAssertEqual(pendingChoice.actions.map(\.title), [
            AppStrings.GameBoard.drawOneFishCard,
            AppStrings.GameBoard.skipChoice
        ])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [true, true])
    }

    func testMoveYoungOrSchoolPendingChoiceListsSourcesAndTargets() {
        let choice = pendingChoice(kind: .moveYoungOrSchool, source: .diveBonus(.purple))
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.targetPrompt, AppStrings.GameBoard.moveYoungOrSchool)
        XCTAssertTrue(
            pendingChoice.moveTargets.contains {
                $0.source == Self.resourceSourceAddress && $0.kind == .young
            }
        )
        XCTAssertTrue(
            pendingChoice.moveTargets.contains {
                $0.source == Self.resourceSourceAddress
                    && $0.target != Self.resourceSourceAddress
                    && $0.kind == .school
            }
        )
        XCTAssertTrue(
            pendingChoice.moveTargets.allSatisfy {
                $0.subtitle.contains(AppStrings.GameBoard.chooseMoveSource)
                    && $0.subtitle.contains(AppStrings.GameBoard.chooseMoveTarget)
            }
        )
    }

    func testMoveYoungOrSchoolPendingChoiceShowsNoMovableResources() {
        let choice = pendingChoice(kind: .moveYoungOrSchool, source: .diveBonus(.purple))
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            resourceSourceResources: [],
            clearAllSlotResources: true
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertTrue(pendingChoice.moveTargets.isEmpty)
        XCTAssertEqual(pendingChoice.noTargetsText, AppStrings.GameBoard.noMovableYoungOrSchool)
        XCTAssertEqual(pendingChoice.actions.map(\.title), [AppStrings.GameBoard.skipChoice])
    }

    func testPlaceEggPendingChoiceShowsTargetPromptAndSkipAction() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.targetPrompt, AppStrings.GameBoard.choosePlaceEggTarget)
        XCTAssertFalse(pendingChoice.targets.isEmpty)
        XCTAssertEqual(pendingChoice.actions.map(\.title), [AppStrings.GameBoard.skipChoice])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [true])
    }

    func testHatchEggPendingChoiceShowsTargetPromptAndSkipAction() {
        let choice = pendingChoice(kind: .hatchEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.targetPrompt, AppStrings.GameBoard.chooseHatchEggTarget)
        XCTAssertFalse(pendingChoice.targets.isEmpty)
        XCTAssertEqual(pendingChoice.actions.map(\.title), [AppStrings.GameBoard.skipChoice])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [true])
    }

    func testPlaceYoungPendingChoiceShowsTargetPromptAndSkipAction() {
        let choice = pendingChoice(kind: .placeYoung)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.targetPrompt, AppStrings.GameBoard.choosePlaceYoungTarget)
        XCTAssertFalse(pendingChoice.targets.isEmpty)
        XCTAssertEqual(pendingChoice.actions.map(\.title), [AppStrings.GameBoard.skipChoice])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [true])
    }

    func testDrawFishPendingChoiceGeneratesRewardToken() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let rewardPool = viewModel.rewardPoolViewState

        XCTAssertTrue(rewardPool.isActive)
        XCTAssertEqual(rewardPool.rewards.map(\.kind), [.drawFish])
        XCTAssertEqual(rewardPool.rewards.map(\.title), [AppStrings.GameBoard.drawOneFishCard])
        XCTAssertEqual(rewardPool.instructionText, AppStrings.GameBoard.chooseRewardToken)
    }

    func testPlaceEggPendingChoiceGeneratesEggRewardToken() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let rewardPool = viewModel.rewardPoolViewState

        XCTAssertEqual(rewardPool.rewards.map(\.kind), [.placeEgg])
        XCTAssertEqual(rewardPool.rewards.first?.title, AppStrings.GameBoard.placeEggAbilityAction)
        XCTAssertEqual(rewardPool.instructionText, AppStrings.GameBoard.chooseRewardThenTarget)
    }

    func testHatchEggPendingChoiceGeneratesHatchRewardToken() {
        let choice = pendingChoice(kind: .hatchEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let rewardPool = viewModel.rewardPoolViewState

        XCTAssertEqual(rewardPool.rewards.map(\.kind), [.hatchEgg])
        XCTAssertEqual(rewardPool.rewards.first?.title, AppStrings.GameBoard.hatchEggAbilityAction)
        XCTAssertEqual(rewardPool.instructionText, AppStrings.GameBoard.chooseRewardThenTarget)
    }

    func testPlaceYoungPendingChoiceGeneratesYoungRewardToken() {
        let choice = pendingChoice(kind: .placeYoung)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let rewardPool = viewModel.rewardPoolViewState

        XCTAssertEqual(rewardPool.rewards.map(\.kind), [.placeYoung])
        XCTAssertEqual(rewardPool.rewards.first?.title, AppStrings.GameBoard.placeYoungAbilityAction)
        XCTAssertEqual(rewardPool.instructionText, AppStrings.GameBoard.chooseRewardThenTarget)
    }

    func testMoveYoungOrSchoolPendingChoiceGeneratesMoveRewardToken() {
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let rewardPool = viewModel.rewardPoolViewState

        XCTAssertEqual(rewardPool.rewards.map(\.kind), [.moveYoungOrSchool])
        XCTAssertEqual(rewardPool.rewards.first?.title, AppStrings.GameBoard.moveYoungOrSchool)
        XCTAssertEqual(rewardPool.instructionText, AppStrings.GameBoard.chooseRewardThenSource)
    }

    func testCoralReefPendingChoiceGeneratesPaymentAndSkipRewardTokens() {
        let choice = pendingChoice(kind: .gainCoral, source: .coralReef(.blue))
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let rewardPool = viewModel.rewardPoolViewState

        XCTAssertEqual(rewardPool.rewards.map(\.kind), [.gainCoral, .gainCoral, .gainCoral, .skipOrEnd])
        XCTAssertEqual(
            rewardPool.rewards.map(\.title),
            [
                AppStrings.GameBoard.payOneEgg,
                AppStrings.GameBoard.payOneYoung,
                AppStrings.GameBoard.discardOneHandCard,
                AppStrings.GameBoard.skipChoice
            ]
        )
        XCTAssertEqual(rewardPool.instructionText, AppStrings.GameBoard.chooseCoralPayment)
    }

    func testGainCoralAbilityPendingChoiceGeneratesFreeCoralRewardToken() {
        let choice = gainCoralAbilityPendingChoice(selector: .blue)
        let service = makeService(
            hand: [],
            pendingChoices: [choice.choiceId: choice],
            clearAllSlotResources: true,
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let rewardPool = viewModel.rewardPoolViewState

        XCTAssertEqual(rewardPool.rewards.map(\.kind), [.gainCoral])
        XCTAssertEqual(rewardPool.rewards.first?.title, AppStrings.GameBoard.gainOneCoral)
        XCTAssertEqual(rewardPool.rewards.first?.isSelectable, true)
        XCTAssertEqual(rewardPool.instructionText, AppStrings.GameBoard.chooseCoralDiveSite)
    }

    func testAnyGainCoralAbilityPendingChoiceGeneratesDiveSiteRewardTokens() {
        let choice = gainCoralAbilityPendingChoice(selector: .any)
        let service = makeService(
            hand: [],
            pendingChoices: [choice.choiceId: choice],
            clearAllSlotResources: true,
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.rewardPoolViewState.rewards.map(\.title), [
            "\(AppStrings.oceanDiveSiteName(.blue)) \(AppStrings.GameBoard.gainOneCoral)",
            "\(AppStrings.oceanDiveSiteName(.purple)) \(AppStrings.GameBoard.gainOneCoral)",
            "\(AppStrings.oceanDiveSiteName(.green)) \(AppStrings.GameBoard.gainOneCoral)"
        ])
    }

    func testSelectingGainCoralAbilityRewardTokenBuildsFreeResolveCommand() throws {
        let choice = gainCoralAbilityPendingChoice(selector: .blue)
        let service = makeService(
            hand: [],
            pendingChoices: [choice.choiceId: choice],
            clearAllSlotResources: true,
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        viewModel.selectRewardToken(token.id)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .gainCoralFromAbility(diveSite: .blue))
    }

    func testFullCoralReefDisablesGainCoralAbilityToken() throws {
        let choice = gainCoralAbilityPendingChoice(selector: .blue)
        let service = makeService(
            hand: [],
            pendingChoices: [choice.choiceId: choice],
            clearAllSlotResources: true,
            coralReefs: [
                CoralReefState(diveSite: .blue, coralCount: 6, maxCoral: 6, completionBonus: 6)
            ]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        XCTAssertEqual(token.isSelectable, false)
        XCTAssertEqual(token.unavailableReasonText, AppStrings.GameBoard.coralReefFull)
    }

    func testCoralReefOverlayRewardPoolStillRequiresPaymentTokens() {
        let choice = pendingChoice(kind: .gainCoral, source: .coralReef(.blue))
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(
            viewModel.rewardPoolViewState.rewards.map(\.title),
            [
                AppStrings.GameBoard.payOneEgg,
                AppStrings.GameBoard.payOneYoung,
                AppStrings.GameBoard.discardOneHandCard,
                AppStrings.GameBoard.skipChoice
            ]
        )
        XCTAssertFalse(
            viewModel.rewardPoolViewState.rewards.contains {
                $0.title == AppStrings.GameBoard.gainOneCoral
            }
        )
    }

    func testSelectingCoralEggRewardTokenThenSourceBuildsGainCoralCommand() throws {
        let choice = pendingChoice(kind: .gainCoral, source: .coralReef(.blue))
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first { $0.title == AppStrings.GameBoard.payOneEgg })

        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.chooseCoralResourceSource)
        XCTAssertTrue(
            viewModel.oceanSlots.contains {
                $0.address == Self.resourceSourceAddress
                    && $0.rewardSelectionReasonText == AppStrings.GameBoard.chooseCoralResourceSource
            }
        )

        viewModel.selectTargetSlot(Self.resourceSourceAddress)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .gainCoralWithEgg(source: Self.resourceSourceAddress))
    }

    func testSelectingCoralDiscardRewardTokenThenHandCardBuildsGainCoralCommand() throws {
        let choice = pendingChoice(kind: .gainCoral, source: .coralReef(.blue))
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            coralReefs: CoralReefState.sharksAndReefsInitial
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first { $0.title == AppStrings.GameBoard.discardOneHandCard })

        viewModel.selectRewardToken(token.id)
        viewModel.selectHandCard("fish-2")

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .gainCoralByDiscard(cardId: "fish-2"))
    }

    func testScatterSchoolPendingChoiceShowsSourceRewardTokenAndHighlightsSchoolSource() throws {
        let choice = scatterSchoolPendingChoice()
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        XCTAssertEqual(viewModel.rewardPoolViewState.rewards.map(\.kind), [.scatterSchool])
        XCTAssertEqual(token.title, AppStrings.GameBoard.scatterSchool)
        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.scatterSchoolSource)
        XCTAssertTrue(viewModel.oceanSlots.contains {
            $0.address == Self.resourceSourceAddress
                && $0.isHighlightedByRewardSelection
                && $0.rewardSelectionReasonText == AppStrings.GameBoard.scatterSchoolSource
        })
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    func testSelectingScatterSchoolSourceBuildsResolveCommand() throws {
        let choice = scatterSchoolPendingChoice()
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        viewModel.selectRewardToken(token.id)
        viewModel.selectTargetSlot(Self.resourceSourceAddress)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .chooseScatterSchoolSource(Self.resourceSourceAddress))
    }

    func testScatterSchoolYoungProgressShowsTargetRewardAndRejectsUsedTargetHighlight() throws {
        let choice = scatterSchoolPendingChoice(
            expectedInput: .scatterSchoolYoungTarget,
            progress: ScatterSchoolProgress(
                sourceSlot: Self.resourceSourceAddress,
                targetSlots: [Self.slotAddress],
                requiredTargetCount: 4,
                requiresSchoolSource: true
            )
        )
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        XCTAssertEqual(token.title, AppStrings.GameBoard.scatterSchoolYoungTarget)
        XCTAssertEqual(token.subtitle, AppStrings.GameBoard.scatterSchoolProgressText(completedCount: 1, totalCount: 4))
        viewModel.selectRewardToken(token.id)

        XCTAssertFalse(oceanSlot(in: viewModel, address: Self.slotAddress).isHighlightedByRewardSelection)
        XCTAssertTrue(oceanSlot(in: viewModel, address: Self.forageTargetAddress).isHighlightedByRewardSelection)
    }

    func testSelectingScatterSchoolYoungTargetBuildsResolveCommand() throws {
        let choice = scatterSchoolPendingChoice(
            expectedInput: .scatterSchoolYoungTarget,
            progress: ScatterSchoolProgress(
                sourceSlot: Self.resourceSourceAddress,
                targetSlots: [],
                requiredTargetCount: 4,
                requiresSchoolSource: true
            )
        )
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        viewModel.selectRewardToken(token.id)
        viewModel.selectTargetSlot(Self.forageTargetAddress)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .placeScatterSchoolYoung(Self.forageTargetAddress))
    }

    func testScatterSchoolWithoutSchoolShowsSingleYoungTargetReward() throws {
        let choice = scatterSchoolPendingChoice()
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            resourceSourceResources: [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 1)
            ],
            clearAllSlotResources: true
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        XCTAssertEqual(token.title, AppStrings.GameBoard.scatterSchoolNoSchool)
        XCTAssertEqual(token.subtitle, AppStrings.GameBoard.scatterSchoolProgressText(completedCount: 0, totalCount: 1))
        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.scatterSchoolYoungTarget)
        XCTAssertTrue(oceanSlot(in: viewModel, address: Self.slotAddress).isHighlightedByRewardSelection)
    }

    func testConsumeFishFromHandShowsConsumerRewardTokenAndHighlightsVisibleFishCard() throws {
        let choice = consumeFishFromHandPendingChoice()
        let service = makeService(hand: ["consume.short"], pendingChoices: [choice.choiceId: choice])
        setContent(.fishCard("consume.consumer"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { self.consumeFishCatalog() }
        )
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        XCTAssertEqual(token.kind, .consumeFish)
        XCTAssertEqual(token.title, AppStrings.GameBoard.consumeFishFromHand)
        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.consumeFishConsumer)
        XCTAssertTrue(oceanSlot(in: viewModel, address: Self.slotAddress).isHighlightedByRewardSelection)
        XCTAssertFalse(oceanSlot(in: viewModel, address: Self.forageTargetAddress).isHighlightedByRewardSelection)
    }

    func testConsumeFishFromHandHandStepOnlyAllowsShorterHandFishAndBuildsResolveCommand() throws {
        let choice = consumeFishFromHandPendingChoice(
            expectedInput: .consumeFishHandCard,
            progress: ConsumeFishFromHandProgress(consumerSlot: Self.slotAddress)
        )
        let service = makeService(
            hand: ["consume.short", "consume.same", "consume.long"],
            pendingChoices: [choice.choiceId: choice]
        )
        setContent(.fishCard("consume.consumer"), at: Self.slotAddress, in: service)
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { self.consumeFishCatalog() }
        )
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        viewModel.selectRewardToken(token.id)
        XCTAssertNil(viewModel.handViewState.cards.first { $0.cardId == "consume.short" }?.unavailableReasonText)
        XCTAssertEqual(
            viewModel.handViewState.cards.first { $0.cardId == "consume.same" }?.unavailableReasonText,
            AppStrings.GameBoard.consumeFishMustBeShorter
        )

        viewModel.selectHandCard("consume.same")
        XCTAssertTrue(service.submittedCommands.isEmpty)
        viewModel.selectHandCard("consume.short")

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .consumeFishFromHand("consume.short"))
    }

    func testPlayFishForFreeShowsHandRewardTokenAndFiltersHandCards() throws {
        let choice = playFishForFreePendingChoice(filter: .lengthBucket(.small))
        let service = makeService(
            hand: ["free.small", "free.medium"],
            pendingChoices: [choice.choiceId: choice]
        )
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { self.playFishForFreeCatalog() }
        )
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        XCTAssertEqual(token.kind, .playFishForFree)
        XCTAssertEqual(token.title, AppStrings.GameBoard.playFishForFree)
        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.playFishForFreeHandCard)
        XCTAssertNil(viewModel.handViewState.cards.first { $0.cardId == "free.small" }?.unavailableReasonText)
        XCTAssertEqual(
            viewModel.handViewState.cards.first { $0.cardId == "free.medium" }?.unavailableReasonText,
            AppStrings.GameBoard.playFishForFreeFilterMismatch
        )
    }

    func testPlayFishForFreeTargetStepHighlightsLegalSlotAndBuildsResolveCommand() throws {
        let choice = playFishForFreePendingChoice(
            expectedInput: .freePlayTargetSlot,
            progress: PlayFishForFreeProgress(selectedCardId: "free.sunlight")
        )
        let service = makeService(
            hand: ["free.sunlight"],
            pendingChoices: [choice.choiceId: choice],
            emptySlots: [Self.slotAddress, Self.blueTwilightSlotAddress]
        )
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalogProvider: { self.playFishForFreeCatalog() }
        )
        let token = try XCTUnwrap(viewModel.rewardPoolViewState.rewards.first)

        viewModel.selectRewardToken(token.id)

        XCTAssertTrue(oceanSlot(in: viewModel, address: Self.slotAddress).isHighlightedByRewardSelection)
        XCTAssertFalse(oceanSlot(in: viewModel, address: Self.blueTwilightSlotAddress).isHighlightedByRewardSelection)
        viewModel.selectTargetSlot(Self.blueTwilightSlotAddress)
        XCTAssertTrue(service.submittedCommands.isEmpty)
        viewModel.selectTargetSlot(Self.slotAddress)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .playFishForFree(cardId: "free.sunlight", targetSlot: Self.slotAddress))
    }

    func testCompoundAbilityPendingChoiceGeneratesRemainingRewardTokens() {
        let choice = compoundAbilityPendingChoice()
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let rewards = viewModel.rewardPoolViewState.rewards

        XCTAssertEqual(rewards.map(\.kind), [
            .compoundPlaceEgg,
            .compoundPlaceEgg,
            .compoundHatchEgg,
            .skipOrEnd
        ])
        XCTAssertEqual(
            rewards.map(\.title),
            [
                AppStrings.GameBoard.placeEggAbilityAction,
                AppStrings.GameBoard.placeEggAbilityAction,
                AppStrings.GameBoard.hatchEggAbilityAction,
                AppStrings.GameBoard.finishAbility
            ]
        )
    }

    func testSelectingEggRewardTokenEntersPlaceEggTargetSelectionMode() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.selectedRewardTokenId, token.id)
        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.chooseLeftTarget)
        XCTAssertTrue(
            viewModel.oceanSlots.contains {
                $0.isHighlightedByRewardSelection
                    && $0.rewardSelectionReasonText == AppStrings.GameBoard.chooseLeftTarget
            }
        )
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    func testSelectingHatchRewardTokenEntersHatchEggTargetSelectionMode() {
        let choice = pendingChoice(kind: .hatchEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.selectedRewardTokenId, token.id)
        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.chooseLeftTarget)
        XCTAssertTrue(
            viewModel.oceanSlots.contains {
                $0.address == Self.resourceSourceAddress
                    && $0.isHighlightedByRewardSelection
            }
        )
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    func testSelectingMoveRewardTokenEntersMoveSourceSelectionMode() {
        let choice = pendingChoice(kind: .moveYoungOrSchool)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        viewModel.selectRewardToken(token.id)

        XCTAssertEqual(viewModel.rewardPoolViewState.instructionText, AppStrings.GameBoard.chooseSource)
        XCTAssertTrue(
            viewModel.oceanSlots.contains {
                $0.address == Self.resourceSourceAddress
                    && $0.rewardSelectionReasonText == AppStrings.GameBoard.chooseSource
            }
        )
    }

    func testClickingDrawRewardTokenBuildsDrawResolveCommand() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        XCTAssertEqual(token.title, AppStrings.GameBoard.drawFishCard(count: 1))
        viewModel.selectRewardToken(token.id)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .draw(count: 1))
    }

    func testDrawFourPendingChoiceGeneratesDrawFourRewardTokenAndCommand() {
        let choice = abilityPendingChoice(
            cardId: "base.starter.127",
            kind: .drawFish,
            drawCount: 4
        )
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            fishDrawPile: ["base.main.001", "base.main.002", "base.main.003", "base.main.004"]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        XCTAssertEqual(token.title, AppStrings.GameBoard.drawFishCard(count: 4))

        viewModel.selectRewardToken(token.id)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .draw(count: 4))
    }

    func testRecoverRewardTokenDrawsFromDeckWhenDiscardPileIsEmpty() {
        let choice = pendingChoice(kind: .recoverFromDiscardOrDraw)
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            discardPile: [],
            fishDrawPile: ["fish-9"]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        XCTAssertEqual(token.kind, .recoverFromDiscardOrDraw)
        XCTAssertEqual(token.subtitle, AppStrings.GameBoard.discardPileEmptyDrawAlternative)

        viewModel.selectRewardToken(token.id)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.resolution, .drawFromDeck)
    }

    func testRecoverRewardTokenRecoversDiscardCardWhenDiscardPileHasCards() {
        let choice = pendingChoice(kind: .recoverFromDiscardOrDraw)
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            discardPile: ["fish-9"]
        )
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        XCTAssertEqual(token.kind, .recoverFromDiscardOrDraw)
        XCTAssertEqual(token.subtitle, "Fish 9")

        viewModel.selectRewardToken(token.id)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.resolution, .recoverCard("fish-9"))
    }

    func testClickingEndAbilityRewardTokenBuildsFinishAbilityCommand() throws {
        let choice = compoundAbilityPendingChoice()
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards.first { $0.kind == .skipOrEnd }

        viewModel.selectRewardToken(try XCTUnwrap(token).id)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .finishAbility)
    }

    func testUnsupportedPendingChoiceGeneratesUnsupportedRewardToken() {
        let choice = pendingChoice(kind: .unsupported, source: .placeholder("sample-dlc"))
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let token = viewModel.rewardPoolViewState.rewards[0]

        XCTAssertEqual(token.kind, .unsupported)
        XCTAssertTrue(token.isUnsupported)
        XCTAssertEqual(token.title, AppStrings.GameBoard.abilityUnsupported)
        XCTAssertFalse(token.isSelectable)
    }

    func testOceanColumnsExposeSunlightTwilightMidnightZoneSections() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        for column in viewModel.oceanColumns {
            XCTAssertEqual(column.zoneSections.map(\.zone), [.sunlit, .twilight, .midnight])
            XCTAssertEqual(column.zoneSections.map { $0.slots.count }, [3, 1, 2])
        }
    }

    func testBottomBonusIsSeparateFromOceanZoneSections() {
        let queue = activeDiveQueue(diveSite: .blue, source: .bottomBonus)
        let service = makeService(hand: ["fish-2"], activeDiveQueue: queue)
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.bottomAreas.count, 3)
        XCTAssertEqual(viewModel.highlightedBottomBonusDiveSite, .blue)
        XCTAssertTrue(viewModel.bottomAreas.contains { $0.diveSite == .blue && $0.isHighlightedByDiveQueue })
        XCTAssertTrue(viewModel.oceanColumns.flatMap(\.zoneSections).allSatisfy { !$0.isHighlightedByDiveQueue })
        XCTAssertTrue(viewModel.oceanColumns.flatMap(\.zoneSections).flatMap(\.slots).contains {
            $0.address.rowIndex == 5
        })
    }

    func testPrintedDiveBonusHighlightsMatchingZoneSectionOnly() throws {
        let queue = activeDiveQueue(diveSite: .blue, source: .printedDiveBonus(.twilight))
        let service = makeService(hand: ["fish-2"], activeDiveQueue: queue)
        let viewModel = GameBoardViewModel(roomService: service)

        let blueColumn = viewModel.oceanColumns.first { $0.diveSite == .blue }
        let highlightedZones = try XCTUnwrap(blueColumn).zoneSections
            .filter(\.isHighlightedByDiveQueue)
            .map(\.zone)

        XCTAssertEqual(highlightedZones, [.twilight])
        XCTAssertNil(viewModel.highlightedBottomBonusDiveSite)
    }

    func testPerformSkipPendingChoiceActionBuildsResolvePendingChoiceCommand() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.performPendingChoiceAction(.skip, for: choice.choiceId)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }

        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .skip)
    }

    func testResolvePendingChoiceTargetBuildsChooseTargetCommand() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)
        let target = viewModel.pendingChoices[0].targets[0].address

        viewModel.resolvePendingChoice(choice.choiceId, target: target)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }

        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .chooseTarget(target))
    }

    func testPlaceEggTargetsIncludeFishSlotsWithoutEggOnly() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let targets = viewModel.pendingChoiceTargets(for: choice)

        XCTAssertTrue(targets.contains { $0.address == Self.forageYoungAddress })
        XCTAssertFalse(targets.contains { $0.address == Self.forageEggAddress })
        XCTAssertFalse(targets.contains { $0.address == Self.slotAddress })
    }

    func testHatchEggTargetsIncludeSlotsWithEggOnly() {
        let choice = pendingChoice(kind: .hatchEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let targets = viewModel.pendingChoiceTargets(for: choice)

        XCTAssertTrue(targets.contains { $0.address == Self.forageEggAddress })
        XCTAssertFalse(targets.contains { $0.address == Self.forageYoungAddress })
        XCTAssertFalse(targets.contains { $0.address == Self.slotAddress })
    }

    func testOceanSlotResourcesTextDisplaysSchool() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        let slot = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)

        XCTAssertTrue(slot.resourcesText.contains("鱼群 1"))
    }

    func testHatchEggTargetResourcesTextDisplaysSchool() {
        let choice = pendingChoice(kind: .hatchEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let target = viewModel.pendingChoiceTargets(for: choice)
            .first { $0.address == Self.resourceSourceAddress }

        XCTAssertEqual(target?.resourcesText, "鱼卵 1，幼鱼 1，鱼群 1")
    }

    func testPendingChoiceShowsNoTargetsWhenNoneAreLegal() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(
            hand: ["fish-2"],
            pendingChoices: [choice.choiceId: choice],
            emptySlots: [Self.slotAddress, Self.forageEggAddress, Self.forageYoungAddress]
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertTrue(pendingChoice.targets.isEmpty)
        XCTAssertEqual(pendingChoice.noTargetsText, AppStrings.GameBoard.noPendingChoiceTargets)
        XCTAssertEqual(pendingChoice.actions.map(\.title), [AppStrings.GameBoard.skipChoice])
    }

    private static let slotAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .blue,
        rowIndex: 0
    )

    private static let resourceSourceAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .purple,
        rowIndex: 3
    )

    private static let blueTwilightSlotAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .blue,
        rowIndex: 3
    )

    private static let forageTargetAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .blue,
        rowIndex: 4
    )

    private static let forageEggAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .blue,
        rowIndex: 4
    )

    private static let forageYoungAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .green,
        rowIndex: 1
    )

    private func gameEvent(
        _ payload: GameEventPayload,
        sequenceNumber: EventID = 10
    ) -> GameEvent {
        GameEvent(
            sequenceNumber: sequenceNumber,
            roomId: "room-1",
            timestamp: Date(timeIntervalSince1970: 1_000),
            payload: payload
        )
    }

    private func emptyFinalScoreResult() -> FinalScoreResult {
        FinalScoreResult(results: [], winnerPlayerIds: [], isTie: false)
    }

    private func makeService(
        hand: [CardID],
        pendingChoices: [PendingChoiceID: PendingChoice] = [:],
        emptySlots: [OceanSlotAddress] = [GameBoardViewModelTests.slotAddress],
        additionalSlots: [OceanSlot] = [],
        availableDivers: Int = 6,
        phase: GamePhase = .playing,
        currentWeek: Int = 1,
        activePlayerId: PlayerID? = "player-1",
        activeDiveQueue: DiveResolutionQueue? = nil,
        discardPile: [CardID] = [],
        fishDrawPile: [CardID] = [],
        resourceSourceResources: [ResourceQuantity] = [
            ResourceQuantity(kind: .egg, amount: 1),
            ResourceQuantity(kind: .young, amount: 1),
            ResourceQuantity(kind: .school, amount: 1)
        ],
        clearAllSlotResources: Bool = false,
        diveSitesReachedBottomThisWeek: Set<DiveActionSite> = [],
        weeklyAchievementResults: [WeeklyAchievementResult] = [],
        finalScoreResult: FinalScoreResult? = nil,
        additionalPlayers: [RoomPlayer] = [],
        enabledExpansions: [Expansion] = [],
        coralReefs: [CoralReefState] = [],
        eventLog: [GameEvent] = []
    ) -> CapturingRoomService {
        var ocean = OceanState.baseGameInitial(for: "player-1")
        ocean.coralReefs = coralReefs
        if clearAllSlotResources {
            for slotIndex in ocean.slots.indices {
                ocean.slots[slotIndex].resources = []
            }
        }
        for emptySlot in emptySlots {
            if let targetIndex = ocean.slots.firstIndex(where: { $0.address == emptySlot }) {
                ocean.slots[targetIndex].content = .empty
            }
        }
        if let sourceIndex = ocean.slots.firstIndex(where: { $0.address == Self.resourceSourceAddress }) {
            ocean.slots[sourceIndex].resources = resourceSourceResources
        }
        ocean.slots.append(contentsOf: additionalSlots)

        let roomPlayers = [
            RoomPlayer(
                playerId: "player-1",
                displayName: "玩家 1",
                role: .host
            )
        ] + additionalPlayers
        let statePlayers = [Player(id: "player-1", name: "玩家 1")]
            + additionalPlayers.map { Player(id: $0.playerId, name: $0.displayName) }

        return CapturingRoomService(
            gameRoom: GameRoom(
                roomId: "room-1",
                roomCode: "LOCAL",
                hostPlayerId: "player-1",
                players: roomPlayers,
                gameConfig: GameConfig(
                    playerCount: 1,
                    enabledExpansions: enabledExpansions,
                    randomSeed: 1
                ),
                createdAt: Date(timeIntervalSince1970: 1_000),
                updatedAt: Date(timeIntervalSince1970: 1_000)
            ),
            gameState: GameState(
                roomId: "room-1",
                players: statePlayers,
                currentWeek: currentWeek,
                currentTurnIndex: 0,
                activePlayerId: activePlayerId,
                firstPlayerId: "player-1",
                phase: phase,
                eventSequence: 1,
                randomSeed: 1,
                turnsCompletedThisWeek: 0,
                playerGameStates: [
                    "player-1": PlayerGameState(
                        playerId: "player-1",
                        hand: hand,
                        discardPile: discardPile,
                        availableDivers: availableDivers,
                        usedDivers: 6 - availableDivers,
                        ocean: ocean,
                        diveSitesReachedBottomThisWeek: diveSitesReachedBottomThisWeek
                    )
                ],
                deckState: DeckState(
                    starterFishDrawPile: [],
                    fishDrawPile: fishDrawPile,
                    discardPile: []
                ),
                pendingChoices: pendingChoices,
                activeDiveQueue: activeDiveQueue,
                weeklyAchievementResults: weeklyAchievementResults,
                finalScoreResult: finalScoreResult
            ),
            eventLog: eventLog
        )
    }

    private func activeDiveQueue(
        diveSite: DiveActionSite,
        source: DiveResolutionStepSource
    ) -> DiveResolutionQueue {
        DiveResolutionQueue(
            queueId: "queue-1",
            playerId: "player-1",
            diveSite: diveSite,
            steps: [
                DiveResolutionStep(
                    stepId: "step-1",
                    source: source,
                    pendingChoice: PendingChoice(
                        choiceId: "choice-queue-1",
                        playerId: "player-1",
                        source: .diveBonus(diveSite),
                        diveQueueId: "queue-1",
                        diveStepId: "step-1",
                        kind: pendingChoiceKind(for: source),
                        options: [],
                        expectedInput: expectedInput(for: pendingChoiceKind(for: source)),
                        isOptional: true,
                        createdAtSequence: 2
                    )
                )
            ],
            currentStepIndex: 0
        )
    }

    private func pendingChoiceKind(for source: DiveResolutionStepSource) -> PendingChoiceKind {
        switch source {
        case .bottomBonus:
            return .bottomBonus
        case .coralReefOverlay:
            return .gainCoral
        case let .printedDiveBonus(zone):
            switch zone {
            case .sunlit:
                return .drawFish
            case .twilight:
                return .placeEgg
            case .midnight:
                return .moveYoungOrSchool
            }
        case .fishAbility,
             .compoundFishAbility:
            return .compoundAbility
        }
    }

    private func pendingChoice(
        kind: PendingChoiceKind,
        source: PendingChoiceSource = .diveBonus(.blue)
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "choice-\(kind.rawValue)",
            playerId: "player-1",
            source: source,
            kind: kind,
            options: [],
            expectedInput: expectedInput(for: kind),
            isOptional: true,
            createdAtSequence: 2
        )
    }

    private func abilityPendingChoice(
        cardId: CardID,
        kind: PendingChoiceKind,
        drawCount: Int = 1
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "choice-ability-\(cardId)",
            playerId: "player-1",
            source: .fishAbility(cardId),
            kind: kind,
            options: [],
            expectedInput: expectedInput(for: kind),
            isOptional: true,
            abilityDefinition: AbilityDefinition(
                abilityId: "ability-\(cardId)",
                trigger: .ifActivated,
                effects: [.drawFish(count: drawCount)],
                displayText: "发动时：抽 \(drawCount) 张鱼牌"
            ),
            createdAtSequence: 2
        )
    }

    private func gainCoralAbilityPendingChoice(
        selector: CoralDiveSiteSelector,
        cardId: CardID = "sr.main.171"
    ) -> PendingChoice {
        let ability = AbilityDefinition(
            abilityId: "fixture-gain-coral-\(selector.rawValue)",
            trigger: .ifActivated,
            effects: [.gainCoral(selector: selector, count: 1)],
            displayText: "发动时：获得 1 个珊瑚"
        )
        return PendingChoice(
            choiceId: "choice-ability-coral-\(selector.rawValue)",
            playerId: "player-1",
            source: .fishAbility(cardId),
            kind: .gainCoral,
            options: [],
            expectedInput: .coralPlacement,
            isOptional: true,
            abilityDefinition: ability,
            createdAtSequence: 2
        )
    }

    private func scatterSchoolPendingChoice(
        expectedInput: PendingChoiceExpectedInput = .scatterSchoolSource,
        progress: ScatterSchoolProgress? = nil
    ) -> PendingChoice {
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
            expectedInput: expectedInput,
            isOptional: true,
            abilityDefinition: ability,
            scatterSchoolProgress: progress,
            selectedAbilityEffect: .scatterSchool(count: 1),
            createdAtSequence: 2
        )
    }

    private func consumeFishFromHandPendingChoice(
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
            createdAtSequence: 2
        )
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
            createdAtSequence: 2
        )
    }

    private func compoundAbilityPendingChoice() -> PendingChoice {
        let sourceAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        let ability = AbilityDefinition(
            abilityId: "sample-fish-b-if-activated",
            trigger: .ifActivated,
            effects: [.placeEgg(count: 2), .hatchEgg(count: 1)],
            canResolveInAnyOrder: true,
            isOptional: true,
            displayText: "发动时：放置 2 个鱼卵，孵化 1 个鱼卵，可任选顺序"
        )
        return PendingChoice(
            choiceId: "choice-compound-fish-b",
            playerId: "player-1",
            source: .fishAbility("fish-31"),
            kind: .compoundAbility,
            options: [],
            expectedInput: .abilityEffectSelection,
            isOptional: true,
            abilityDefinition: ability,
            compoundAbilityProgress: CompoundAbilityProgress(
                abilityId: ability.abilityId,
                playerId: "player-1",
                sourceCardId: "fish-31",
                sourceAddress: sourceAddress,
                remainingEffects: ability.effects,
                completedEffects: [],
                canResolveInAnyOrder: true,
                isOptional: true
            ),
            createdAtSequence: 2
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

    private func oceanSlot(
        in viewModel: GameBoardViewModel,
        address: OceanSlotAddress,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> OceanSlotViewData {
        guard let slot = viewModel.oceanSlots.first(where: { $0.address == address }) else {
            XCTFail("Expected ocean slot.", file: file, line: line)
            return OceanSlotViewData(
                address: address,
                title: "",
                subtitle: "",
                resourcesText: "",
                cardFace: FishCardFaceViewState(
                    kind: .empty,
                    cardId: nil,
                    displayName: AppStrings.GameBoard.cardFaceEmptySlot,
                    scientificName: nil,
                    printedPointsText: "",
                    lengthText: "",
                    costText: AppStrings.GameBoard.noCost,
                    allowedZonesText: AppStrings.GameBoard.noLimit,
                    requiredDiveSiteColor: nil,
                    requiredDiveSiteText: AppStrings.GameBoard.noLimit,
                    tagsText: AppStrings.GameBoard.cardFaceNoTags,
                    abilityTriggerText: nil,
                    abilityText: AppStrings.GameBoard.cardFaceNoAbility,
                    costIcons: [FishCardFaceIconViewState(assetName: "NoCost", fallbackText: "-", accessibilityText: AppStrings.GameBoard.noCost)],
                    zoneIcons: [],
                    tagIcons: [],
                    sizeClassIcon: FishCardFaceIconViewState(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼"),
                    abilitySegments: FishCardAbilityTokenParser.parse(AppStrings.GameBoard.cardFaceNoAbility),
                    backgroundAssetPrefix: "base",
                    abilityStripAssetPrefix: nil,
                    abilityPanelStyle: .none,
                    localFishImagePrefix: nil,
                    aspectRatio: CardRenderMetrics.cardAspectRatio,
                    isPlaceholder: true
                ),
                isOccupied: false,
                isSelected: false,
                isHighlightedByDiveQueue: false,
                highlightReasonText: nil,
                playFishPreview: PlayFishSlotPreview(
                    availability: .unavailable,
                    unavailableReason: .noSelectedCard,
                    message: ""
                ),
                resourceTokens: [],
                aspectRatio: CardRenderMetrics.cardAspectRatio,
                isDropTarget: false,
                isValidDropTarget: false,
                dropTargetReasonText: nil,
                isHighlightedByRewardSelection: false,
                rewardSelectionReasonText: nil
            )
        }
        return slot
    }

    private func resourceToken(
        in viewModel: GameBoardViewModel,
        address: OceanSlotAddress,
        kind: ResourceKind,
        tokenIndex: Int = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SlotResourceTokenViewState {
        let slot = oceanSlot(in: viewModel, address: address, file: file, line: line)
        guard let token = slot.resourceTokens.first(where: { $0.kind == kind && $0.tokenIndex == tokenIndex }) else {
            XCTFail("Expected resource token.", file: file, line: line)
            return SlotResourceTokenViewState(
                address: address,
                kind: kind,
                tokenIndex: tokenIndex,
                title: "",
                iconText: "",
                isSelectable: false,
                isSelectedForPayment: false,
                selectionMarkerText: nil,
                unavailableReasonText: nil,
                warningText: nil
            )
        }
        return token
    }

    private func setContent(
        _ content: OceanSlotContent,
        at address: OceanSlotAddress,
        in service: CapturingRoomService
    ) {
        guard var playerState = service.gameState.playerGameStates[address.playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == address })
        else {
            return
        }

        playerState.ocean.slots[slotIndex].content = content
        service.gameState.playerGameStates[address.playerId] = playerState
        service.snapshot = RoomSnapshot(
            id: service.snapshot.id,
            players: service.snapshot.players,
            state: service.gameState,
            events: service.snapshot.events
        )
    }

    private func setConsumedFish(
        _ consumedFish: [ConsumedFish],
        at address: OceanSlotAddress,
        in service: CapturingRoomService
    ) {
        guard var playerState = service.gameState.playerGameStates[address.playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == address })
        else {
            return
        }

        playerState.ocean.slots[slotIndex].consumedFish = consumedFish
        service.gameState.playerGameStates[address.playerId] = playerState
        service.snapshot = RoomSnapshot(
            id: service.snapshot.id,
            players: service.snapshot.players,
            state: service.gameState,
            events: service.snapshot.events
        )
    }

    private func setActivatedGameEndAbilitySources(
        _ sourceIds: Set<String>,
        in service: CapturingRoomService
    ) {
        service.gameState.activatedGameEndAbilitySourceIds = sourceIds
        service.snapshot = RoomSnapshot(
            id: service.snapshot.id,
            players: service.snapshot.players,
            state: service.gameState,
            events: service.snapshot.events
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
                    id: "gameEnd.scoring",
                    name: "Scoring Game End Fish",
                    abilityIds: [BaseGameAbilityIDs.abyssalAnglerfishGameEnd],
                    abilityText: "游戏结束计分：若此鱼上没有任何标记，得 3 分",
                    printedPoints: 1,
                    lengthCm: 20
                ),
                Card(
                    id: "gameEnd.unsupported",
                    name: "Unsupported Game End Fish",
                    abilityIds: ["unsupported.test.gameEnd.card_999"],
                    abilityText: "游戏结束：未接入能力",
                    printedPoints: 1,
                    lengthCm: 22
                )
            ]
        )
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
                )
            ]
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

    private func playFishForFreeCatalog() -> TestCardCatalog {
        TestCardCatalog(
            fishCards: [
                Card(id: "free.small", name: "Free Small", printedPoints: 1, lengthCm: 10),
                Card(id: "free.medium", name: "Free Medium", printedPoints: 1, lengthCm: 80),
                Card(id: "free.sunlight", name: "Free Sunlight", allowedZones: [.sunlit], printedPoints: 2, lengthCm: 30)
            ]
        )
    }
}

@MainActor
private final class CapturingRoomService: RoomService {
    var gameRoom: GameRoom?
    var gameState: GameState
    var snapshot: RoomSnapshot
    var eventLog: [GameEvent] = []
    var submittedCommands: [PlayerCommand] = []
    var didResetLocalRoomSession = false

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    init(gameRoom: GameRoom, gameState: GameState, eventLog: [GameEvent] = []) {
        self.gameRoom = gameRoom
        self.gameState = gameState
        self.eventLog = eventLog
        self.snapshot = RoomSnapshot(
            id: gameRoom.roomId,
            players: gameRoom.players,
            state: gameState,
            events: []
        )
    }

    func submit(_ command: PlayerCommand) throws -> [GameEvent] {
        submittedCommands.append(command)
        return []
    }

    func resetLocalRoomSession() {
        didResetLocalRoomSession = true
        gameRoom = nil
        gameState = .empty
        snapshot = .empty
        eventLog = []
    }
}

private extension Array where Element == FishCardAbilitySegment {
    func containsRawToken(_ token: String) -> Bool {
        contains { segment in
            if case let .text(text) = segment {
                return text.contains("{\(token)}") || text.contains("[\(token)]")
            }
            return false
        }
    }

    func containsText(_ text: String) -> Bool {
        contains { segment in
            if case let .text(segmentText) = segment {
                return segmentText.contains(text)
            }
            return false
        }
    }

    var filterYoungFishIconCount: Int {
        filter { segment in
            if case let .icon(icon) = segment {
                return icon.assetName == "YoungFish"
            }
            return false
        }.count
    }
}

private struct TestCardCatalog: CardCatalog {
    var starterFishCards: [Card] = []
    var fishCards: [Card]
}

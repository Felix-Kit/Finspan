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

    func testHandViewStateUsesStackedPresentationByDefault() {
        let service = makeService(hand: ["starter-fish-1", "fish-2", "fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)
        let hand = viewModel.handViewState

        XCTAssertTrue(hand.isStackedPresentation)
        XCTAssertNil(hand.pulledOutCardId)
        XCTAssertEqual(hand.cards.map(\.stackIndex), [0, 1, 2])
        XCTAssertEqual(hand.cards.map(\.stackOffsetX), [0, 74, 148])
        XCTAssertEqual(hand.cards.map(\.stackOffsetY), [72, 72, 72])
        XCTAssertEqual(hand.cards.map(\.stackZIndex), [0, 1, 2])
        XCTAssertTrue(hand.cards.allSatisfy { !$0.isPulledOutFromStack })
        XCTAssertTrue(hand.cards.allSatisfy { $0.visibleHeightRatio == 0.48 })
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
    }

    func testSwitchingSelectedHandCardReturnsOldCardAndPullsOutNewCard() {
        let service = makeService(hand: ["starter-fish-1", "fish-2", "fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectHandCard("fish-2")
        viewModel.selectHandCard("fish-3")

        let cards = Dictionary(uniqueKeysWithValues: viewModel.handViewState.cards.map { ($0.cardId, $0) })
        XCTAssertEqual(viewModel.handViewState.pulledOutCardId, "fish-3")
        XCTAssertFalse(cards["fish-2"]?.isPulledOutFromStack ?? true)
        XCTAssertEqual(cards["fish-2"]?.stackOffsetY, 72)
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
        XCTAssertEqual(viewModel.handViewState.cards.map(\.stackOffsetY), [72, 72])
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

    func testDroppingHandCardOnLegalSlotSelectsTargetSlot() {
        let service = makeService(hand: ["fish-6"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("fish-6"))

        let dropTarget = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        XCTAssertTrue(dropTarget.isDropTarget)
        XCTAssertTrue(dropTarget.isValidDropTarget)
        XCTAssertEqual(dropTarget.dropTargetReasonText, AppStrings.GameBoard.dragToPlayHere)

        XCTAssertTrue(viewModel.dropHandCard(targetAddress: Self.forageTargetAddress))

        XCTAssertEqual(viewModel.selectedCardId, "fish-6")
        XCTAssertEqual(viewModel.selectedTargetSlot, Self.forageTargetAddress)
        XCTAssertNil(viewModel.draggingHandCardId)
    }

    func testDroppingHandCardOnIllegalSlotKeepsCardSelectedWithoutTarget() {
        let service = makeService(hand: ["starter-fish-1"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.beginDraggingHandCard("starter-fish-1"))

        let dropTarget = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        XCTAssertTrue(dropTarget.isDropTarget)
        XCTAssertFalse(dropTarget.isValidDropTarget)
        XCTAssertEqual(
            dropTarget.dropTargetReasonText,
            "\(AppStrings.GameBoard.slotCannotPlayHere)：\(AppStrings.GameBoard.cannotCoverLongerOrSameFish)"
        )

        XCTAssertFalse(viewModel.dropHandCard(targetAddress: Self.forageTargetAddress))

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

        let slot = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
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
        XCTAssertTrue(viewModel.oceanSlots.allSatisfy { $0.aspectRatio == 0.72 })
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
        viewModel.submitDive(to: .blue)

        XCTAssertTrue(viewModel.hasBlockingPendingChoices)
        XCTAssertFalse(viewModel.canSubmitPlayFish)
        XCTAssertFalse(viewModel.canDive)
        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.resolveCurrentRewardFirst)
    }

    func testNoAvailableDiversPreventsPlayFishAndDiveSubmission() {
        let service = makeService(hand: ["starter-fish-1"], availableDivers: 0)
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.submitPlayFish()
        viewModel.submitDive(to: .blue)

        XCTAssertFalse(viewModel.canSubmitPlayFish)
        XCTAssertFalse(viewModel.canDive)
        XCTAssertEqual(viewModel.diverAvailabilityWarning, AppStrings.GameBoard.diversUsedThisWeek)
        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.diversUsedThisWeek)
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
        XCTAssertEqual(AppStrings.phaseName(viewModel.state.phase), "游戏结束待结算")
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
            resourceSourceResources: []
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
        diveSitesReachedBottomThisWeek: Set<DiveActionSite> = [],
        weeklyAchievementResults: [WeeklyAchievementResult] = [],
        finalScoreResult: FinalScoreResult? = nil
    ) -> CapturingRoomService {
        var ocean = OceanState.baseGameInitial(for: "player-1")
        for emptySlot in emptySlots {
            if let targetIndex = ocean.slots.firstIndex(where: { $0.address == emptySlot }) {
                ocean.slots[targetIndex].content = .empty
            }
        }
        if let sourceIndex = ocean.slots.firstIndex(where: { $0.address == Self.resourceSourceAddress }) {
            ocean.slots[sourceIndex].resources = resourceSourceResources
        }
        ocean.slots.append(contentsOf: additionalSlots)

        return CapturingRoomService(
            gameRoom: GameRoom(
                roomId: "room-1",
                roomCode: "LOCAL",
                hostPlayerId: "player-1",
                players: [
                    RoomPlayer(
                        playerId: "player-1",
                        displayName: "玩家 1",
                        role: .host
                    )
                ],
                gameConfig: GameConfig(playerCount: 1, randomSeed: 1),
                createdAt: Date(timeIntervalSince1970: 1_000),
                updatedAt: Date(timeIntervalSince1970: 1_000)
            ),
            gameState: GameState(
                roomId: "room-1",
                players: [Player(id: "player-1", name: "玩家 1")],
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
            )
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
            return .unsupported
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
                aspectRatio: 0.72,
                isDropTarget: false,
                isValidDropTarget: false,
                dropTargetReasonText: nil
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
}

@MainActor
private final class CapturingRoomService: RoomService {
    var gameRoom: GameRoom?
    var gameState: GameState
    var snapshot: RoomSnapshot
    var eventLog: [GameEvent] = []
    var submittedCommands: [PlayerCommand] = []

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    init(gameRoom: GameRoom, gameState: GameState) {
        self.gameRoom = gameRoom
        self.gameState = gameState
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
}

private struct TestCardCatalog: CardCatalog {
    var starterFishCards: [Card] = []
    var fishCards: [Card]
}

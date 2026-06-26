import XCTest
@testable import Finspan

@MainActor
final class GameBoardAnimationTests: XCTestCase {
    func testSharedAnimationTimingIsLightweight() {
        XCTAssertEqual(GameBoardAnimation.Duration.quick, 0.16, accuracy: 0.001)
        XCTAssertEqual(GameBoardAnimation.Duration.standard, 0.24, accuracy: 0.001)
        XCTAssertEqual(GameBoardAnimation.Duration.slow, 0.34, accuracy: 0.001)
        XCTAssertGreaterThan(GameBoardAnimation.selectedHandCardScale, 1)
        XCTAssertGreaterThan(GameBoardAnimation.draggingHandCardScale, GameBoardAnimation.selectedHandCardScale)
        XCTAssertGreaterThan(GameBoardAnimation.dockSelectedTokenScale, 1)
        XCTAssertGreaterThan(GameBoardAnimation.invalidCardNudge, 0)
    }
}

@MainActor
final class HandInteractionPolishTests: XCTestCase {
    func testHandCardIdentityStaysStableAcrossSelectAndCancel() {
        let service = polishRoomService(hand: ["polish-a", "polish-b"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: BoardPolishCatalog()
        )
        let initialIds = viewModel.handViewState.cards.map(\.id)

        viewModel.selectHandCard("polish-a")

        XCTAssertEqual(viewModel.handViewState.cards.map(\.id), initialIds)
        XCTAssertEqual(viewModel.handViewState.pulledOutCardId, "polish-a")
        XCTAssertEqual(viewModel.handViewState.cards.first?.stackZIndex, 1_000)

        viewModel.selectHandCard("polish-a")

        XCTAssertEqual(viewModel.handViewState.cards.map(\.id), initialIds)
        XCTAssertNil(viewModel.handViewState.pulledOutCardId)
    }

    func testDragDropHighlightUsesPresentationStateOnly() throws {
        let service = polishRoomService(hand: ["polish-a"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: BoardPolishCatalog()
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)

        XCTAssertTrue(viewModel.beginDraggingHandCard("polish-a"))
        viewModel.updateDragTarget(target)

        let slot = try XCTUnwrap(viewModel.oceanSlots.first { $0.address == target })
        XCTAssertTrue(slot.isDropTarget)
        XCTAssertTrue(slot.isValidDropTarget)
        XCTAssertNil(viewModel.selectedTargetSlot)
    }
}

@MainActor
final class BottomRewardDockPolishTests: XCTestCase {
    func testDockTokenIdentityStaysStableWhenSelectionChanges() {
        let unselected = dockToken(id: "reward-egg", isSelected: false)
        let selected = dockToken(id: "reward-egg", isSelected: true)

        XCTAssertEqual(unselected.id, selected.id)
        XCTAssertEqual(unselected.action, selected.action)
        XCTAssertFalse(unselected.isSelected)
        XCTAssertTrue(selected.isSelected)
    }

    func testDockControlsAreNotInformationalDockContent() {
        let state = BottomRewardDockState(
            displayMode: .hidden,
            title: AppStrings.GameBoard.playFishPayment,
            sourceText: nil,
            instructionText: AppStrings.GameBoard.playFishFromHandPayment,
            summaryLines: [],
            tokens: [],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: nil,
            backControl: nil
        )

        XCTAssertFalse(state.usesMainBoardRightPanel)
        XCTAssertFalse(state.hasInformationalContent)
        XCTAssertEqual(state.displayMode, .hidden)
    }
}

@MainActor
final class BottomDockOverlayPolishTests: XCTestCase {
    func testOverlayRouteHasStablePresentationIdentityAndNoRightPanel() {
        let overlay = BottomDockOverlayState(
            route: .handCardPicker,
            title: AppStrings.GameBoard.currentAction,
            instructionText: AppStrings.GameBoard.chooseOption,
            handCards: [],
            debugText: nil
        )

        XCTAssertEqual(overlay.route.rawValue, "handCardPicker")
        XCTAssertFalse(overlay.usesMainBoardRightPanel)
    }
}

private func dockToken(id: String, isSelected: Bool) -> BottomRewardDockToken {
    BottomRewardDockToken(
        id: id,
        title: "放置鱼卵",
        subtitle: "选择目标",
        icon: GameTokenIconResolver.shared.icon(for: .egg),
        countText: nil,
        isSelectable: true,
        isSelected: isSelected,
        isCompleted: false,
        isUnsupported: false,
        fallbackReason: nil,
        continuationSurfaces: [.boardTarget],
        action: .selectRewardToken(id)
    )
}

@MainActor
private func polishRoomService(hand: [CardID]) -> WeeklyDisplayRoomService {
    let service = WeeklyDisplayRoomService()
    var playerState = service.gameState.playerGameStates["player-1"]!
    playerState.hand = hand
    service.gameState.playerGameStates["player-1"] = playerState
    service.snapshot.state = service.gameState
    return service
}

private struct BoardPolishCatalog: CardCatalog {
    let starterFishCards: [Card] = []
    let fishCards: [Card] = [
        Card(
            id: "polish-a",
            name: "Polish A",
            costs: [],
            allowedZones: [.sunlit],
            printedPoints: 1,
            lengthCm: 12
        ),
        Card(
            id: "polish-b",
            name: "Polish B",
            costs: [],
            allowedZones: [.sunlit],
            printedPoints: 1,
            lengthCm: 13
        )
    ]
}

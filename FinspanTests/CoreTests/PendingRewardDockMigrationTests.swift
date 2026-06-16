import XCTest
@testable import Finspan

final class PendingRewardDockMigrationTests: XCTestCase {
    func testRecoverFromDiscardOrDrawOpensDiscardOverlayFromDock() {
        let token = pendingToken(
            id: "recover",
            continuation: [.discardOverlay, .directCommit],
            fallbackReason: AppStrings.GameBoard.chooseDiscardCardToRecover
        )

        XCTAssertEqual(token.continuationSurfaces, [.discardOverlay, .directCommit])
        XCTAssertEqual(token.fallbackReason, AppStrings.GameBoard.chooseDiscardCardToRecover)
    }

    func testConsumeFishFromHandOpensHandPickerFromDock() {
        let token = pendingToken(
            id: "consume",
            continuation: [.handPicker, .boardTarget, .fallbackPanel],
            fallbackReason: AppStrings.GameBoard.consumeFishHandCard
        )

        XCTAssertEqual(token.continuationSurfaces, [.handPicker, .boardTarget, .fallbackPanel])
    }

    func testPlayFishAbilityOpensHandPickerAndStagedPlayFishFlowFromDock() {
        let freePlay = pendingToken(
            id: "freePlay",
            continuation: [.handPicker, .playFishFlow, .fallbackPanel],
            fallbackReason: AppStrings.GameBoard.playFishForFreeHandCard
        )
        let paidPlay = pendingToken(
            id: "paidPlay",
            continuation: [.handPicker, .playFishFlow, .paymentFlow, .fallbackPanel],
            fallbackReason: AppStrings.GameBoard.playFishFromHandHandCard
        )

        XCTAssertEqual(freePlay.continuationSurfaces, [.handPicker, .playFishFlow, .fallbackPanel])
        XCTAssertEqual(paidPlay.continuationSurfaces, [.handPicker, .playFishFlow, .paymentFlow, .fallbackPanel])
    }

    func testDiveRewardWithoutBoardMarkerAppearsInDock() {
        let state = BottomRewardDockState(
            displayMode: .compact,
            title: AppStrings.GameBoard.currentRewards,
            sourceText: AppStrings.GameBoard.triggeringFirstBottomBonus,
            instructionText: AppStrings.GameBoard.chooseRewardToken,
            summaryLines: [],
            tokens: [pendingToken(id: "dive", continuation: [.reefTarget, .fallbackPanel])],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: nil,
            backControl: nil
        )

        XCTAssertEqual(state.sourceText, AppStrings.GameBoard.triggeringFirstBottomBonus)
        XCTAssertEqual(state.tokens.first?.continuationSurfaces, [.reefTarget, .fallbackPanel])
    }

    private func pendingToken(
        id: String,
        continuation: [ContinuationSurface],
        fallbackReason: String? = nil
    ) -> BottomRewardDockToken {
        BottomRewardDockToken(
            id: id,
            title: id,
            subtitle: id,
            icon: GameTokenIconResolver.shared.icon(for: .draw),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: fallbackReason,
            continuationSurfaces: continuation,
            action: .selectRewardToken(id)
        )
    }
}

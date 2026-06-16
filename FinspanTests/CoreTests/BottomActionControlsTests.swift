import XCTest
@testable import Finspan

final class BottomActionControlsTests: XCTestCase {
    func testForwardControlCanRepresentConfirmSkipAndFinish() {
        let confirm = BottomRewardDockControl(
            title: "→ 确认出牌",
            action: .primary,
            isEnabled: true,
            accessibilityLabel: AppStrings.GameBoard.confirmPlayFish
        )
        let finish = BottomRewardDockControl(
            title: "→ 进入最终计分",
            action: .finishGameEndAbilities,
            isEnabled: false,
            accessibilityLabel: AppStrings.GameBoard.finishGameEndAbilities
        )

        XCTAssertEqual(confirm.action, .primary)
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertEqual(finish.action, .finishGameEndAbilities)
        XCTAssertFalse(finish.isEnabled)
    }

    func testBackControlRepresentsStagedUndoOnly() {
        let back = BottomRewardDockControl(
            title: "←",
            action: .back,
            isEnabled: true,
            accessibilityLabel: AppStrings.GameBoard.cancel
        )

        XCTAssertEqual(back.action, .back)
        XCTAssertNotEqual(back.action, .primary)
    }

    func testFallbackIsOpenedFromDockAction() {
        let token = BottomRewardDockToken(
            id: "recover",
            title: AppStrings.GameBoard.recoverFromDiscardOrDraw,
            subtitle: AppStrings.GameBoard.discardPile,
            icon: GameTokenIconResolver.shared.icon(for: .draw),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: AppStrings.GameBoard.chooseDiscardCardToRecover,
            continuationSurfaces: [.discardOverlay, .directCommit],
            action: .selectRewardToken("recover")
        )

        XCTAssertEqual(token.fallbackReason, AppStrings.GameBoard.chooseDiscardCardToRecover)
        XCTAssertEqual(token.continuationSurfaces, [.discardOverlay, .directCommit])
        XCTAssertEqual(token.action, .selectRewardToken("recover"))
    }
}

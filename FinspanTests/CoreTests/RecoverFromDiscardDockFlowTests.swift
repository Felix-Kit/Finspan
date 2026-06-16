import XCTest
@testable import Finspan

final class RecoverFromDiscardDockFlowTests: XCTestCase {
    func testRecoverTokenOpensDiscardOverlayWhenDiscardTargetsExist() {
        let token = recoverToken(
            continuation: [.discardOverlay, .directCommit],
            fallbackReason: AppStrings.GameBoard.chooseDiscardCardToRecover
        )
        let overlay = BottomDockOverlayState(
            route: .discardPileSelection,
            title: AppStrings.GameBoard.recoverFromDiscardOrDraw,
            instructionText: AppStrings.GameBoard.chooseDiscardCardToRecover,
            handCards: [],
            debugText: nil
        )

        XCTAssertEqual(token.action, .selectRewardToken("recover"))
        XCTAssertEqual(token.continuationSurfaces, [.discardOverlay, .directCommit])
        XCTAssertEqual(overlay.route, .discardPileSelection)
        XCTAssertFalse(overlay.usesMainBoardRightPanel)
    }

    func testRecoverEmptyDiscardFallsBackToDrawDirectCommit() {
        let token = recoverToken(
            continuation: [.directCommit],
            fallbackReason: AppStrings.GameBoard.discardPileEmptyDrawAlternative
        )

        XCTAssertEqual(token.continuationSurfaces, [.directCommit])
        XCTAssertEqual(token.fallbackReason, AppStrings.GameBoard.discardPileEmptyDrawAlternative)
        XCTAssertEqual(token.action, .selectRewardToken("recover"))
    }

    func testDrawInsteadResolvesThroughExistingDockTokenPath() {
        let token = recoverToken(
            continuation: [.discardOverlay, .directCommit],
            fallbackReason: AppStrings.GameBoard.drawInstead
        )

        XCTAssertEqual(token.action, .selectRewardToken("recover"))
        XCTAssertTrue(token.continuationSurfaces.contains(.directCommit))
        XCTAssertFalse(token.usesUnsupportedFallback)
    }

    private func recoverToken(
        continuation: [ContinuationSurface],
        fallbackReason: String?
    ) -> BottomRewardDockToken {
        BottomRewardDockToken(
            id: "recover",
            title: AppStrings.GameBoard.recoverFromDiscardOrDraw,
            subtitle: AppStrings.GameBoard.discardPile,
            icon: GameTokenIconResolver.shared.icon(for: .draw),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: fallbackReason,
            continuationSurfaces: continuation,
            action: .selectRewardToken("recover")
        )
    }
}

private extension BottomRewardDockToken {
    var usesUnsupportedFallback: Bool {
        isUnsupported || continuationSurfaces == [.fallbackPanel]
    }
}

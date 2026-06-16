import XCTest
@testable import Finspan

final class BottomRewardDockFallbackFlowTests: XCTestCase {
    func testDockCanOpenDebugFallbackWithoutRightPanel() {
        let state = BottomRewardDockState(
            displayMode: .expanded,
            title: AppStrings.GameBoard.currentAction,
            sourceText: nil,
            instructionText: AppStrings.GameBoard.chooseOption,
            summaryLines: [],
            tokens: [],
            warningText: nil,
            fallbackReason: AppStrings.GameBoard.chooseOption,
            forwardControl: BottomRewardDockControl(
                title: "→",
                action: .openFallbackOverlay,
                isEnabled: true,
                accessibilityLabel: AppStrings.GameBoard.chooseOption
            ),
            backControl: nil
        )

        XCTAssertEqual(state.forwardControl?.action, .openFallbackOverlay)
        XCTAssertFalse(state.usesMainBoardRightPanel)
    }

    func testOverlayCancelIsPresentationOnly() {
        let overlay = BottomDockOverlayState(
            route: .debugFallback,
            title: AppStrings.GameBoard.currentAction,
            instructionText: AppStrings.GameBoard.chooseOption,
            handCards: [],
            debugText: AppStrings.GameBoard.chooseOption
        )

        XCTAssertEqual(overlay.route, .debugFallback)
        XCTAssertTrue(overlay.handCards.isEmpty)
        XCTAssertFalse(overlay.usesMainBoardRightPanel)
    }
}

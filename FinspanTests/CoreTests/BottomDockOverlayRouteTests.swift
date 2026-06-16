import XCTest
@testable import Finspan

final class BottomDockOverlayRouteTests: XCTestCase {
    func testOverlayRoutesCoverDockFallbackContinuations() {
        XCTAssertEqual(BottomDockOverlayRoute.discardPileSelection.rawValue, "discardPileSelection")
        XCTAssertEqual(BottomDockOverlayRoute.handCardPicker.rawValue, "handCardPicker")
        XCTAssertEqual(BottomDockOverlayRoute.playFishStaging.rawValue, "playFishStaging")
        XCTAssertEqual(BottomDockOverlayRoute.reefTargetPicker.rawValue, "reefTargetPicker")
        XCTAssertEqual(BottomDockOverlayRoute.debugFallback.rawValue, "debugFallback")
        XCTAssertEqual(BottomDockOverlayRoute.gameEndCandidate.rawValue, "gameEndCandidate")
    }

    func testOverlayStateDoesNotUseMainBoardRightPanel() {
        let state = BottomDockOverlayState(
            route: .handCardPicker,
            title: AppStrings.GameBoard.playFishFromHand,
            instructionText: AppStrings.GameBoard.playFishFromHandHandCard,
            handCards: [],
            debugText: nil
        )

        XCTAssertFalse(state.usesMainBoardRightPanel)
    }
}

import XCTest
@testable import Finspan

final class PlayFishBottomDockConfirmTests: XCTestCase {
    func testPlayFishStagedConfirmIsNotModeledAsDockOnlyContent() {
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

        XCTAssertEqual(state.title, AppStrings.GameBoard.playFishPayment)
        XCTAssertEqual(state.displayMode, .hidden)
        XCTAssertNil(state.forwardControl)
        XCTAssertNil(state.backControl)
        XCTAssertFalse(state.hasInformationalContent)
        XCTAssertFalse(state.usesMainBoardRightPanel)
    }

    func testPlayFishStagedCancelUsesFloatingActionBackControl() {
        let state = FloatingActionPairState(
            leading: FloatingActionButtonState(
                id: "playFish-back",
                title: "←",
                action: .back,
                isEnabled: true,
                accessibilityLabel: AppStrings.GameBoard.cancelPlayFish
            ),
            trailing: FloatingActionButtonState(
                id: "playFish-forward",
                title: "→",
                action: .primary,
                isEnabled: true,
                accessibilityLabel: AppStrings.GameBoard.confirmPlayFish
            ),
            context: .playFish
        )

        XCTAssertEqual(state.leading?.action, .back)
        XCTAssertEqual(state.trailing?.action, .primary)
        XCTAssertTrue(state.leading?.isEnabled == true)
        XCTAssertTrue(state.avoidsHomeIndicator)
        XCTAssertTrue(state.avoidsHandArea)
        XCTAssertFalse(state.usesMainBoardRightPanel)
    }
}

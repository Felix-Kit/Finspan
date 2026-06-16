import XCTest
@testable import Finspan

final class PlayFishBottomDockConfirmTests: XCTestCase {
    func testPlayFishStagedConfirmUsesBottomDockForwardControl() {
        let state = BottomRewardDockState(
            displayMode: .compact,
            title: AppStrings.GameBoard.playFishPayment,
            sourceText: "蓝鳍金枪鱼",
            instructionText: AppStrings.GameBoard.playFishFromHandPayment,
            summaryLines: [
                "鱼牌：蓝鳍金枪鱼",
                "目标：蓝色潜水点第 1 格"
            ],
            tokens: [],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: BottomRewardDockControl(
                title: "→ \(AppStrings.GameBoard.confirmPlayFish)",
                action: .primary,
                isEnabled: true,
                accessibilityLabel: AppStrings.GameBoard.confirmPlayFish
            ),
            backControl: BottomRewardDockControl(
                title: "←",
                action: .back,
                isEnabled: true,
                accessibilityLabel: AppStrings.GameBoard.cancelPlayFish
            )
        )

        XCTAssertEqual(state.title, AppStrings.GameBoard.playFishPayment)
        XCTAssertEqual(state.forwardControl?.action, .primary)
        XCTAssertTrue(state.forwardControl?.isEnabled == true)
        XCTAssertEqual(state.forwardControl?.accessibilityLabel, AppStrings.GameBoard.confirmPlayFish)
        XCTAssertFalse(state.usesMainBoardRightPanel)
    }

    func testPlayFishStagedCancelUsesBottomDockBackControl() {
        let state = BottomRewardDockState(
            displayMode: .compact,
            title: AppStrings.GameBoard.playFishPayment,
            sourceText: "蓝鳍金枪鱼",
            instructionText: AppStrings.GameBoard.playFishFromHandPayment,
            summaryLines: [],
            tokens: [],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: nil,
            backControl: BottomRewardDockControl(
                title: "←",
                action: .back,
                isEnabled: true,
                accessibilityLabel: AppStrings.GameBoard.cancelPlayFish
            )
        )

        XCTAssertEqual(state.backControl?.action, .back)
        XCTAssertTrue(state.backControl?.isEnabled == true)
        XCTAssertNotEqual(state.backControl?.action, .finishGameEndAbilities)
    }
}

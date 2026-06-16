import XCTest
@testable import Finspan

final class PlayFishAbilityDockFlowTests: XCTestCase {
    func testPlayFishForFreeTokenOpensHandPickerThenStagedPlayFishWithoutPayment() {
        let token = playToken(
            id: "free-play",
            title: AppStrings.GameBoard.playFishForFree,
            subtitle: AppStrings.GameBoard.playFishForFreeHandCard,
            continuation: [.handPicker, .playFishFlow, .fallbackPanel]
        )
        let overlay = BottomDockOverlayState(
            route: .handCardPicker,
            title: AppStrings.GameBoard.playFishForFree,
            instructionText: AppStrings.GameBoard.playFishForFreeHandCard,
            handCards: [],
            debugText: nil
        )

        XCTAssertEqual(token.continuationSurfaces, [.handPicker, .playFishFlow, .fallbackPanel])
        XCTAssertFalse(token.continuationSurfaces.contains(.paymentFlow))
        XCTAssertEqual(overlay.route, .handCardPicker)
    }

    func testPlayFishFromHandPaidFlowCanEnterPaymentSelection() {
        let token = playToken(
            id: "paid-play",
            title: AppStrings.GameBoard.playFishFromHand,
            subtitle: AppStrings.GameBoard.playFishFromHandHandCard,
            continuation: [.handPicker, .playFishFlow, .paymentFlow, .fallbackPanel]
        )
        let overlay = BottomDockOverlayState(
            route: .playFishStaging,
            title: AppStrings.GameBoard.playFishFromHand,
            instructionText: AppStrings.GameBoard.playFishFromHandPayment,
            handCards: [],
            debugText: nil
        )

        XCTAssertTrue(token.continuationSurfaces.contains(.paymentFlow))
        XCTAssertEqual(overlay.route, .playFishStaging)
        XCTAssertEqual(overlay.instructionText, AppStrings.GameBoard.playFishFromHandPayment)
        XCTAssertFalse(overlay.usesMainBoardRightPanel)
    }

    func testStagedPlayFishConfirmAndCancelUseDockControls() {
        let state = BottomRewardDockState(
            displayMode: .compact,
            title: AppStrings.GameBoard.playFishPayment,
            sourceText: "Bluefin Tuna",
            instructionText: AppStrings.GameBoard.playFishFromHandPayment,
            summaryLines: [],
            tokens: [],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: BottomRewardDockControl(
                title: "→",
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

        XCTAssertEqual(state.forwardControl?.action, .primary)
        XCTAssertEqual(state.backControl?.action, .back)
        XCTAssertFalse(state.usesMainBoardRightPanel)
    }

    private func playToken(
        id: String,
        title: String,
        subtitle: String,
        continuation: [ContinuationSurface]
    ) -> BottomRewardDockToken {
        BottomRewardDockToken(
            id: id,
            title: title,
            subtitle: subtitle,
            icon: GameTokenIconResolver.shared.icon(for: .fish),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: nil,
            continuationSurfaces: continuation,
            action: .selectRewardToken(id)
        )
    }
}

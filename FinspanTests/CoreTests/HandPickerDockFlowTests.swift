import XCTest
@testable import Finspan

final class HandPickerDockFlowTests: XCTestCase {
    func testConsumeFishFromHandTokenOpensHandPicker() {
        let token = consumeToken()
        let overlay = BottomDockOverlayState(
            route: .handCardPicker,
            title: AppStrings.GameBoard.consumeFishFromHand,
            instructionText: AppStrings.GameBoard.consumeFishHandCard,
            handCards: [],
            debugText: nil
        )

        XCTAssertEqual(token.action, .selectRewardToken("consume"))
        XCTAssertEqual(token.continuationSurfaces, [.handPicker, .boardTarget, .fallbackPanel])
        XCTAssertEqual(overlay.route, .handCardPicker)
        XCTAssertEqual(overlay.instructionText, AppStrings.GameBoard.consumeFishHandCard)
        XCTAssertFalse(overlay.usesMainBoardRightPanel)
    }

    func testConsumeFishFromHandCanContinueFromHandPickerToBoardTarget() {
        let task = BoardCardInteractionTask(
            id: "consume",
            source: .pendingEffectNode(choiceId: "choice-consume", nodeId: "consume"),
            taxonomy: BoardCardInteractionTaxonomy(
                inlineEntrySurfaces: [.incomingRewardDock],
                continuationSurfaces: [.handPicker, .boardTarget, .fallbackPanel],
                commitReversibility: .stagedOnlyUndo,
                sourceVisibility: .externalPendingReward,
                requiresFallback: true,
                requiresOverlay: true,
                canStartInline: true
            ),
            steps: [
                BoardCardInteractionStep(
                    id: "hand",
                    kind: .chooseHandCard,
                    tokens: [interactionToken(id: "consume", kind: .consume, state: .selected)],
                    sources: [
                        BoardCardInteractionSourceOption(
                            id: "hand-fish",
                            kind: .handCard("base.main.002"),
                            state: .selected,
                            satisfiesTokenIds: ["consume"]
                        )
                    ],
                    targets: [],
                    state: .selected
                ),
                BoardCardInteractionStep(
                    id: "consumer",
                    kind: .chooseTargetFish,
                    tokens: [],
                    sources: [],
                    targets: [
                        BoardCardInteractionTarget(
                            id: "consumer-slot",
                            kind: .fish(OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)),
                            state: .available
                        )
                    ],
                    state: .available
                )
            ],
            controls: BoardCardInteractionControlState(
                forward: BoardCardInteractionControl(visibility: .hidden, action: nil, isEnabled: false),
                back: BoardCardInteractionControl(visibility: .visible, action: .stagedUndo, isEnabled: true),
                fallbackPanelVisible: false,
                compactHintText: nil
            ),
            hintText: nil
        )

        XCTAssertEqual(task.steps.map(\.kind), [.chooseHandCard, .chooseTargetFish])
        XCTAssertEqual(task.steps.first?.sources.first?.kind, .handCard("base.main.002"))
        XCTAssertEqual(task.controls.back.action, .stagedUndo)
    }

    private func consumeToken() -> BottomRewardDockToken {
        BottomRewardDockToken(
            id: "consume",
            title: AppStrings.GameBoard.consumeFishFromHand,
            subtitle: AppStrings.GameBoard.consumeFishHandCard,
            icon: GameTokenIconResolver.shared.icon(for: .consume),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: nil,
            continuationSurfaces: [.handPicker, .boardTarget, .fallbackPanel],
            action: .selectRewardToken("consume")
        )
    }

    private func interactionToken(
        id: String,
        kind: BoardCardInteractionTokenKind,
        state: BoardCardInteractionSelectionState
    ) -> BoardCardInteractionToken {
        BoardCardInteractionToken(
            id: id,
            kind: kind,
            role: .reward,
            state: state,
            count: 1,
            title: id
        )
    }
}

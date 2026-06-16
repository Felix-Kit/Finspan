import XCTest
@testable import Finspan

final class AllPlayersDockFlowTests: XCTestCase {
    func testTargetPlayerSeesExternalSourceSummaryInDock() {
        let dock = IncomingRewardDockState(
            id: "all-players-target",
            sourceSummary: IncomingRewardDockSourceSummary(
                sourcePlayerId: "player-2",
                sourcePlayerName: "玩家二",
                sourcePlayerColorName: "紫色",
                sourceFishName: "Giant Hatchetfish",
                sourceCardId: "base.main.050",
                triggerText: "所有玩家",
                sourceVisibility: .externalPendingReward
            ),
            tokens: [
                IncomingRewardDockToken(
                    id: "draw",
                    kind: .draw,
                    icon: GameTokenIconResolver.shared.icon(for: .draw),
                    title: AppStrings.GameBoard.drawFish,
                    state: .available,
                    continuationSurfaces: [.directCommit],
                    action: .selectRewardToken("draw"),
                    fallbackReason: nil
                )
            ],
            controls: BoardCardInteractionControlState(
                forward: BoardCardInteractionControl(
                    visibility: .visible,
                    action: .skipCurrentEffect(choiceId: "target-player-choice"),
                    isEnabled: true
                ),
                back: BoardCardInteractionControl(
                    visibility: .visible,
                    action: .stagedUndo,
                    isEnabled: true
                ),
                fallbackPanelVisible: false,
                compactHintText: nil
            ),
            fallbackReason: nil,
            isVisible: true
        )

        XCTAssertEqual(dock.sourceSummary.sourcePlayerId, "player-2")
        XCTAssertEqual(dock.sourceSummary.sourceVisibility, .externalPendingReward)
        XCTAssertEqual(dock.tokens.first?.continuationSurfaces, [.directCommit])
        XCTAssertTrue(dock.isVisible)
    }

    func testTargetPlayerSkipDoesNotRepresentOtherPlayersSkip() {
        let targetPlayerChoice = BoardCardInteractionControl(
            visibility: .visible,
            action: .skipCurrentEffect(choiceId: "choice-player-1"),
            isEnabled: true
        )
        let otherPlayerChoice = BoardCardInteractionControl(
            visibility: .visible,
            action: .skipCurrentEffect(choiceId: "choice-player-2"),
            isEnabled: true
        )

        XCTAssertNotEqual(targetPlayerChoice.action, otherPlayerChoice.action)
        XCTAssertEqual(targetPlayerChoice.action, .skipCurrentEffect(choiceId: "choice-player-1"))
    }
}

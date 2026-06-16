import XCTest
@testable import Finspan

final class IncomingRewardDockTests: XCTestCase {
    private let choiceId: PendingChoiceID = "choice-all-players-target"

    func testDockRepresentsExternalAllPlayersRewardEntry() {
        let dock = incomingDock(
            sourceVisibility: .externalPendingReward,
            tokens: [
                dockToken(
                    id: "draw",
                    kind: .draw,
                    continuation: [.directCommit],
                    action: .selectRewardToken("draw")
                )
            ]
        )

        XCTAssertTrue(dock.isVisible)
        XCTAssertEqual(dock.sourceSummary.sourcePlayerId, "opponent-1")
        XCTAssertEqual(dock.sourceSummary.sourceCardId, "base.main.050")
        XCTAssertEqual(dock.sourceSummary.sourceVisibility, .externalPendingReward)
        XCTAssertEqual(dock.tokens.first?.continuationSurfaces, [.directCommit])
        XCTAssertEqual(dock.tokens.first?.action, .selectRewardToken("draw"))
    }

    func testDockCanCarryFallbackReasonForPickerContinuation() {
        let dock = incomingDock(
            fallbackReason: "需要手牌选择器",
            tokens: [
                dockToken(
                    id: "consume",
                    kind: .consume,
                    continuation: [.handPicker, .boardTarget, .fallbackPanel],
                    action: .showFallback,
                    fallbackReason: "需要手牌选择器"
                )
            ]
        )

        XCTAssertEqual(dock.fallbackReason, "需要手牌选择器")
        XCTAssertEqual(dock.tokens.first?.continuationSurfaces, [.handPicker, .boardTarget, .fallbackPanel])
        XCTAssertEqual(dock.tokens.first?.fallbackReason, "需要手牌选择器")
        XCTAssertEqual(dock.tokens.first?.action, .showFallback)
    }

    func testTargetPlayerSkipAndUndoAreScopedToOwnPendingReward() {
        let controls = BoardCardInteractionControlState(
            forward: BoardCardInteractionControl(visibility: .visible, action: .skipCurrentEffect(choiceId: choiceId), isEnabled: true),
            back: BoardCardInteractionControl(visibility: .visible, action: .stagedUndo, isEnabled: true),
            fallbackPanelVisible: false,
            compactHintText: nil
        )
        let dock = incomingDock(tokens: [], controls: controls)

        XCTAssertEqual(dock.controls.forward.action, .skipCurrentEffect(choiceId: choiceId))
        XCTAssertEqual(dock.controls.back.action, .stagedUndo)
        XCTAssertFalse(dock.controls.fallbackPanelVisible)
    }

    private func incomingDock(
        sourceVisibility: SourceVisibility = .externalPendingReward,
        fallbackReason: String? = nil,
        tokens: [IncomingRewardDockToken],
        controls: BoardCardInteractionControlState? = nil
    ) -> IncomingRewardDockState {
        IncomingRewardDockState(
            id: "incoming-all-players",
            sourceSummary: IncomingRewardDockSourceSummary(
                sourcePlayerId: "opponent-1",
                sourcePlayerName: "玩家二",
                sourcePlayerColorName: "紫色",
                sourceFishName: "Giant Hatchetfish",
                sourceCardId: "base.main.050",
                triggerText: "所有玩家",
                sourceVisibility: sourceVisibility
            ),
            tokens: tokens,
            controls: controls ?? BoardCardInteractionControlState(
                forward: BoardCardInteractionControl(visibility: .visible, action: .skipCurrentEffect(choiceId: choiceId), isEnabled: true),
                back: BoardCardInteractionControl(visibility: .visible, action: .stagedUndo, isEnabled: true),
                fallbackPanelVisible: fallbackReason != nil,
                compactHintText: fallbackReason
            ),
            fallbackReason: fallbackReason,
            isVisible: true
        )
    }

    private func dockToken(
        id: String,
        kind: BoardCardInteractionTokenKind,
        continuation: [ContinuationSurface],
        action: IncomingRewardDockAction,
        fallbackReason: String? = nil
    ) -> IncomingRewardDockToken {
        IncomingRewardDockToken(
            id: id,
            kind: kind,
            icon: GameTokenIconResolver.shared.icon(for: .draw),
            title: id,
            state: .available,
            continuationSurfaces: continuation,
            action: action,
            fallbackReason: fallbackReason
        )
    }
}

import XCTest
@testable import Finspan

final class BottomRewardDockTests: XCTestCase {
    func testDockSupportsRequiredDisplayModes() {
        XCTAssertEqual(BottomRewardDockDisplayMode.hidden.rawValue, "hidden")
        XCTAssertEqual(BottomRewardDockDisplayMode.handleOnly.rawValue, "handleOnly")
        XCTAssertEqual(BottomRewardDockDisplayMode.compact.rawValue, "compact")
        XCTAssertEqual(BottomRewardDockDisplayMode.expanded.rawValue, "expanded")
    }

    func testPendingRewardTokenListAppearsInBottomRewardDock() {
        let state = dock(tokens: [
            token(id: "egg", title: "放置鱼卵", action: .selectRewardToken("egg"))
        ])

        XCTAssertEqual(state.displayMode, .compact)
        XCTAssertEqual(state.tokens.map(\.id), ["egg"])
        XCTAssertEqual(state.tokens.first?.action, .selectRewardToken("egg"))
        XCTAssertFalse(state.usesMainBoardRightPanel)
    }

    func testSimpleRewardsCanStartFromDock() {
        let tokens = [
            token(id: "placeEgg", title: "放置鱼卵", continuation: [.boardTarget]),
            token(id: "hatchEgg", title: "孵化鱼卵", continuation: [.boardTarget]),
            token(id: "gainCoral", title: "获得珊瑚", continuation: [.reefTarget, .fallbackPanel])
        ]
        let state = dock(tokens: tokens)

        XCTAssertEqual(state.tokens[0].continuationSurfaces, [.boardTarget])
        XCTAssertEqual(state.tokens[1].continuationSurfaces, [.boardTarget])
        XCTAssertEqual(state.tokens[2].continuationSurfaces, [.reefTarget, .fallbackPanel])
    }

    func testExternalAllPlayersTargetRewardAppearsInDock() {
        let state = dock(
            sourceText: "玩家二 · Giant Hatchetfish · 所有玩家",
            tokens: [
                token(id: "allPlayersDraw", title: "抽鱼牌", continuation: [.directCommit])
            ]
        )

        XCTAssertEqual(state.sourceText, "玩家二 · Giant Hatchetfish · 所有玩家")
        XCTAssertEqual(state.tokens.first?.continuationSurfaces, [.directCommit])
    }

    func testGameEndCandidateAppearsInDockAsDirectCommitToken() {
        let source = GameEndAbilitySource(
            playerId: "player-1",
            slotAddress: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            cardId: "base.main.001",
            abilityId: "game-end-score"
        )
        let state = dock(tokens: [
            BottomRewardDockToken(
                id: source.id,
                title: "可发动终局能力",
                subtitle: "直接结算或选择目标",
                icon: GameTokenIconResolver.shared.icon(for: .wave),
                countText: nil,
                isSelectable: true,
                isSelected: false,
                isCompleted: false,
                isUnsupported: false,
                fallbackReason: nil,
                continuationSurfaces: [.directCommit],
                action: .activateGameEndAbility(source)
            )
        ])

        XCTAssertEqual(state.tokens.first?.continuationSurfaces, [.directCommit])
        XCTAssertEqual(state.tokens.first?.action, .activateGameEndAbility(source))
    }

    private func dock(
        sourceText: String? = nil,
        tokens: [BottomRewardDockToken]
    ) -> BottomRewardDockState {
        BottomRewardDockState(
            displayMode: .compact,
            title: AppStrings.GameBoard.currentRewards,
            sourceText: sourceText,
            instructionText: AppStrings.GameBoard.chooseRewardToken,
            summaryLines: [],
            tokens: tokens,
            warningText: nil,
            fallbackReason: nil,
            forwardControl: nil,
            backControl: nil
        )
    }

    private func token(
        id: String,
        title: String,
        continuation: [ContinuationSurface] = [.boardTarget],
        action: BottomRewardDockAction? = nil
    ) -> BottomRewardDockToken {
        BottomRewardDockToken(
            id: id,
            title: title,
            subtitle: title,
            icon: GameTokenIconResolver.shared.icon(for: .egg),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: nil,
            continuationSurfaces: continuation,
            action: action ?? .selectRewardToken(id)
        )
    }
}

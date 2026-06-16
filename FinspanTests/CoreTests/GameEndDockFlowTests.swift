import XCTest
@testable import Finspan

final class GameEndDockFlowTests: XCTestCase {
    func testGameEndCandidateAppearsInDock() {
        let source = gameEndSource()
        let token = BottomRewardDockToken(
            id: source.id,
            title: AppStrings.GameBoard.gameEndAbilityPhaseTitle,
            subtitle: AppStrings.GameBoard.gameEndAbilityAvailable,
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
        let state = BottomRewardDockState(
            displayMode: .compact,
            title: AppStrings.GameBoard.gameEndAbilityPhaseTitle,
            sourceText: "Bluefin Tuna",
            instructionText: AppStrings.GameBoard.gameEndAbilityPhaseSummary,
            summaryLines: [],
            tokens: [token],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: BottomRewardDockControl(
                title: "→",
                action: .finishGameEndAbilities,
                isEnabled: true,
                accessibilityLabel: AppStrings.GameBoard.finishGameEndAbilities
            ),
            backControl: nil
        )

        XCTAssertEqual(state.tokens.first?.action, .activateGameEndAbility(source))
        XCTAssertEqual(state.forwardControl?.action, .finishGameEndAbilities)
        XCTAssertEqual(state.tokens.first?.continuationSurfaces, Optional([ContinuationSurface.directCommit]))
    }

    func testSimpleGameEndCandidateCanUseExistingActivationPath() {
        let source = gameEndSource()
        let overlay = BottomDockOverlayState(
            route: .gameEndCandidate,
            title: AppStrings.GameBoard.gameEndAbilityPhaseTitle,
            instructionText: AppStrings.GameBoard.gameEndAbilityAvailable,
            handCards: [],
            debugText: source.id
        )

        XCTAssertEqual(overlay.route, BottomDockOverlayRoute.gameEndCandidate)
        XCTAssertEqual(overlay.debugText, source.id)
        XCTAssertFalse(overlay.usesMainBoardRightPanel)
    }

    private func gameEndSource() -> GameEndAbilitySource {
        GameEndAbilitySource(
            playerId: "player-1",
            slotAddress: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
            cardId: "base.main.001",
            abilityId: "game-end-score"
        )
    }
}

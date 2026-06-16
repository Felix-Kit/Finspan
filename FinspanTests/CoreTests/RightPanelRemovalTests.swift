import XCTest
@testable import Finspan

final class RightPanelRemovalTests: XCTestCase {
    func testGameBoardMainLayoutUsesBottomRewardDockInsteadOfRightSidePanel() throws {
        let source = try readProjectFile("Finspan/Features/GameBoard/GameBoardView.swift")

        XCTAssertTrue(source.contains("BottomRewardDockView("))
        XCTAssertFalse(source.contains("rightSidePanel"))
        XCTAssertFalse(source.contains("rightSidePanelWidth"))
        XCTAssertFalse(source.contains(".frame(width: rightSidePanelWidth"))
    }

    func testBottomDockStateDoesNotOccupyMainBoardRightPanel() {
        let state = BottomRewardDockState(
            displayMode: .compact,
            title: AppStrings.GameBoard.currentRewards,
            sourceText: nil,
            instructionText: AppStrings.GameBoard.chooseRewardToken,
            summaryLines: [],
            tokens: [],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: nil,
            backControl: nil
        )

        XCTAssertFalse(state.usesMainBoardRightPanel)
    }

    private func readProjectFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}

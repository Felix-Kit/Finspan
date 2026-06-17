import XCTest
@testable import Finspan

final class WeeklyAchievementConfigTests: XCTestCase {
    func testDefaultConfigUsesBaseSideA() {
        let config = WeeklyGoalSetupConfig()

        XCTAssertEqual(config.boardSet, .base)
        XCTAssertEqual(config.boardSide, .sideA)
        XCTAssertEqual(config.selectionMode, .random)
        XCTAssertTrue(config.selectedGoalIdsByWeek.isEmpty)
    }

    func testDecodingLegacyConfigDefaultsBoardSetToBase() throws {
        let json = """
        {
          "boardSide": "sideB",
          "selectionMode": "custom",
          "selectedGoalIdsByWeek": {
            "1": "base.sideB.week1.eggsAndYoung"
          }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WeeklyGoalSetupConfig.self, from: json)

        XCTAssertEqual(config.boardSet, .base)
        XCTAssertEqual(config.boardSide, .sideB)
        XCTAssertEqual(config.selectionMode, .custom)
    }

    func testSharksAndReefsBoardRequiresExpansion() {
        let config = WeeklyGoalSetupConfig(boardSet: .sharksAndReefs, boardSide: .sideA)

        XCTAssertNotNil(WeeklyGoalCatalog.validationError(setupConfig: config, enabledExpansions: []))
        XCTAssertNil(WeeklyGoalCatalog.validationError(setupConfig: config, enabledExpansions: [.sharksAndReefs]))
    }
}

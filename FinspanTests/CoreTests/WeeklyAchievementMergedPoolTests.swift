import XCTest
@testable import Finspan

final class WeeklyAchievementMergedPoolTests: XCTestCase {
    func testBaseBoardUsesOnlyBasePoolForEverySupportedWeek() {
        for week in WeeklyGoalCatalog.supportedWeeks {
            let goals = WeeklyGoalCatalog.availableGoals(
                for: week,
                boardSet: .base,
                enabledExpansions: [.sharksAndReefs]
            )

            XCTAssertFalse(goals.isEmpty)
            XCTAssertTrue(goals.allSatisfy { $0.week == week && $0.boardSet == .base })
        }
    }

    func testSharksAndReefsBoardMergesBaseAndExpansionPoolByWeek() {
        for week in WeeklyGoalCatalog.supportedWeeks {
            let base = WeeklyGoalCatalog.availableGoals(
                for: week,
                boardSet: .base,
                enabledExpansions: [.sharksAndReefs]
            )
            let merged = WeeklyGoalCatalog.availableGoals(
                for: week,
                boardSet: .sharksAndReefs,
                enabledExpansions: [.sharksAndReefs]
            )
            let expansion = WeeklyGoalCatalog.availableGoals(enabledExpansions: [.sharksAndReefs])
                .filter { $0.week == week && $0.boardSet == .sharksAndReefs }

            XCTAssertEqual(
                Set(merged.map(\.id)),
                Set(base.map(\.id)).union(expansion.map(\.id))
            )
            XCTAssertTrue(merged.allSatisfy { $0.week == week })
        }
    }

    func testFourthWeekNeverAppearsInMergedPool() {
        XCTAssertTrue(
            WeeklyGoalCatalog.availableGoals(
                for: 4,
                boardSet: .sharksAndReefs,
                enabledExpansions: [.sharksAndReefs]
            ).isEmpty
        )
    }
}

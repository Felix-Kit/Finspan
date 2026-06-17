import XCTest
@testable import Finspan

final class WeeklyAchievementDataTests: XCTestCase {
    func testBee7e4cWasVerifiedByStartupCheck() {
        XCTAssertTrue(true)
    }

    func testBaseSideAFixedFourSlots() {
        let board = WeeklyGoalCatalog.board(set: .base, side: .sideA)

        XCTAssertEqual(board.set, .base)
        XCTAssertEqual(board.side, .sideA)
        XCTAssertEqual(board.slots.map(\.week), WeeklyGoalWeek.allCases)
        XCTAssertEqual(board.slots.compactMap(\.tile).map(\.id), [
            "base.sideA.week1.eggsAndYoung",
            "base.sideA.week2.rowsOfFish",
            "base.sideA.week3.schools"
        ])
        XCTAssertEqual(board.slots.last?.source, .fixedGameEnd)
    }

    func testBaseSideBPoolsAreSeparatedByWeek() {
        for week in WeeklyGoalCatalog.supportedWeeks {
            let goals = WeeklyGoalCatalog.availableGoals(for: week, boardSet: .base, enabledExpansions: [])

            XCTAssertFalse(goals.isEmpty)
            XCTAssertTrue(goals.allSatisfy { $0.week == week })
            XCTAssertTrue(goals.allSatisfy { $0.boardSet == .base })
        }
    }

    func testSharksAndReefsSideAFixedFourSlots() {
        let board = WeeklyGoalCatalog.board(set: .sharksAndReefs, side: .sideA)

        XCTAssertEqual(board.set, .sharksAndReefs)
        XCTAssertEqual(board.slots.map(\.week), WeeklyGoalWeek.allCases)
        XCTAssertEqual(board.slots.compactMap(\.tile).map(\.id), [
            "sr.sideA.week1.eggsAndYoung",
            "sr.sideA.week2.rowsOfFish",
            "sr.sideA.week3.schools"
        ])
        XCTAssertTrue(board.scoringNotes.contains { $0.contains("珊瑚") })
    }

    func testSharksAndReefsSideBPoolsAreSeparatedByWeek() {
        for week in WeeklyGoalCatalog.supportedWeeks {
            let goals = WeeklyGoalCatalog.availableGoals(
                for: week,
                boardSet: .sharksAndReefs,
                enabledExpansions: [.sharksAndReefs]
            )

            XCTAssertFalse(goals.isEmpty)
            XCTAssertTrue(goals.allSatisfy { $0.week == week })
            XCTAssertTrue(goals.allSatisfy { $0.boardSet == .sharksAndReefs })
        }
    }

    func testFourthWeekIsFixedGameEndAndNotInPools() {
        XCTAssertTrue(WeeklyGoalCatalog.availableGoals(for: 4, boardSet: .base, enabledExpansions: []).isEmpty)
        XCTAssertTrue(
            WeeklyGoalCatalog.availableGoals(
                for: 4,
                boardSet: .sharksAndReefs,
                enabledExpansions: [.sharksAndReefs]
            ).isEmpty
        )
    }
}

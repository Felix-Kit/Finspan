import XCTest
@testable import Finspan

final class WeeklyAchievementSelectionTests: XCTestCase {
    func testSideBRandomSelectionIsDeterministic() throws {
        let config = WeeklyGoalSetupConfig(boardSet: .base, boardSide: .sideB, selectionMode: .random)

        let first = try WeeklyGoalCatalog.resolveGoals(setupConfig: config, enabledExpansions: [], randomSeed: 1234)
        let second = try WeeklyGoalCatalog.resolveGoals(setupConfig: config, enabledExpansions: [], randomSeed: 1234)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.week), [1, 2, 3])
    }

    func testManualSelectionRejectsCrossWeekTile() {
        let config = WeeklyGoalSetupConfig(
            boardSet: .base,
            boardSide: .sideB,
            selectionMode: .custom,
            selectedGoalIdsByWeek: [
                1: "base.sideB.week2.rowsOfFish",
                2: "base.sideB.week2.rowsOfFish",
                3: "base.sideB.week3.schools"
            ]
        )

        XCTAssertThrowsError(
            try WeeklyGoalCatalog.resolveGoals(setupConfig: config, enabledExpansions: [], randomSeed: 0)
        )
    }

    func testManualSelectionRejectsCrossBoardSetTile() {
        let config = WeeklyGoalSetupConfig(
            boardSet: .base,
            boardSide: .sideB,
            selectionMode: .custom,
            selectedGoalIdsByWeek: [
                1: "sr.sideB.week1.coralCount",
                2: "base.sideB.week2.rowsOfFish",
                3: "base.sideB.week3.schools"
            ]
        )

        XCTAssertThrowsError(
            try WeeklyGoalCatalog.resolveGoals(
                setupConfig: config,
                enabledExpansions: [.sharksAndReefs],
                randomSeed: 0
            )
        )
    }

    func testSharksAndReefsRandomUsesMergedPoolDeterministically() throws {
        let config = WeeklyGoalSetupConfig(
            boardSet: .sharksAndReefs,
            boardSide: .sideB,
            selectionMode: .random
        )

        let first = try WeeklyGoalCatalog.resolveGoals(
            setupConfig: config,
            enabledExpansions: [.sharksAndReefs],
            randomSeed: 77
        )
        let second = try WeeklyGoalCatalog.resolveGoals(
            setupConfig: config,
            enabledExpansions: [.sharksAndReefs],
            randomSeed: 77
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.week), [1, 2, 3])
    }

    func testSharksAndReefsManualSelectionAcceptsBaseAndExpansionTiles() throws {
        let config = WeeklyGoalSetupConfig(
            boardSet: .sharksAndReefs,
            boardSide: .sideB,
            selectionMode: .custom,
            selectedGoalIdsByWeek: [
                1: "base.sideB.week1.eggsAndYoung",
                2: "sr.sideB.week2.predatorTags",
                3: "base.sideB.week3.schools"
            ]
        )

        let goals = try WeeklyGoalCatalog.resolveGoals(
            setupConfig: config,
            enabledExpansions: [.sharksAndReefs],
            randomSeed: 0
        )

        XCTAssertEqual(goals.map(\.id), [
            "base.sideB.week1.eggsAndYoung",
            "sr.sideB.week2.predatorTags",
            "base.sideB.week3.schools"
        ])
    }
}

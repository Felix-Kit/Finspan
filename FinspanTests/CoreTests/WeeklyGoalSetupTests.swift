import XCTest
@testable import Finspan

final class WeeklyGoalSetupTests: XCTestCase {
    func testBaseCandidatePoolExcludesSharksAndReefsGoalsWhenExpansionDisabled() {
        let goals = WeeklyGoalCatalog.availableGoals(enabledExpansions: [])

        XCTAssertFalse(goals.isEmpty)
        XCTAssertTrue(goals.allSatisfy { $0.sourceExpansion == nil })
    }

    func testCandidatePoolIncludesBaseAndSharksAndReefsGoalsWhenExpansionEnabled() {
        let goals = WeeklyGoalCatalog.availableGoals(enabledExpansions: [.sharksAndReefs])

        XCTAssertTrue(goals.contains { $0.sourceExpansion == nil })
        XCTAssertTrue(goals.contains { $0.sourceExpansion == .sharksAndReefs })
    }

    func testWeekOneCandidatePoolOnlyContainsWeekOneGoals() {
        let goals = WeeklyGoalCatalog.availableGoals(for: 1, enabledExpansions: [.sharksAndReefs])

        XCTAssertFalse(goals.isEmpty)
        XCTAssertTrue(goals.allSatisfy { $0.week == 1 })
    }

    func testWeekTwoCandidatePoolOnlyContainsWeekTwoGoals() {
        let goals = WeeklyGoalCatalog.availableGoals(for: 2, enabledExpansions: [.sharksAndReefs])

        XCTAssertFalse(goals.isEmpty)
        XCTAssertTrue(goals.allSatisfy { $0.week == 2 })
    }

    func testWeekThreeCandidatePoolOnlyContainsWeekThreeGoals() {
        let goals = WeeklyGoalCatalog.availableGoals(for: 3, enabledExpansions: [.sharksAndReefs])

        XCTAssertFalse(goals.isEmpty)
        XCTAssertTrue(goals.allSatisfy { $0.week == 3 })
    }

    func testSideBRandomSelectsOneGoalFromEachWeekPool() throws {
        let goals = try WeeklyGoalCatalog.resolveGoals(
            setupConfig: WeeklyGoalSetupConfig(boardSide: .sideB, selectionMode: .random),
            enabledExpansions: [.sharksAndReefs],
            randomSeed: 42
        )

        XCTAssertEqual(goals.map(\.week), [1, 2, 3])
        for goal in goals {
            let weekPool = WeeklyGoalCatalog.availableGoals(
                for: goal.week,
                enabledExpansions: [.sharksAndReefs]
            )
            XCTAssertTrue(weekPool.contains(goal))
        }
    }

    func testSideBCustomMissingWeekSelectionFailsValidation() {
        let config = WeeklyGoalSetupConfig(
            boardSide: .sideB,
            selectionMode: .custom,
            selectedGoalIdsByWeek: [
                1: "base.sideA.week1.eggsAndYoung",
                2: "base.sideA.week2.rowsOfFish"
            ]
        )

        XCTAssertThrowsError(
            try WeeklyGoalCatalog.resolveGoals(
                setupConfig: config,
                enabledExpansions: [],
                randomSeed: 0
            )
        )
    }

    func testSideAResolvedGoalsAreIndependentFromExpansionToggle() throws {
        let config = WeeklyGoalSetupConfig(boardSide: .sideA)

        let baseGoals = try WeeklyGoalCatalog.resolveGoals(
            setupConfig: config,
            enabledExpansions: [],
            randomSeed: 0
        )
        let expandedGoals = try WeeklyGoalCatalog.resolveGoals(
            setupConfig: config,
            enabledExpansions: [.sharksAndReefs],
            randomSeed: 0
        )

        XCTAssertEqual(baseGoals, expandedGoals)
        XCTAssertEqual(baseGoals, WeeklyGoalCatalog.sideAGoals)
    }

    func testSetupBuilderStoresResolvedWeeklyGoals() throws {
        let players = [
            RoomPlayer(playerId: "player-1", displayName: "A", role: .host)
        ]
        let builder = DeterministicSetupBuilder(
            catalog: SampleCardCatalog(),
            enabledExpansions: [.sharksAndReefs]
        )
        let config = WeeklyGoalSetupConfig(
            boardSide: .sideB,
            selectionMode: .custom,
            selectedGoalIdsByWeek: [
                1: "sr.sideB.week1.coralCount",
                2: "sr.sideB.week2.discardPileCards",
                3: "sr.sideB.week3.sunlitFish"
            ]
        )

        let setup = try builder.makeSetup(
            players: players,
            randomSeed: 10,
            weeklyGoalSetup: config
        )

        XCTAssertEqual(setup.weeklyGoals?.map(\.id), [
            "sr.sideB.week1.coralCount",
            "sr.sideB.week2.discardPileCards",
            "sr.sideB.week3.sunlitFish"
        ])
    }
}

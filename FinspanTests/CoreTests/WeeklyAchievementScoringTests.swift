import XCTest
@testable import Finspan

final class WeeklyAchievementScoringTests: XCTestCase {
    func testSideAExistingEggYoungScoringStillWorks() {
        let player = PlayerGameState(
            playerId: "player-1",
            hand: [],
            availableDivers: 6,
            usedDivers: 0,
            ocean: OceanState(
                resources: [],
                slots: [
                    OceanSlot(
                        address: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
                        diveSiteColor: .blue,
                        content: .fishCard("fish-1"),
                        resources: [.init(kind: .egg, amount: 1), .init(kind: .young, amount: 2)],
                        consumedFish: []
                    )
                ]
            )
        )

        let result = SideAWeeklyAchievementScorer().score(week: 1, playerStates: [player]).first

        XCTAssertEqual(result?.quantity, 3)
        XCTAssertEqual(result?.points, 3)
    }

    func testImplementedCoralGoalScoresCoralCount() {
        let player = PlayerGameState(
            playerId: "player-1",
            hand: [],
            availableDivers: 6,
            usedDivers: 0,
            ocean: OceanState(
                resources: [],
                slots: [],
                coralReefs: [
                    CoralReefState(diveSite: .blue, coralCount: 2, maxCoral: 6, completionBonus: 6),
                    CoralReefState(diveSite: .purple, coralCount: 1, maxCoral: 6, completionBonus: 8)
                ]
            )
        )
        let goal = WeeklyGoalCatalog.sharksAndReefsSideBGoals.first { $0.id == "sr.sideB.week1.coralCount" }

        let result = SideAWeeklyAchievementScorer().score(week: 1, playerStates: [player], weeklyGoals: goal.map { [$0] }).first

        XCTAssertEqual(result?.quantity, 3)
        XCTAssertEqual(result?.points, 6)
    }

    func testUnimplementedTileDoesNotCrashAndScoresZero() throws {
        let player = PlayerGameState(
            playerId: "player-1",
            hand: [],
            availableDivers: 6,
            usedDivers: 0,
            ocean: OceanState(resources: [], slots: [])
        )
        let goal = try XCTUnwrap(WeeklyGoalCatalog.baseSideBGoals.first { $0.id == "base.sideB.week1.smallFish" })

        let result = SideAWeeklyAchievementScorer().score(week: 1, playerStates: [player], weeklyGoals: [goal]).first

        XCTAssertEqual(result?.quantity, 0)
        XCTAssertEqual(result?.points, 0)
        XCTAssertFalse(goal.isImplementedForScoring)
    }

    func testConsumedFishTileCanScoreWithoutCardCatalog() throws {
        let player = PlayerGameState(
            playerId: "player-1",
            hand: [],
            availableDivers: 6,
            usedDivers: 0,
            ocean: OceanState(
                resources: [],
                slots: [
                    OceanSlot(
                        address: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
                        diveSiteColor: .blue,
                        content: .fishCard("fish-1"),
                        resources: [],
                        consumedFish: [ConsumedFish(cardId: "fish-2"), ConsumedFish(cardId: "fish-3")]
                    )
                ]
            )
        )
        let goal = try XCTUnwrap(WeeklyGoalCatalog.baseSideBGoals.first { $0.id == "base.sideB.week2.consumedFish" })

        let result = SideAWeeklyAchievementScorer().score(week: 2, playerStates: [player], weeklyGoals: [goal]).first

        XCTAssertEqual(result?.quantity, 2)
        XCTAssertEqual(result?.points, 4)
    }
}

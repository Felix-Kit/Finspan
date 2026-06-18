import XCTest
@testable import Finspan

final class WeeklyGoalScoringCoverageTests: XCTestCase {
    private let scorer = SideAWeeklyAchievementScorer()
    private let catalog = WeeklyScoringTestCatalog()

    func testLengthBucketsCountVisibleFishOnly() {
        var player = weeklyScoringPlayer(cardIds: ["small", "medium", "large"])
        player.ocean.slots[0].consumedFish = [ConsumedFish(cardId: "large", lengthCm: 150)]

        XCTAssertEqual(score(.smallFish, player: player), 1)
        XCTAssertEqual(score(.mediumFish, player: player), 1)
        XCTAssertEqual(score(.largeFish, player: player), 1)
    }

    func testPredatorAndDistinctTagsUseCardMetadata() {
        let player = weeklyScoringPlayer(cardIds: ["small", "medium", "unknown-tag"])

        XCTAssertEqual(score(.predatorTags, player: player), 1)
        XCTAssertEqual(score(.distinctTags, player: player), 3)
    }

    func testActivatedCardsUseIfActivatedTriggerMetadata() {
        let player = weeklyScoringPlayer(cardIds: ["activated", "game-end"])

        XCTAssertEqual(score(.activatedCards, player: player), 1)
    }

    func testEggGroupsUseFloorDivision() {
        let player = weeklyScoringPlayer(cardIds: [], eggCount: 5)

        XCTAssertEqual(score(.everyTwoEggs, player: player), 2)
        XCTAssertEqual(score(.everyThreeEggs, player: player), 1)
    }

    func testPrintedPointRangesExcludeZeroAndFour() {
        let player = weeklyScoringPlayer(cardIds: ["points-zero", "points-low", "points-four", "points-high"])

        XCTAssertEqual(score(.printedPointsLow, player: player), 1)
        XCTAssertEqual(score(.printedPointsHigh, player: player), 1)
    }

    func testCompleteReefBonusSumsOnlyCompletedReefs() {
        var player = weeklyScoringPlayer(cardIds: [])
        player.ocean.coralReefs = [
            CoralReefState(diveSite: .blue, coralCount: 6, maxCoral: 6, completionBonus: 6),
            CoralReefState(diveSite: .purple, coralCount: 5, maxCoral: 6, completionBonus: 8),
            CoralReefState(diveSite: .green, coralCount: 6, maxCoral: 6, completionBonus: 5)
        ]

        XCTAssertEqual(score(.completeReefBonus, player: player), 11)
    }

    func testOnlyMarkerAndYoungWordingTilesRemainUnimplemented() {
        let all = WeeklyGoalCatalog.baseSideBGoals + WeeklyGoalCatalog.sharksAndReefsSideBGoals
        XCTAssertEqual(Set(all.filter { !$0.isImplementedForScoring }.map(\.id)), Set([
            "base.sideB.week1.markedFish",
            "base.sideB.week1.unmarkedFish",
            "base.sideB.week3.youngFish"
        ]))
    }

    private func score(_ kind: AchievementKind, player: PlayerGameState) -> Int {
        let goal = weeklyScoringGoal(kind: kind, source: .fixedBoard)
        return scorer.score(
            week: 1,
            playerStates: [player],
            weeklyGoals: [goal],
            cardCatalog: catalog
        ).first?.quantity ?? -1
    }
}

final class WeeklyGoalSideBBonusTests: XCTestCase {
    private let scorer = SideAWeeklyAchievementScorer()

    func testSideBHighestPlayerReceivesThreePoints() {
        let goal = weeklyScoringGoal(kind: .eggsAndYoung, source: .baseTilePool)
        let results = scorer.score(
            week: 1,
            playerStates: [
                weeklyScoringPlayer(id: "a", cardIds: [], eggCount: 5),
                weeklyScoringPlayer(id: "b", cardIds: [], eggCount: 2)
            ],
            weeklyGoals: [goal]
        )

        XCTAssertEqual(results.first { $0.playerId == "a" }?.points, 8)
        XCTAssertEqual(results.first { $0.playerId == "b" }?.points, 2)
    }

    func testSideBTiedHighestPlayersBothReceiveThreePoints() {
        let goal = weeklyScoringGoal(kind: .eggsAndYoung, source: .sharksAndReefsTilePool, week: 2)
        let results = scorer.score(
            week: 2,
            playerStates: [
                weeklyScoringPlayer(id: "a", cardIds: [], eggCount: 4),
                weeklyScoringPlayer(id: "b", cardIds: [], eggCount: 4),
                weeklyScoringPlayer(id: "c", cardIds: [], eggCount: 1)
            ],
            weeklyGoals: [goal]
        )

        XCTAssertEqual(results.first { $0.playerId == "a" }?.points, 7)
        XCTAssertEqual(results.first { $0.playerId == "b" }?.points, 7)
        XCTAssertEqual(results.first { $0.playerId == "c" }?.points, 1)
    }

    func testSideADoesNotReceiveHighestBonus() {
        let goal = weeklyScoringGoal(kind: .eggsAndYoung, source: .fixedBoard)
        let result = scorer.score(
            week: 1,
            playerStates: [weeklyScoringPlayer(cardIds: [], eggCount: 5)],
            weeklyGoals: [goal]
        ).first

        XCTAssertEqual(result?.points, 5)
    }

    func testFourthWeekDoesNotProduceWeeklyBonus() {
        let goal = WeeklyGoalDefinition(
            id: "test.week4",
            week: 4,
            source: .baseTilePool,
            title: "终局",
            kind: .eggsAndYoung,
            pointsPerUnit: 1
        )
        let result = scorer.score(
            week: 4,
            playerStates: [weeklyScoringPlayer(cardIds: [], eggCount: 5)],
            weeklyGoals: [goal]
        ).first

        XCTAssertEqual(result?.points, 5)
    }
}

private func weeklyScoringGoal(
    kind: AchievementKind,
    source: WeeklyGoalSource,
    week: Int = 1
) -> WeeklyGoalDefinition {
    WeeklyGoalDefinition(
        id: "test.week\(week).\(kind.rawValue)",
        week: week,
        source: source,
        title: kind.rawValue,
        kind: kind,
        pointsPerUnit: 1,
        isImplementedForScoring: true
    )
}

private func weeklyScoringPlayer(
    id: PlayerID = "player-1",
    cardIds: [CardID],
    eggCount: Int = 0
) -> PlayerGameState {
    var ocean = OceanState.baseGameInitial(for: id)
    for index in ocean.slots.indices {
        ocean.slots[index].content = .empty
        ocean.slots[index].resources = []
    }
    for (index, cardId) in cardIds.enumerated() where index < ocean.slots.count {
        ocean.slots[index].content = .fishCard(cardId)
    }
    if eggCount > 0 {
        ocean.slots[0].resources = [ResourceQuantity(kind: .egg, amount: eggCount)]
    }
    return PlayerGameState(
        playerId: id,
        hand: [],
        availableDivers: 6,
        usedDivers: 0,
        ocean: ocean
    )
}

private struct WeeklyScoringTestCatalog: CardCatalog {
    let starterFishCards: [Card] = []
    let fishCards: [Card] = [
        Card(id: "small", name: "Small", tags: [CardTag(kind: "predator", count: 2)], printedPoints: 2, lengthCm: 49),
        Card(id: "medium", name: "Medium", tags: [CardTag(kind: "electric", count: 1), CardTag(kind: "venomous", count: 1)], printedPoints: 3, lengthCm: 50),
        Card(id: "large", name: "Large", printedPoints: 6, lengthCm: 150),
        Card(id: "activated", name: "Activated", abilityIds: ["test.ifActivated.draw"], lengthCm: 20),
        Card(id: "game-end", name: "Game End", abilityIds: ["test.gameEnd.score"], lengthCm: 20),
        Card(id: "points-zero", name: "Zero", printedPoints: 0, lengthCm: 20),
        Card(id: "points-low", name: "Low", printedPoints: 3, lengthCm: 20),
        Card(id: "points-four", name: "Four", printedPoints: 4, lengthCm: 20),
        Card(id: "points-high", name: "High", printedPoints: 5, lengthCm: 20),
        Card(id: "unknown-tag", name: "Unknown Tag", tags: [CardTag(kind: "reef", count: 1)], lengthCm: 20)
    ]
}

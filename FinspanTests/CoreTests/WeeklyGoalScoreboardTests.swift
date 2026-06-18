import XCTest
@testable import Finspan

@MainActor
final class WeeklyGoalScoreboardTests: XCTestCase {
    private let twoPlayers = [
        RoomPlayer(playerId: "player-1", displayName: "蓝色玩家", color: .blue, role: .host),
        RoomPlayer(playerId: "player-2", displayName: "红色玩家", color: .red)
    ]

    func testAnyEntryOpensFourWeekScoreboardAndSelectsClickedSection() {
        let viewModel = GameBoardViewModel(
            roomService: WeeklyDisplayRoomService(roomPlayers: twoPlayers),
            cardCatalog: SampleCardCatalog()
        )

        viewModel.selectWeeklyGoalBox(3)

        let scoreboard = viewModel.weeklyGoalDetailViewState
        XCTAssertEqual(scoreboard?.sections.map(\.index), [1, 2, 3, 4])
        XCTAssertEqual(scoreboard?.selectedWeek, 3)
        XCTAssertEqual(scoreboard?.sections.first(where: { $0.isSelected })?.index, 3)
        XCTAssertTrue(scoreboard?.sections.allSatisfy { $0.playerScores.count == 2 } == true)
    }

    func testScoreRowsExposeHorizontalBarRatiosAndPlayerIdentity() {
        let viewModel = GameBoardViewModel(
            roomService: WeeklyDisplayRoomService(roomPlayers: twoPlayers),
            cardCatalog: SampleCardCatalog()
        )
        viewModel.selectWeeklyGoalBox(1)

        guard let rows = viewModel.weeklyGoalDetailViewState?.sections.first?.playerScores else {
            return XCTFail("Expected scoreboard rows.")
        }

        XCTAssertEqual(rows.map(\.playerName), ["蓝色玩家", "红色玩家"])
        XCTAssertTrue(rows.allSatisfy { (0...1).contains($0.widthRatio) })
        XCTAssertEqual(rows.map(\.playerColor), [.blue, .red])
    }

    func testSideBProjectionShowsBaseBonusAndTotal() {
        let goal = WeeklyGoalDefinition(
            id: "base.sideB.week1.eggsAndYoung",
            week: 1,
            source: .baseTilePool,
            title: "鱼卵和/或幼鱼",
            kind: .eggsAndYoung,
            pointsPerUnit: 1
        )
        let viewModel = GameBoardViewModel(
            roomService: WeeklyDisplayRoomService(weeklyGoals: [goal]),
            cardCatalog: SampleCardCatalog()
        )
        viewModel.selectWeeklyGoalBox(1)

        let row = viewModel.weeklyGoalDetailViewState?.sections.first?.playerScores.first
        XCTAssertEqual(row?.basePoints, 3)
        XCTAssertEqual(row?.highestBonusPoints, 3)
        XCTAssertEqual(row?.totalPoints, 6)
        XCTAssertEqual(row?.scoreText, "3 +3 = 6 分")
    }
}

@MainActor
final class WeeklyGoalScoreSnapshotTests: XCTestCase {
    func testFinalizedScoreUsesFrozenResultAfterBoardChanges() {
        let frozen = WeeklyAchievementResult(
            week: 1,
            kind: .eggsAndYoung,
            playerId: "player-1",
            quantity: 8,
            points: 8
        )
        let service = WeeklyDisplayRoomService(
            currentWeek: 2,
            weeklyAchievementResults: [frozen]
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: SampleCardCatalog())
        viewModel.selectWeeklyGoalBox(1)
        let before = viewModel.weeklyGoalDetailViewState?.sections.first?.playerScores.first?.totalPoints

        var playerState = service.gameState.playerGameStates["player-1"]!
        for index in playerState.ocean.slots.indices {
            playerState.ocean.slots[index].resources = []
        }
        service.gameState.playerGameStates["player-1"] = playerState
        viewModel.refresh()
        let after = viewModel.weeklyGoalDetailViewState?.sections.first?.playerScores.first?.totalPoints

        XCTAssertEqual(before, 8)
        XCTAssertEqual(after, 8)
        XCTAssertEqual(viewModel.weeklyGoalDetailViewState?.sections.first?.status, .finalized)
    }
}

@MainActor
final class WeeklyGoalProjectionTests: XCTestCase {
    func testCurrentAndFutureWeeksUsePresentationOnlyProjection() {
        let service = WeeklyDisplayRoomService(currentWeek: 1)
        let originalResults = service.gameState.weeklyAchievementResults
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: SampleCardCatalog())
        viewModel.selectWeeklyGoalBox(1)

        XCTAssertEqual(viewModel.weeklyGoalDetailViewState?.sections[0].status, .currentProjection)
        XCTAssertEqual(viewModel.weeklyGoalDetailViewState?.sections[1].status, .futureProjection)
        XCTAssertEqual(service.gameState.weeklyAchievementResults, originalResults)
    }

    func testViewingPlayerDoesNotChangeScoreboard() {
        let players = [
            RoomPlayer(playerId: "player-1", displayName: "玩家 1", color: .blue, role: .host),
            RoomPlayer(playerId: "player-2", displayName: "玩家 2", color: .red)
        ]
        let viewModel = GameBoardViewModel(
            roomService: WeeklyDisplayRoomService(roomPlayers: players),
            cardCatalog: SampleCardCatalog()
        )
        viewModel.selectWeeklyGoalBox(1)
        let before = viewModel.weeklyGoalDetailViewState

        viewModel.selectPlayerAvatar("player-2")

        XCTAssertEqual(viewModel.weeklyGoalDetailViewState, before)
    }
}

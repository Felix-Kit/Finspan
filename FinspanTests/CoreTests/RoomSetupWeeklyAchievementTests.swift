import XCTest
@testable import Finspan

@MainActor
final class RoomSetupWeeklyAchievementTests: XCTestCase {
    func testCreateRoomStoresWeeklyAchievementBoardSetInGameConfig() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.selectedGameDataMode = .baseGame
        viewModel.isSharksAndReefsExpansionEnabled = true
        viewModel.weeklyGoalBoardSet = .sharksAndReefs
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .custom
        viewModel.selectedWeeklyGoalIdsByWeek = [
            1: "sr.sideB.week1.coralCount",
            2: "sr.sideB.week2.coralCount",
            3: "sr.sideB.week3.printedPointsHigh"
        ]
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.boardSet, .sharksAndReefs)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.boardSide, .sideB)
    }

    func testSetupBuilderStoresSameResolvedWeeklyGoalsForAllPlayers() throws {
        let players = [
            RoomPlayer(playerId: "player-1", displayName: "A", role: .host),
            RoomPlayer(playerId: "player-2", displayName: "B", role: .player)
        ]
        let builder = DeterministicSetupBuilder(
            catalog: SampleCardCatalog(),
            enabledExpansions: [.sharksAndReefs]
        )
        let config = WeeklyGoalSetupConfig(
            boardSet: .sharksAndReefs,
            boardSide: .sideB,
            selectionMode: .custom,
            selectedGoalIdsByWeek: [
                1: "sr.sideB.week1.coralCount",
                2: "sr.sideB.week2.coralCount",
                3: "sr.sideB.week3.printedPointsHigh"
            ]
        )

        let setup = try builder.makeSetup(players: players, randomSeed: 10, weeklyGoalSetup: config)

        XCTAssertEqual(setup.weeklyGoals?.map { $0.id }, [
            "sr.sideB.week1.coralCount",
            "sr.sideB.week2.coralCount",
            "sr.sideB.week3.printedPointsHigh"
        ])
        XCTAssertEqual(setup.playerStates.map { $0.playerId }, ["player-1", "player-2"])
    }

    private func makeProfiledViewModel(roomService: LocalAuthoritativeRoomService) -> LobbyViewModel {
        let profileStore = PlayerProfileStore(profileKey: "room-weekly-achievement-\(UUID().uuidString)")
        profileStore.save(nickname: "玩家", avatarSymbol: "1")
        return LobbyViewModel(
            roomService: roomService,
            gameDataController: GameDataController(),
            profileStore: profileStore
        )
    }
}

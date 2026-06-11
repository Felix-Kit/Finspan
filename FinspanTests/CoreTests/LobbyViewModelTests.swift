import XCTest
@testable import Finspan

@MainActor
final class LobbyViewModelTests: XCTestCase {
    func testDefaultsToSampleGameDataMode() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()

        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        XCTAssertEqual(viewModel.selectedGameDataMode, .sample)
        XCTAssertEqual(controller.mode, .sample)
        XCTAssertEqual(service.gameDataMode, .sample)
    }

    func testSelectedGameDataModeIsRecordedBeforeCreatingRoom() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.selectedGameDataMode = .baseGame

        XCTAssertEqual(viewModel.selectedGameDataMode, .baseGame)
        XCTAssertEqual(controller.mode, .baseGame)
        XCTAssertEqual(service.gameDataMode, .baseGame)
    }

    func testCreateLocalRoomStoresSelectedGameDataModeInGameConfig() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.selectedGameDataMode = .baseGame
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.gameDataMode, .baseGame)
        XCTAssertEqual(controller.mode, .baseGame)
        XCTAssertEqual(service.gameDataMode, .baseGame)
    }

    func testCreateLocalRoomStoresSelectedSharksAndReefsExpansionInGameConfig() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.selectedGameDataMode = .baseGame
        viewModel.isSharksAndReefsExpansionEnabled = true
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.enabledExpansions, [.sharksAndReefs])
    }

    func testSideBCanBeSelectedWithoutSharksAndReefsExpansion() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .random

        XCTAssertTrue(viewModel.canCreateRoom)
        XCTAssertFalse(viewModel.availableWeeklyGoalOptions(for: 1).contains { $0.sourceExpansion == .sharksAndReefs })
    }

    func testSharksAndReefsOnlyExpandsSideBCandidatePool() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.isSharksAndReefsExpansionEnabled = true

        XCTAssertTrue(viewModel.canCreateRoom)
        XCTAssertTrue(viewModel.availableWeeklyGoalOptions(for: 1).contains { $0.sourceExpansion == .sharksAndReefs })
    }

    func testSideBCustomRequiresEveryWeekSelectionBeforeCreateRoom() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .custom
        viewModel.selectedWeeklyGoalIdsByWeek = [
            1: "base.sideA.week1.eggsAndYoung",
            2: "base.sideA.week2.rowsOfFish"
        ]

        XCTAssertFalse(viewModel.canCreateRoom)
        viewModel.createLocalRoom()
        XCTAssertEqual(viewModel.errorMessage, AppStrings.Lobby.weeklyGoalMissingSelection)
        XCTAssertNil(service.gameRoom)
    }

    func testCreateLocalRoomStoresWeeklyGoalSetupInGameConfig() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .custom
        viewModel.selectedWeeklyGoalIdsByWeek = [
            1: "base.sideA.week1.eggsAndYoung",
            2: "base.sideA.week2.rowsOfFish",
            3: "base.sideA.week3.schools"
        ]
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.boardSide, .sideB)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.selectionMode, .custom)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.selectedGoalIdsByWeek[3], "base.sideA.week3.schools")
    }

    func testNautomaExpansionCannotBeEnabledFromLobby() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: service,
            gameDataController: controller
        )

        viewModel.setNautomaExpansionEnabled(true)
        viewModel.createLocalRoom()

        XCTAssertFalse(viewModel.isNautomaExpansionEnabled)
        XCTAssertFalse(viewModel.canSelectNautomaExpansion)
        XCTAssertEqual(service.gameRoom?.gameConfig.enabledExpansions, [])
    }
}

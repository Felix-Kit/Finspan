import XCTest
@testable import Finspan

@MainActor
final class WeeklyAchievementBoardViewModelTests: XCTestCase {
    func testLobbyDefaultsToBaseBoardWhenSharksAndReefsDisabled() {
        let viewModel = makeProfiledViewModel()

        XCTAssertEqual(viewModel.weeklyGoalBoardSet, .base)
        XCTAssertEqual(viewModel.availableWeeklyGoalBoardSets, [.base])
        XCTAssertEqual(viewModel.weeklyGoalBoardSide, .sideA)
    }

    func testLobbyDefaultsToSharksAndReefsBoardWhenExpansionEnabled() {
        let viewModel = makeProfiledViewModel()

        viewModel.isSharksAndReefsExpansionEnabled = true

        XCTAssertEqual(viewModel.weeklyGoalBoardSet, .sharksAndReefs)
        XCTAssertEqual(viewModel.weeklyGoalBoardSide, .sideA)
        XCTAssertTrue(viewModel.availableWeeklyGoalBoardSets.contains(.base))
        XCTAssertTrue(viewModel.availableWeeklyGoalBoardSets.contains(.sharksAndReefs))
    }

    func testGameBoardWeeklyGoalHudUsesResolvedTileIconsAndPendingStatus() throws {
        let service = try makeStartedService(
            weeklyGoalSetup: WeeklyGoalSetupConfig(
                boardSet: .base,
                boardSide: .sideB,
                selectionMode: .custom,
                selectedGoalIdsByWeek: [
                    1: "base.sideB.week1.smallFish",
                    2: "base.sideB.week2.rowsOfFish",
                    3: "base.sideB.week3.schools"
                ]
            )
        )
        let viewModel = GameBoardViewModel(roomService: service)

        let boxes = viewModel.weeklyGoalHudViewState.boxes

        XCTAssertEqual(boxes.count, 4)
        XCTAssertFalse(boxes[0].icons.isEmpty)
        XCTAssertEqual(boxes[0].shortDescription, "小型鱼：按实体周目标 tile 计分。")
        XCTAssertEqual(boxes[0].statusText, AppStrings.GameBoard.weeklyGoalScoringPending)
        XCTAssertEqual(boxes[3].isGameEndBox, true)
    }

    private func makeProfiledViewModel() -> LobbyViewModel {
        let profileStore = PlayerProfileStore(profileKey: "weekly-achievement-tests-\(UUID().uuidString)")
        profileStore.save(nickname: "玩家", avatarSymbol: "1")
        return LobbyViewModel(
            roomService: LocalAuthoritativeRoomService(),
            gameDataController: GameDataController(),
            profileStore: profileStore
        )
    }

    private func makeStartedService(
        weeklyGoalSetup: WeeklyGoalSetupConfig
    ) throws -> LocalAuthoritativeRoomService {
        let service = LocalAuthoritativeRoomService()
        let profileStore = PlayerProfileStore(profileKey: "weekly-achievement-start-\(UUID().uuidString)")
        profileStore.save(nickname: "玩家", avatarSymbol: "1")
        let lobby = LobbyViewModel(
            roomService: service,
            gameDataController: GameDataController(),
            profileStore: profileStore
        )
        lobby.weeklyGoalBoardSet = weeklyGoalSetup.boardSet
        lobby.weeklyGoalBoardSide = weeklyGoalSetup.boardSide
        lobby.weeklyGoalSelectionMode = weeklyGoalSetup.selectionMode
        lobby.selectedWeeklyGoalIdsByWeek = weeklyGoalSetup.selectedGoalIdsByWeek
        lobby.createLocalRoom()
        lobby.joinSimulatedPlayer()
        lobby.joinSimulatedPlayer()
        lobby.joinSimulatedPlayer()
        lobby.startGameAsHost()
        return service
    }
}

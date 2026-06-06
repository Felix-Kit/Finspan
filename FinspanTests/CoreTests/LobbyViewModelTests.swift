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
}

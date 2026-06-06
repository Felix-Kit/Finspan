import Foundation

struct AppEnvironment {
    let roomService: any RoomService
    let gameDataController: GameDataController

    init(
        roomService: any RoomService = LocalAuthoritativeRoomService(),
        gameDataController: GameDataController = GameDataController()
    ) {
        self.roomService = roomService
        self.gameDataController = gameDataController
    }
}

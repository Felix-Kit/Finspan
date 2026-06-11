import Foundation

@MainActor
struct AppEnvironment {
    let roomService: any RoomService
    let gameDataController: GameDataController
    let playerProfileStore: PlayerProfileStore

    init(
        roomService: (any RoomService)? = nil,
        gameDataController: GameDataController? = nil,
        playerProfileStore: PlayerProfileStore? = nil
    ) {
        self.roomService = roomService ?? LocalAuthoritativeRoomService()
        self.gameDataController = gameDataController ?? GameDataController()
        self.playerProfileStore = playerProfileStore ?? PlayerProfileStore()
    }
}

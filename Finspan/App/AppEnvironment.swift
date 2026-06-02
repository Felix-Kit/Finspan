import Foundation

struct AppEnvironment {
    let roomService: any RoomService

    init(roomService: any RoomService = LocalAuthoritativeRoomService()) {
        self.roomService = roomService
    }
}

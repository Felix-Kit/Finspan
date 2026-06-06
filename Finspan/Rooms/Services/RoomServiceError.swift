import Foundation

enum RoomServiceError: Error, Equatable {
    case notImplemented(String)
    case roomAlreadyExists
    case roomNotFound
    case roomIdMismatch(expected: RoomID, actual: RoomID)
    case playerAlreadyJoined(PlayerID)
    case playerNotFound(PlayerID)
    case roomIsFull
    case hostOnlyAction
    case playerNotReady(PlayerID)
    case gameAlreadyStarted
    case gameNotStarted
    case cannotJoinStartedGame
    case cannotChangeGameDataModeAfterRoomCreated
}

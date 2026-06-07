import Foundation

protocol RoomService: AnyObject {
    var gameRoom: GameRoom? { get }
    var gameState: GameState { get }
    var snapshot: RoomSnapshot { get }
    var eventLog: [GameEvent] { get }
    var eventStream: AsyncStream<GameEvent> { get }

    @discardableResult
    func submit(_ command: PlayerCommand) throws -> [GameEvent]

    /// Ends the current local room session and returns the service to a lobby-ready state.
    ///
    /// Cloud-backed services can implement this as a local navigation/session cleanup
    /// without implying reconnect or room restoration support.
    func resetLocalRoomSession()
}

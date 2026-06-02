import Foundation

protocol RoomService: AnyObject {
    var gameRoom: GameRoom? { get }
    var gameState: GameState { get }
    var snapshot: RoomSnapshot { get }
    var eventLog: [GameEvent] { get }
    var eventStream: AsyncStream<GameEvent> { get }

    @discardableResult
    func submit(_ command: PlayerCommand) throws -> [GameEvent]
}

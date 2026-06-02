import Foundation

/// Placeholder for the future cloud-backed authoritative room service.
///
/// This service will connect to the remote Finspan room API, send
/// `PlayerCommand` values to the server, receive authoritative `GameEvent`
/// values, and expose the same `RoomService` surface as the local simulator.
/// It intentionally does not open network connections in the first version.
final class OnlineRoomService: RoomService {
    var gameRoom: GameRoom? {
        nil
    }

    var gameState: GameState {
        .empty
    }

    var snapshot: RoomSnapshot {
        .empty
    }

    var eventLog: [GameEvent] {
        []
    }

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    @discardableResult
    func submit(_ command: PlayerCommand) throws -> [GameEvent] {
        throw RoomServiceError.notImplemented(
            "OnlineRoomService will submit commands to the cloud room service."
        )
    }
}

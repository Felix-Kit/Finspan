import Combine
import Foundation

@MainActor
final class GameBoardViewModel: ObservableObject {
    @Published private(set) var state: GameState = .empty
    @Published private(set) var players: [RoomPlayer] = []
    @Published private(set) var eventLog: [GameEvent] = []
    @Published private(set) var errorMessage: String?

    private let roomService: any RoomService
    private var commandCounter = 0

    var currentWeekText: String {
        state.currentWeek > 0 ? "\(state.currentWeek)" : "-"
    }

    var currentTurnText: String {
        state.phase == .playing ? "\(state.turnsCompletedThisWeek + 1) / 6" : "-"
    }

    var activePlayerName: String {
        guard let activePlayerId = state.activePlayerId else {
            return "-"
        }
        return players.first(where: { $0.playerId == activePlayerId })?.displayName ?? activePlayerId
    }

    var canEndTurn: Bool {
        state.phase == .playing && state.activePlayerId != nil
    }

    init(roomService: any RoomService) {
        self.roomService = roomService
        refresh()
    }

    func refresh() {
        state = roomService.gameState
        players = roomService.gameRoom?.players ?? []
        eventLog = roomService.eventLog
    }

    func endTurn() {
        guard let activePlayerId = state.activePlayerId else {
            errorMessage = "No active player."
            return
        }
        guard let roomId = state.roomId ?? roomService.gameRoom?.roomId else {
            errorMessage = "No active room."
            return
        }

        do {
            _ = try roomService.submit(
                PlayerCommand(
                    commandId: nextCommandId(),
                    playerId: activePlayerId,
                    roomId: roomId,
                    payload: .endTurn(EndTurnCommand())
                )
            )
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = String(describing: error)
            refresh()
        }
    }

    func eventSummary(_ event: GameEvent) -> String {
        let payload: String
        switch event.payload {
        case .roomCreated:
            payload = "Room Created"
        case let .playerJoined(event):
            payload = "Joined: \(event.player.displayName)"
        case let .playerLeft(event):
            payload = "Left: \(event.playerId)"
        case let .playerReadyChanged(event):
            payload = "Ready: \(event.playerId) \(event.isReady ? "yes" : "no")"
        case let .seatChanged(event):
            payload = "Seat: \(event.playerId) \(event.seatIndex.rawValue)"
        case let .colorChanged(event):
            payload = "Color: \(event.playerId) \(event.color.rawValue)"
        case let .gameStarted(event):
            payload = "Game Started: \(event.startingPlayerId)"
        case let .setupCompleted(event):
            payload = "Setup Completed: \(event.setup.playerStates.count) players"
        case let .fishPlayed(event):
            payload = "Fish Played: \(event.playerId) \(event.cardId)"
        case let .diverMoved(event):
            payload = "Diver Moved: \(event.playerId) \(event.destination)"
        case let .abilityOptionChosen(event):
            payload = "Ability Option: \(event.playerId) \(event.optionId)"
        case let .turnEnded(event):
            payload = "Turn Ended: \(event.playerId)"
        case let .weekEnded(event):
            payload = "Week Ended: \(event.weekNumber)"
        case .gameEnded:
            payload = "Game Ended"
        case let .snapshotCreated(event):
            payload = "Snapshot: \(event.snapshotSequenceNumber)"
        }

        return "#\(event.sequenceNumber) \(payload)"
    }

    private func nextCommandId() -> CommandID {
        commandCounter += 1
        return "game-board-command-\(commandCounter)"
    }
}

import Combine
import Foundation

@MainActor
final class LobbyViewModel: ObservableObject {
    @Published private(set) var roomCode = "-"
    @Published private(set) var hostName = "-"
    @Published private(set) var status = "No Room"
    @Published private(set) var players: [RoomPlayer] = []
    @Published var selectedPlayerId: PlayerID?
    @Published var selectedColor: PlayerColor = .blue
    @Published private(set) var errorMessage: String?

    private let roomService: any RoomService
    private let hostPlayerId: PlayerID = "host-player"
    private let hostDisplayName = "Host"
    private let roomId: RoomID = "local-room"
    private let roomCodeValue = "LOCAL"
    private var commandCounter = 0
    private var simulatedPlayerCounter = 0

    var canCreateRoom: Bool {
        roomService.gameRoom == nil
    }

    var canJoinPlayer: Bool {
        guard let room = roomService.gameRoom else {
            return false
        }
        return room.status == .waiting || room.status == .configuring
    }

    var canStartGame: Bool {
        guard let room = roomService.gameRoom else {
            return false
        }
        return room.hostPlayerId == hostPlayerId && room.status != .inProgress
    }

    init(roomService: any RoomService) {
        self.roomService = roomService
        refresh()
    }

    func createLocalRoom() {
        submit(
            PlayerCommand.createRoom(
                commandId: nextCommandId(),
                playerId: hostPlayerId,
                roomId: roomId,
                roomCode: roomCodeValue,
                displayName: hostDisplayName,
                gameConfig: GameConfig(playerCount: 4, randomSeed: 0)
            )
        )
    }

    func joinSimulatedPlayer() {
        simulatedPlayerCounter += 1
        let playerId = "sim-player-\(simulatedPlayerCounter)"
        submit(
            PlayerCommand(
                commandId: nextCommandId(),
                playerId: playerId,
                roomId: roomId,
                payload: .joinRoom(
                    JoinRoomCommand(displayName: "Player \(simulatedPlayerCounter)")
                )
            )
        )
    }

    func chooseSelectedColor() {
        guard let selectedPlayerId else {
            errorMessage = "Select a player first."
            return
        }
        submit(
            PlayerCommand(
                commandId: nextCommandId(),
                playerId: selectedPlayerId,
                roomId: roomId,
                payload: .chooseColor(ChooseColorCommand(color: selectedColor))
            )
        )
    }

    func toggleReadyForSelectedPlayer() {
        guard let selectedPlayerId else {
            errorMessage = "Select a player first."
            return
        }
        let currentReady = players.first(where: { $0.playerId == selectedPlayerId })?.isReady ?? false
        submit(
            PlayerCommand(
                commandId: nextCommandId(),
                playerId: selectedPlayerId,
                roomId: roomId,
                payload: .setReady(SetReadyCommand(isReady: !currentReady))
            )
        )
    }

    func startGameAsHost() {
        submit(
            PlayerCommand(
                commandId: nextCommandId(),
                playerId: hostPlayerId,
                roomId: roomId,
                payload: .startGame(StartGameCommand())
            )
        )
    }

    func refresh() {
        guard let room = roomService.gameRoom else {
            roomCode = "-"
            hostName = "-"
            status = "No Room"
            players = []
            selectedPlayerId = nil
            return
        }

        roomCode = room.roomCode
        hostName = room.players.first(where: { $0.playerId == room.hostPlayerId })?.displayName ?? room.hostPlayerId
        status = room.status.rawValue
        players = room.players

        if selectedPlayerId == nil || !room.players.contains(where: { $0.playerId == selectedPlayerId }) {
            selectedPlayerId = room.players.first?.playerId
        }
    }

    private func submit(_ command: PlayerCommand) {
        do {
            _ = try roomService.submit(command)
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = String(describing: error)
            refresh()
        }
    }

    private func nextCommandId() -> CommandID {
        commandCounter += 1
        return "lobby-command-\(commandCounter)"
    }
}

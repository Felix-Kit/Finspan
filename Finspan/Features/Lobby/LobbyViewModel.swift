import Combine
import Foundation

@MainActor
final class LobbyViewModel: ObservableObject {
    @Published private(set) var roomCode = "-"
    @Published private(set) var hostName = "-"
    @Published private(set) var status = AppStrings.Lobby.noRoom
    @Published private(set) var players: [RoomPlayer] = []
    @Published var selectedPlayerId: PlayerID?
    @Published var selectedColor: PlayerColor = .blue
    @Published var selectedGameDataMode: GameDataMode {
        didSet {
            configureGameDataMode(selectedGameDataMode)
        }
    }
    @Published private(set) var errorMessage: String?

    private let roomService: any RoomService
    private let gameDataController: GameDataController?
    private let hostPlayerId: PlayerID = "host-player"
    private let hostDisplayName = AppStrings.Lobby.hostName
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

    init(
        roomService: any RoomService,
        gameDataController: GameDataController? = nil
    ) {
        self.roomService = roomService
        self.gameDataController = gameDataController
        selectedGameDataMode = gameDataController?.mode
            ?? (roomService as? GameDataModeConfiguring)?.gameDataMode
            ?? .sample
        refresh()
    }

    func createLocalRoom() {
        guard configureGameDataMode(selectedGameDataMode) else {
            return
        }
        submit(
            PlayerCommand.createRoom(
                commandId: nextCommandId(),
                playerId: hostPlayerId,
                roomId: roomId,
                roomCode: roomCodeValue,
                displayName: hostDisplayName,
                gameConfig: GameConfig(
                    playerCount: 4,
                    randomSeed: 0,
                    gameDataMode: selectedGameDataMode
                )
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
                    JoinRoomCommand(displayName: "\(AppStrings.Lobby.simulatedPlayerPrefix) \(simulatedPlayerCounter)")
                )
            )
        )
    }

    func chooseSelectedColor() {
        guard let selectedPlayerId else {
            errorMessage = AppStrings.Lobby.selectPlayerFirst
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
            errorMessage = AppStrings.Lobby.selectPlayerFirst
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
        for player in players where !player.isReady && player.role != .spectator {
            submit(
                PlayerCommand(
                    commandId: nextCommandId(),
                    playerId: player.playerId,
                    roomId: roomId,
                    payload: .setReady(SetReadyCommand(isReady: true))
                )
            )
        }

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
            status = AppStrings.Lobby.noRoom
            players = []
            selectedPlayerId = nil
            return
        }

        roomCode = room.roomCode
        hostName = room.players.first(where: { $0.playerId == room.hostPlayerId })?.displayName ?? room.hostPlayerId
        status = AppStrings.roomStatusName(room.status)
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

    @discardableResult
    private func configureGameDataMode(_ mode: GameDataMode) -> Bool {
        do {
            try gameDataController?.setMode(mode)
            try (roomService as? GameDataModeConfiguring)?.setGameDataMode(mode)
            errorMessage = nil
            return true
        } catch {
            errorMessage = String(describing: error)
            return false
        }
    }

    private func nextCommandId() -> CommandID {
        commandCounter += 1
        return "lobby-command-\(commandCounter)"
    }
}

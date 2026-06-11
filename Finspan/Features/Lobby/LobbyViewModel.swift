import Combine
import Foundation

enum LobbyScreen: Equatable {
    case mainMenu
    case createRoom
    case roomLobby
    case joinGame
    case automa
}

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
    @Published var isSharksAndReefsExpansionEnabled = false
    @Published private(set) var isNautomaExpansionEnabled = false
    @Published var weeklyGoalBoardSide: AchievementBoardSide = .sideA
    @Published var weeklyGoalSelectionMode: WeeklyGoalSelectionMode = .random
    @Published var selectedWeeklyGoalIdsByWeek: [Int: WeeklyGoalID] = [:]
    @Published var screen: LobbyScreen = .mainMenu
    @Published var isProfileEditorPresented = false
    @Published var profileNicknameDraft = ""
    @Published var profileAvatarDraft = PlayerProfile.defaultAvatarSymbol
    @Published var roomNameDraft = ""
    @Published var playerCount = 4
    @Published private(set) var errorMessage: String?
    @Published private(set) var localPlayerProfile: PlayerProfile?

    private let roomService: any RoomService
    private let gameDataController: GameDataController?
    private let profileStore: PlayerProfileStore
    private let roomId: RoomID = "local-room"
    private let roomCodeValue = "LOCAL"
    private var commandCounter = 0
    private var simulatedPlayerCounter = 0
    private var roomNameCounter = 0

    var canCreateRoom: Bool {
        roomService.gameRoom == nil && weeklyGoalSetupValidationError == nil
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
        return room.hostPlayerId == localPlayerId && room.status != .inProgress
    }

    var canSelectExpansions: Bool {
        roomService.gameRoom == nil
    }

    var canSelectNautomaExpansion: Bool {
        false
    }

    var weeklyGoalSetupValidationError: String? {
        guard weeklyGoalBoardSide == .sideB,
              weeklyGoalSelectionMode == .custom
        else {
            return nil
        }
        for week in WeeklyGoalCatalog.supportedWeeks {
            guard let selectedGoalId = selectedWeeklyGoalIdsByWeek[week],
                  availableWeeklyGoalOptions(for: week).contains(where: { $0.id == selectedGoalId })
            else {
                return AppStrings.Lobby.weeklyGoalMissingSelection
            }
        }
        return nil
    }

    var requiresProfileSetup: Bool {
        localPlayerProfile == nil
    }

    var profileDisplayName: String {
        localPlayerProfile?.nickname ?? PlayerProfile.defaultNickname
    }

    var profileAvatarSymbol: String {
        localPlayerProfile?.avatarSymbol ?? PlayerProfile.defaultAvatarSymbol
    }

    var effectiveRoomName: String {
        let trimmed = roomNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AppStrings.Lobby.defaultRoomName(ownerName: profileDisplayName)
        }
        return trimmed
    }

    var createRoomValidationMessage: String? {
        weeklyGoalSetupValidationError
    }

    var canSubmitCreateRoom: Bool {
        canCreateRoom && !requiresProfileSetup && createRoomValidationMessage == nil
    }

    var roomLobbySummary: RoomLobbyViewData? {
        guard let room = roomService.gameRoom else {
            return nil
        }
        let host = room.players.first(where: { $0.playerId == room.hostPlayerId })
        return RoomLobbyViewData(
            roomName: room.gameConfig.roomName.isEmpty ? AppStrings.Lobby.unnamedRoom : room.gameConfig.roomName,
            hostName: host?.displayName ?? room.hostPlayerId,
            hostAvatarSymbol: host?.avatarSymbol ?? PlayerProfile.defaultAvatarSymbol,
            playerCountText: "\(room.players.filter { $0.role != .spectator }.count) / \(room.gameConfig.playerCount)",
            expansionText: expansionSummary(for: room.gameConfig.enabledExpansions),
            weeklyGoalSummary: weeklyGoalSetupSummary(room.gameConfig.weeklyGoalSetup),
            weeklyGoalDetails: weeklyGoalDetails(for: room.gameConfig.weeklyGoalSetup),
            players: room.players.map(roomPlayerViewData)
        )
    }

    var activeRoomSummary: JoinableRoomViewData? {
        guard let room = roomService.gameRoom,
              room.status != .finished
        else {
            return nil
        }
        return joinableRoomViewData(room)
    }

    var discoveredRooms: [JoinableRoomViewData] {
        guard let activeRoomSummary else {
            return []
        }
        return [activeRoomSummary]
    }

    init(
        roomService: any RoomService,
        gameDataController: GameDataController? = nil,
        profileStore: PlayerProfileStore? = nil
    ) {
        self.roomService = roomService
        self.gameDataController = gameDataController
        let resolvedProfileStore = profileStore ?? PlayerProfileStore()
        self.profileStore = resolvedProfileStore
        selectedGameDataMode = gameDataController?.mode
            ?? (roomService as? GameDataModeConfiguring)?.gameDataMode
            ?? .sample
        localPlayerProfile = resolvedProfileStore.profile
        resetProfileDraft()
        refresh()
    }

    func showMainMenu() {
        screen = .mainMenu
    }

    func returnToMainMenuKeepingRoom() {
        screen = .mainMenu
        errorMessage = nil
    }

    func enterActiveRoom() {
        guard roomService.gameRoom != nil else {
            errorMessage = AppStrings.Lobby.noRoom
            return
        }
        refresh()
        screen = .roomLobby
    }

    func enterRoom(_ roomId: RoomID) {
        guard roomService.gameRoom?.roomId == roomId else {
            errorMessage = AppStrings.Lobby.noRoom
            return
        }
        refresh()
        screen = .roomLobby
    }

    func dissolveCurrentRoom() {
        roomService.resetLocalRoomSession()
        screen = .mainMenu
        errorMessage = nil
        refresh()
    }

    func showCreateRoom() {
        roomNameDraft = ""
        screen = .createRoom
    }

    func showJoinGame() {
        screen = .joinGame
    }

    func showAutoma() {
        screen = .automa
    }

    func beginProfileEditing() {
        resetProfileDraft()
        isProfileEditorPresented = true
    }

    func saveProfileDraft() {
        let trimmed = profileNicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = AppStrings.Lobby.profileNicknameRequired
            return
        }
        profileStore.save(nickname: trimmed, avatarSymbol: profileAvatarDraft)
        localPlayerProfile = profileStore.profile
        isProfileEditorPresented = false
        errorMessage = nil
    }

    func randomizeRoomName() {
        roomNameDraft = RoomNameGenerator.name(at: roomNameCounter)
        roomNameCounter += 1
    }

    func createLocalRoom() {
        guard configureGameDataMode(selectedGameDataMode) else {
            return
        }
        guard !requiresProfileSetup else {
            errorMessage = AppStrings.Lobby.profileRequiredBeforeRoom
            return
        }
        if let validationError = weeklyGoalSetupValidationError {
            errorMessage = validationError
            return
        }
        submit(
            PlayerCommand.createRoom(
                commandId: nextCommandId(),
                playerId: localPlayerId,
                roomId: roomId,
                roomCode: roomCodeValue,
                displayName: profileDisplayName,
                avatarSymbol: profileAvatarSymbol,
                gameConfig: GameConfig(
                    playerCount: playerCount,
                    enabledExpansions: selectedEnabledExpansions,
                    randomSeed: 0,
                    gameDataMode: selectedGameDataMode,
                    weeklyGoalSetup: weeklyGoalSetupConfig,
                    roomName: effectiveRoomName
                )
            )
        )
        if roomService.gameRoom != nil {
            screen = .roomLobby
        }
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
                    JoinRoomCommand(
                        displayName: "\(AppStrings.Lobby.simulatedPlayerPrefix) \(simulatedPlayerCounter)",
                        avatarSymbol: PlayerProfile.defaultAvatarSymbol
                    )
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
                playerId: localPlayerId,
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

    func setNautomaExpansionEnabled(_ isEnabled: Bool) {
        isNautomaExpansionEnabled = false
    }

    func availableWeeklyGoalOptions(for week: Int) -> [WeeklyGoalOptionViewData] {
        WeeklyGoalCatalog.availableGoals(
            for: week,
            enabledExpansions: selectedEnabledExpansionsForWeeklyGoals
        )
        .map { goal in
            WeeklyGoalOptionViewData(
                id: goal.id,
                title: goal.title,
                week: goal.week,
                sourceExpansion: goal.sourceExpansion
            )
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

    private var localPlayerId: PlayerID {
        localPlayerProfile?.playerId ?? "local-player"
    }

    private var selectedEnabledExpansions: [Expansion] {
        var expansions: [Expansion] = []
        if isSharksAndReefsExpansionEnabled {
            expansions.append(.sharksAndReefs)
        }
        if isNautomaExpansionEnabled {
            expansions.append(.nautoma)
        }
        return expansions
    }

    private var selectedEnabledExpansionsForWeeklyGoals: [Expansion] {
        guard selectedGameDataMode == .baseGame else {
            return []
        }
        return selectedEnabledExpansions
    }

    private var weeklyGoalSetupConfig: WeeklyGoalSetupConfig {
        WeeklyGoalSetupConfig(
            boardSide: weeklyGoalBoardSide,
            selectionMode: weeklyGoalSelectionMode,
            selectedGoalIdsByWeek: selectedWeeklyGoalIdsByWeek
        )
    }

    private func resetProfileDraft() {
        profileNicknameDraft = localPlayerProfile?.nickname ?? ""
        profileAvatarDraft = localPlayerProfile?.avatarSymbol ?? PlayerProfile.defaultAvatarSymbol
    }

    private func expansionSummary(for expansions: [Expansion]) -> String {
        if expansions.isEmpty {
            return AppStrings.Lobby.noExpansionEnabled
        }
        return expansions.map(expansionName).joined(separator: " · ")
    }

    private func expansionName(_ expansion: Expansion) -> String {
        switch expansion {
        case .sharksAndReefs:
            return AppStrings.Lobby.sharksAndReefsExpansion
        case .nautoma:
            return AppStrings.Lobby.nautomaExpansion
        }
    }

    private func weeklyGoalSetupSummary(_ setup: WeeklyGoalSetupConfig) -> String {
        switch setup.boardSide {
        case .sideA:
            return AppStrings.Lobby.weeklyGoalSideA
        case .sideB:
            switch setup.selectionMode {
            case .random:
                return AppStrings.Lobby.weeklyGoalSideBRandomSummary
            case .custom:
                return AppStrings.Lobby.weeklyGoalSideBCustomSummary
            }
        }
    }

    private func weeklyGoalDetails(for setup: WeeklyGoalSetupConfig) -> [String] {
        guard setup.boardSide == .sideB,
              setup.selectionMode == .custom
        else {
            return []
        }
        return WeeklyGoalCatalog.supportedWeeks.compactMap { week in
            guard let goalId = setup.selectedGoalIdsByWeek[week],
                  let goal = WeeklyGoalCatalog.availableGoals(
                    for: week,
                    enabledExpansions: selectedEnabledExpansionsForWeeklyGoals
                  ).first(where: { $0.id == goalId })
            else {
                return nil
            }
            return "\(AppStrings.Lobby.weeklyGoalWeekTitle(week))：\(goal.title)"
        }
    }

    private func roomPlayerViewData(_ player: RoomPlayer) -> RoomPlayerViewData {
        RoomPlayerViewData(
            id: player.playerId,
            name: player.displayName,
            avatarSymbol: player.avatarSymbol,
            isHost: player.role == .host,
            isReady: player.isReady
        )
    }

    private func joinableRoomViewData(_ room: GameRoom) -> JoinableRoomViewData {
        let host = room.players.first(where: { $0.playerId == room.hostPlayerId })
        return JoinableRoomViewData(
            id: room.roomId,
            roomName: room.gameConfig.roomName.isEmpty ? AppStrings.Lobby.unnamedRoom : room.gameConfig.roomName,
            hostName: host?.displayName ?? room.hostPlayerId,
            hostAvatarSymbol: host?.avatarSymbol ?? PlayerProfile.defaultAvatarSymbol,
            playerCountText: "\(room.players.filter { $0.role != .spectator }.count) / \(room.gameConfig.playerCount)",
            expansionText: expansionSummary(for: room.gameConfig.enabledExpansions),
            weeklyGoalSummary: weeklyGoalSetupSummary(room.gameConfig.weeklyGoalSetup),
            isHostedByLocalPlayer: room.hostPlayerId == localPlayerId
        )
    }
}

struct WeeklyGoalOptionViewData: Identifiable, Equatable {
    let id: WeeklyGoalID
    let title: String
    let week: Int
    let sourceExpansion: Expansion?
}

struct RoomLobbyViewData: Equatable {
    let roomName: String
    let hostName: String
    let hostAvatarSymbol: String
    let playerCountText: String
    let expansionText: String
    let weeklyGoalSummary: String
    let weeklyGoalDetails: [String]
    let players: [RoomPlayerViewData]
}

struct RoomPlayerViewData: Identifiable, Equatable {
    let id: PlayerID
    let name: String
    let avatarSymbol: String
    let isHost: Bool
    let isReady: Bool
}

struct JoinableRoomViewData: Identifiable, Equatable {
    let id: RoomID
    let roomName: String
    let hostName: String
    let hostAvatarSymbol: String
    let playerCountText: String
    let expansionText: String
    let weeklyGoalSummary: String
    let isHostedByLocalPlayer: Bool
}

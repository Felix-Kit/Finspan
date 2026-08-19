import Combine
import Foundation

enum LobbyScreen: Equatable {
    case mainMenu
    case createRoom
    case roomLobby
    case joinGame
    case cardLibrary
    case automa
}

@MainActor
final class LobbyViewModel: ObservableObject {
    nonisolated static let supportedMultiplayerPlayerCounts = Array(2...5)

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
    @Published var isSharksAndReefsExpansionEnabled = false {
        didSet {
            if isSharksAndReefsExpansionEnabled {
                weeklyGoalBoardSet = .sharksAndReefs
            } else {
                weeklyGoalBoardSet = .base
            }
            selectedWeeklyGoalIdsByWeek = [:]
        }
    }
    @Published var weeklyGoalBoardSet: AchievementBoardSet = .base
    @Published var weeklyGoalBoardSide: AchievementBoardSide = .sideA
    @Published var weeklyGoalSelectionMode: WeeklyGoalSelectionMode = .random
    @Published var selectedWeeklyGoalIdsByWeek: [Int: WeeklyGoalID] = [:]
    @Published var screen: LobbyScreen = .mainMenu
    @Published var isProfileEditorPresented = false
    @Published var profileNicknameDraft = ""
    @Published var profileAvatarDraft = PlayerProfile.defaultAvatarSymbol
    @Published var roomNameDraft = ""
    @Published var playerCount = 4 {
        didSet {
            guard !Self.supportedMultiplayerPlayerCounts.contains(playerCount) else {
                return
            }
            let minimum = Self.supportedMultiplayerPlayerCounts.first ?? 2
            let maximum = Self.supportedMultiplayerPlayerCounts.last ?? 5
            playerCount = min(max(playerCount, minimum), maximum)
        }
    }
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

    var availableCreateRoomExpansions: [Expansion] { [.sharksAndReefs] }

    var availablePlayerCounts: [Int] { Self.supportedMultiplayerPlayerCounts }

    var sideAWeeklyGoalPreview: [WeeklyGoalPreviewViewData] {
        guard weeklyGoalBoardSide == .sideA else {
            return []
        }

        let weeklyGoals = WeeklyGoalCatalog.sideAGoals(for: weeklyGoalBoardSet).map { goal in
            WeeklyGoalPreviewViewData(
                id: goal.id,
                week: goal.week,
                title: goal.title,
                description: goal.description,
                scoringText: AppStrings.Lobby.weeklyGoalPointsPerUnit(goal.pointsPerUnit),
                isGameEnd: false
            )
        }
        return weeklyGoals + [
            WeeklyGoalPreviewViewData(
                id: "\(weeklyGoalBoardSet.rawValue).sideA.week4.gameEnd",
                week: 4,
                title: AppStrings.GameBoard.gameEndGoalTitle,
                description: AppStrings.GameBoard.gameEndGoalShortDescription,
                scoringText: AppStrings.GameBoard.gameEndGoalNote,
                isGameEnd: true
            )
        ]
    }

    var weeklyGoalSetupValidationError: String? {
        if weeklyGoalBoardSide == .sideB,
           weeklyGoalSelectionMode == .custom {
            for week in WeeklyGoalCatalog.supportedWeeks {
                guard let selectedGoalId = selectedWeeklyGoalIdsByWeek[week],
                      availableWeeklyGoalOptions(for: week).contains(where: { $0.id == selectedGoalId })
                else {
                    return AppStrings.Lobby.weeklyGoalMissingSelection
                }
            }
        }
        return WeeklyGoalCatalog.validationError(
            setupConfig: weeklyGoalSetupConfig,
            enabledExpansions: selectedEnabledExpansionsForWeeklyGoals
        )
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

    var hasInProgressActiveRoom: Bool {
        guard roomService.gameRoom?.status == .inProgress else {
            return false
        }
        switch roomService.gameState.phase {
        case .playing, .awaitingChoice, .weekScoring, .endGamePending, .gameEnded:
            return true
        case .lobby, .setup:
            return false
        }
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
            ?? .baseGame
        localPlayerProfile = resolvedProfileStore.profile
        resetProfileDraft()
        configureGameDataMode(selectedGameDataMode)
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

    func showCardLibrary() {
        screen = .cardLibrary
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
        if let localRoomIssue = (roomService as? LocalRoomSessionIssueReporting)?.consumeLocalRoomIssueMessage() {
            errorMessage = localRoomIssue
        }

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

    var availableWeeklyGoalBoardSets: [AchievementBoardSet] {
        isSharksAndReefsExpansionEnabled ? AchievementBoardSet.allCases : [.base]
    }

    func availableWeeklyGoalOptions(for week: Int) -> [WeeklyGoalOptionViewData] {
        WeeklyGoalCatalog.availableGoals(
            for: week,
            boardSet: weeklyGoalBoardSet,
            enabledExpansions: selectedEnabledExpansionsForWeeklyGoals
        )
        .map { goal in
            WeeklyGoalOptionViewData(
                id: goal.id,
                title: goal.title,
                shortTitle: goal.shortTitle,
                week: goal.week,
                boardSet: goal.boardSet,
                sourceExpansion: goal.sourceExpansion,
                pointsPerUnit: goal.pointsPerUnit,
                isImplementedForScoring: goal.isImplementedForScoring
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
            boardSet: weeklyGoalBoardSet,
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
        let setName = weeklyGoalBoardSetName(setup.boardSet)
        switch setup.boardSide {
        case .sideA:
            return "\(setName) · \(AppStrings.Lobby.weeklyGoalSideA)"
        case .sideB:
            switch setup.selectionMode {
            case .random:
                return "\(setName) · \(AppStrings.Lobby.weeklyGoalSideBRandomSummary)"
            case .custom:
                return "\(setName) · \(AppStrings.Lobby.weeklyGoalSideBCustomSummary)"
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
                    boardSet: setup.boardSet,
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

    private func weeklyGoalBoardSetName(_ set: AchievementBoardSet) -> String {
        switch set {
        case .base:
            return AppStrings.Lobby.weeklyGoalBaseSet
        case .sharksAndReefs:
            return AppStrings.Lobby.weeklyGoalSharksAndReefsSet
        }
    }
}

struct WeeklyGoalOptionViewData: Identifiable, Equatable {
    let id: WeeklyGoalID
    let title: String
    let shortTitle: String
    let week: Int
    let boardSet: AchievementBoardSet
    let sourceExpansion: Expansion?
    let pointsPerUnit: Int
    let isImplementedForScoring: Bool
}

struct WeeklyGoalPreviewViewData: Identifiable, Equatable {
    let id: String
    let week: Int
    let title: String
    let description: String
    let scoringText: String
    let isGameEnd: Bool
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

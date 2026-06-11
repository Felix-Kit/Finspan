import XCTest
@testable import Finspan

@MainActor
final class LobbyViewModelTests: XCTestCase {
    func testDefaultsToSampleGameDataMode() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()

        let viewModel = makeViewModel(roomService: service, gameDataController: controller)

        XCTAssertEqual(viewModel.selectedGameDataMode, .sample)
        XCTAssertEqual(controller.mode, .sample)
        XCTAssertEqual(service.gameDataMode, .sample)
    }

    func testSelectedGameDataModeIsRecordedBeforeCreatingRoom() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = makeViewModel(roomService: service, gameDataController: controller)

        viewModel.selectedGameDataMode = .baseGame

        XCTAssertEqual(viewModel.selectedGameDataMode, .baseGame)
        XCTAssertEqual(controller.mode, .baseGame)
        XCTAssertEqual(service.gameDataMode, .baseGame)
    }

    func testFirstLaunchWithoutProfileRequiresProfileSetup() {
        let viewModel = makeViewModel(profileStore: makeProfileStore())

        XCTAssertTrue(viewModel.requiresProfileSetup)
        XCTAssertFalse(viewModel.canSubmitCreateRoom)
    }

    func testSavedProfileIsLoadedByNextStore() {
        let defaults = makeProfileDefaults()
        let firstStore = PlayerProfileStore(defaults: defaults, profileKey: "profile")
        firstStore.save(nickname: "潜水员", avatarSymbol: "water.waves")

        let secondStore = PlayerProfileStore(defaults: defaults, profileKey: "profile")
        let viewModel = makeViewModel(profileStore: secondStore)

        XCTAssertFalse(viewModel.requiresProfileSetup)
        XCTAssertEqual(viewModel.profileDisplayName, "潜水员")
        XCTAssertEqual(viewModel.profileAvatarSymbol, "water.waves")
    }

    func testEditingProfileUpdatesNicknameAndAvatar() {
        let store = makeProfileStore()
        store.save(nickname: "旧昵称", avatarSymbol: "fish.circle.fill")
        let viewModel = makeViewModel(profileStore: store)

        viewModel.beginProfileEditing()
        viewModel.profileNicknameDraft = "新昵称"
        viewModel.profileAvatarDraft = "sparkles"
        viewModel.saveProfileDraft()

        XCTAssertEqual(viewModel.profileDisplayName, "新昵称")
        XCTAssertEqual(viewModel.profileAvatarSymbol, "sparkles")
        XCTAssertFalse(viewModel.isProfileEditorPresented)
    }

    func testEmptyProfileNicknameCannotBeSaved() {
        let viewModel = makeViewModel(profileStore: makeProfileStore())

        viewModel.profileNicknameDraft = "   "
        viewModel.saveProfileDraft()

        XCTAssertTrue(viewModel.requiresProfileSetup)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.Lobby.profileNicknameRequired)
    }

    func testDefaultRoomNameUsesNickname() {
        let viewModel = makeProfiledViewModel(nickname: "阿蓝")

        viewModel.showCreateRoom()

        XCTAssertEqual(viewModel.effectiveRoomName, "阿蓝的房间")
    }

    func testRandomRoomNameOnlyChangesDisplayNameNotInternalRoomId() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.showCreateRoom()
        viewModel.randomizeRoomName()
        viewModel.createLocalRoom()

        XCTAssertEqual(service.gameRoom?.roomId, "local-room")
        XCTAssertEqual(service.gameRoom?.gameConfig.roomName, RoomNameGenerator.names[0])
    }

    func testCreateLocalRoomStoresSelectedGameDataModeInGameConfig() {
        let service = LocalAuthoritativeRoomService()
        let controller = GameDataController()
        let viewModel = makeProfiledViewModel(roomService: service, gameDataController: controller)

        viewModel.selectedGameDataMode = .baseGame
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.gameDataMode, .baseGame)
        XCTAssertEqual(controller.mode, .baseGame)
        XCTAssertEqual(service.gameDataMode, .baseGame)
    }

    func testCreateLocalRoomStoresSelectedSharksAndReefsExpansionInGameConfig() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.selectedGameDataMode = .baseGame
        viewModel.isSharksAndReefsExpansionEnabled = true
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.enabledExpansions, [.sharksAndReefs])
    }

    func testSideBCanBeSelectedWithoutSharksAndReefsExpansion() {
        let viewModel = makeProfiledViewModel()

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .random

        XCTAssertTrue(viewModel.canSubmitCreateRoom)
        XCTAssertFalse(viewModel.availableWeeklyGoalOptions(for: 1).contains { $0.sourceExpansion == .sharksAndReefs })
    }

    func testSharksAndReefsOnlyExpandsSideBCandidatePool() {
        let viewModel = makeProfiledViewModel()

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.isSharksAndReefsExpansionEnabled = true

        XCTAssertTrue(viewModel.canSubmitCreateRoom)
        XCTAssertTrue(viewModel.availableWeeklyGoalOptions(for: 1).contains { $0.sourceExpansion == .sharksAndReefs })
    }

    func testWeekOnePickerOnlyOffersWeekOneGoals() {
        let viewModel = makeProfiledViewModel()
        viewModel.selectedGameDataMode = .baseGame
        viewModel.isSharksAndReefsExpansionEnabled = true

        let options = viewModel.availableWeeklyGoalOptions(for: 1)

        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { $0.week == 1 })
    }

    func testWeekTwoPickerOnlyOffersWeekTwoGoals() {
        let viewModel = makeProfiledViewModel()
        viewModel.selectedGameDataMode = .baseGame
        viewModel.isSharksAndReefsExpansionEnabled = true

        let options = viewModel.availableWeeklyGoalOptions(for: 2)

        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { $0.week == 2 })
    }

    func testWeekThreePickerOnlyOffersWeekThreeGoals() {
        let viewModel = makeProfiledViewModel()
        viewModel.selectedGameDataMode = .baseGame
        viewModel.isSharksAndReefsExpansionEnabled = true

        let options = viewModel.availableWeeklyGoalOptions(for: 3)

        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { $0.week == 3 })
    }

    func testSideBCustomRequiresEveryWeekSelectionBeforeCreateRoom() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .custom
        viewModel.selectedWeeklyGoalIdsByWeek = [
            1: "base.sideA.week1.eggsAndYoung",
            2: "base.sideA.week2.rowsOfFish"
        ]

        XCTAssertFalse(viewModel.canSubmitCreateRoom)
        viewModel.createLocalRoom()
        XCTAssertEqual(viewModel.errorMessage, AppStrings.Lobby.weeklyGoalMissingSelection)
        XCTAssertNil(service.gameRoom)
    }

    func testSideBRandomDoesNotRequireSelectedGoals() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .random
        viewModel.selectedWeeklyGoalIdsByWeek = [:]
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.boardSide, .sideB)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.selectionMode, .random)
        XCTAssertTrue(service.gameRoom?.gameConfig.weeklyGoalSetup.selectedGoalIdsByWeek.isEmpty ?? false)
    }

    func testSideBRandomRoomLobbyDoesNotRevealConcreteGoals() {
        let viewModel = makeProfiledViewModel()

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .random
        viewModel.createLocalRoom()

        XCTAssertEqual(viewModel.roomLobbySummary?.weeklyGoalSummary, AppStrings.Lobby.weeklyGoalSideBRandomSummary)
        XCTAssertEqual(viewModel.roomLobbySummary?.weeklyGoalDetails, [])
    }

    func testSideBRandomRoomListDoesNotRevealConcreteGoals() {
        let viewModel = makeProfiledViewModel()

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .random
        viewModel.createLocalRoom()

        XCTAssertEqual(viewModel.discoveredRooms.first?.weeklyGoalSummary, AppStrings.Lobby.weeklyGoalSideBRandomSummary)
    }

    func testCreateLocalRoomStoresWeeklyGoalSetupInGameConfig() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .custom
        viewModel.selectedWeeklyGoalIdsByWeek = [
            1: "base.sideA.week1.eggsAndYoung",
            2: "base.sideA.week2.rowsOfFish",
            3: "base.sideA.week3.schools"
        ]
        viewModel.createLocalRoom()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.boardSide, .sideB)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.selectionMode, .custom)
        XCTAssertEqual(service.gameRoom?.gameConfig.weeklyGoalSetup.selectedGoalIdsByWeek[3], "base.sideA.week3.schools")
    }

    func testSideBCustomRoomLobbyAndRoomListShowCustomSummary() {
        let viewModel = makeProfiledViewModel()

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .custom
        viewModel.selectedWeeklyGoalIdsByWeek = [
            1: "base.sideA.week1.eggsAndYoung",
            2: "base.sideA.week2.rowsOfFish",
            3: "base.sideA.week3.schools"
        ]
        viewModel.createLocalRoom()

        XCTAssertEqual(viewModel.roomLobbySummary?.weeklyGoalSummary, AppStrings.Lobby.weeklyGoalSideBCustomSummary)
        XCTAssertEqual(viewModel.roomLobbySummary?.weeklyGoalDetails.count, 3)
        XCTAssertEqual(viewModel.discoveredRooms.first?.weeklyGoalSummary, AppStrings.Lobby.weeklyGoalSideBCustomSummary)
    }

    func testSideAIsIndependentFromSharksAndReefsToggle() {
        let baseViewModel = makeProfiledViewModel()
        let expandedViewModel = makeProfiledViewModel()

        baseViewModel.selectedGameDataMode = .baseGame
        baseViewModel.weeklyGoalBoardSide = .sideA
        expandedViewModel.selectedGameDataMode = .baseGame
        expandedViewModel.weeklyGoalBoardSide = .sideA
        expandedViewModel.isSharksAndReefsExpansionEnabled = true

        XCTAssertTrue(baseViewModel.canSubmitCreateRoom)
        XCTAssertTrue(expandedViewModel.canSubmitCreateRoom)
    }

    func testCreateRoomEntersRoomLobbyInsteadOfStartingGame() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.createLocalRoom()

        XCTAssertEqual(viewModel.screen, .roomLobby)
        XCTAssertEqual(service.gameRoom?.status, .waiting)
        XCTAssertEqual(service.gameState.phase, .lobby)
    }

    func testReturningToMainMenuKeepsActiveRoom() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.roomNameDraft = "海马观察站"
        viewModel.createLocalRoom()
        let originalRoomId = service.gameRoom?.roomId
        viewModel.returnToMainMenuKeepingRoom()

        XCTAssertEqual(viewModel.screen, .mainMenu)
        XCTAssertEqual(service.gameRoom?.roomId, originalRoomId)
        XCTAssertEqual(service.gameRoom?.gameConfig.roomName, "海马观察站")
        XCTAssertNotNil(viewModel.activeRoomSummary)
    }

    func testMainMenuContinueRoomEntryReentersRoomLobby() {
        let viewModel = makeProfiledViewModel()

        viewModel.createLocalRoom()
        viewModel.returnToMainMenuKeepingRoom()
        viewModel.enterActiveRoom()

        XCTAssertEqual(viewModel.screen, .roomLobby)
        XCTAssertNotNil(viewModel.roomLobbySummary)
    }

    func testJoinGameBrowserShowsLocalActiveRoomAfterTemporaryExit() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.roomNameDraft = "翻车鱼潜点"
        viewModel.createLocalRoom()
        viewModel.returnToMainMenuKeepingRoom()
        viewModel.showJoinGame()

        XCTAssertEqual(viewModel.screen, .joinGame)
        XCTAssertEqual(viewModel.discoveredRooms.map(\.id), [service.gameRoom?.roomId].compactMap { $0 })
        XCTAssertEqual(viewModel.discoveredRooms.first?.roomName, "翻车鱼潜点")
        XCTAssertTrue(viewModel.discoveredRooms.first?.isHostedByLocalPlayer ?? false)
    }

    func testSelectingLocalRoomFromJoinBrowserReentersRoomLobby() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.createLocalRoom()
        let roomId = service.gameRoom!.roomId
        viewModel.returnToMainMenuKeepingRoom()
        viewModel.showJoinGame()
        viewModel.enterRoom(roomId)

        XCTAssertEqual(viewModel.screen, .roomLobby)
        XCTAssertEqual(viewModel.roomLobbySummary?.roomName, service.gameRoom?.gameConfig.roomName)
    }

    func testDissolvingRoomReturnsToMainMenuAndRemovesActiveRoom() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.createLocalRoom()
        viewModel.dissolveCurrentRoom()

        XCTAssertEqual(viewModel.screen, .mainMenu)
        XCTAssertNil(service.gameRoom)
        XCTAssertNil(viewModel.activeRoomSummary)
        XCTAssertTrue(viewModel.discoveredRooms.isEmpty)
    }

    func testDissolvedRoomDoesNotAppearInJoinBrowser() {
        let viewModel = makeProfiledViewModel()

        viewModel.createLocalRoom()
        viewModel.dissolveCurrentRoom()
        viewModel.showJoinGame()

        XCTAssertEqual(viewModel.screen, .joinGame)
        XCTAssertTrue(viewModel.discoveredRooms.isEmpty)
    }

    func testRoomLobbyShowsHostProfileAndRoomSummary() {
        let viewModel = makeProfiledViewModel(nickname: "房主", avatarSymbol: "moon.stars.fill")

        viewModel.roomNameDraft = "灯笼鱼湾"
        viewModel.isSharksAndReefsExpansionEnabled = true
        viewModel.createLocalRoom()

        XCTAssertEqual(viewModel.roomLobbySummary?.roomName, "灯笼鱼湾")
        XCTAssertEqual(viewModel.roomLobbySummary?.hostName, "房主")
        XCTAssertEqual(viewModel.roomLobbySummary?.hostAvatarSymbol, "moon.stars.fill")
        XCTAssertEqual(viewModel.roomLobbySummary?.expansionText, AppStrings.Lobby.sharksAndReefsExpansion)
    }

    func testJoinGameBrowserIsPlaceholderAndDoesNotCreateRoom() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.showJoinGame()

        XCTAssertEqual(viewModel.screen, .joinGame)
        XCTAssertTrue(viewModel.discoveredRooms.isEmpty)
        XCTAssertNil(service.gameRoom)
    }

    func testHostStartGameMovesRoomIntoInProgressGameState() {
        let service = LocalAuthoritativeRoomService(randomSeedProvider: { 42 })
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.createLocalRoom()
        viewModel.startGameAsHost()

        XCTAssertEqual(service.gameRoom?.status, .inProgress)
        XCTAssertNotEqual(service.gameState.phase, .lobby)
    }

    func testSideBRandomGoalsResolveOnlyAfterStartGame() {
        let service = LocalAuthoritativeRoomService(randomSeedProvider: { 42 })
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.selectedGameDataMode = .baseGame
        viewModel.weeklyGoalBoardSide = .sideB
        viewModel.weeklyGoalSelectionMode = .random
        viewModel.createLocalRoom()

        XCTAssertNil(service.gameState.weeklyGoals)
        XCTAssertEqual(viewModel.roomLobbySummary?.weeklyGoalDetails, [])
        XCTAssertEqual(viewModel.discoveredRooms.first?.weeklyGoalSummary, AppStrings.Lobby.weeklyGoalSideBRandomSummary)

        viewModel.startGameAsHost()

        XCTAssertEqual(service.gameState.weeklyGoals?.map(\.week), [1, 2, 3])
    }

    func testAutomaEntryIsPlaceholderAndDoesNotEnableNautoma() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.showAutoma()
        viewModel.setNautomaExpansionEnabled(true)

        XCTAssertEqual(viewModel.screen, .automa)
        XCTAssertFalse(viewModel.isNautomaExpansionEnabled)
        XCTAssertNil(service.gameRoom)
    }

    func testNautomaExpansionCannotBeEnabledFromLobby() {
        let service = LocalAuthoritativeRoomService()
        let viewModel = makeProfiledViewModel(roomService: service)

        viewModel.setNautomaExpansionEnabled(true)
        viewModel.createLocalRoom()

        XCTAssertFalse(viewModel.isNautomaExpansionEnabled)
        XCTAssertFalse(viewModel.canSelectNautomaExpansion)
        XCTAssertEqual(service.gameRoom?.gameConfig.enabledExpansions, [])
    }

    private func makeProfiledViewModel(
        roomService: LocalAuthoritativeRoomService = LocalAuthoritativeRoomService(),
        gameDataController: GameDataController = GameDataController(),
        nickname: String = "测试玩家",
        avatarSymbol: String = "fish.circle.fill"
    ) -> LobbyViewModel {
        let store = makeProfileStore()
        store.save(nickname: nickname, avatarSymbol: avatarSymbol)
        return makeViewModel(
            roomService: roomService,
            gameDataController: gameDataController,
            profileStore: store
        )
    }

    private func makeViewModel(
        roomService: LocalAuthoritativeRoomService = LocalAuthoritativeRoomService(),
        gameDataController: GameDataController = GameDataController(),
        profileStore: PlayerProfileStore? = nil
    ) -> LobbyViewModel {
        LobbyViewModel(
            roomService: roomService,
            gameDataController: gameDataController,
            profileStore: profileStore ?? makeProfileStore()
        )
    }

    private func makeProfileStore(
        suiteName: String = "FinspanTests.LobbyViewModelTests.\(#function)"
    ) -> PlayerProfileStore {
        let defaults = makeProfileDefaults(suiteName: suiteName)
        return PlayerProfileStore(defaults: defaults, profileKey: "profile")
    }

    private func makeProfileDefaults(
        suiteName: String = "FinspanTests.LobbyViewModelTests.\(#function)"
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

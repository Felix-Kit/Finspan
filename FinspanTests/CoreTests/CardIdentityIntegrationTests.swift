import XCTest
@testable import Finspan

@MainActor
final class CardIdentityIntegrationTests: XCTestCase {
    func testBaseGameSetupInitialHandsResolveInActiveCatalog() throws {
        let service = try makeStartedService(gameDataMode: .baseGame, enabledExpansions: [])
        let catalog = try CardCatalogFactory().makeCatalog(for: .baseGame, enabledExpansions: [])
        let resolver = catalog.identityResolver()
        let handIds = service.gameState.playerGameStates.values.flatMap(\.hand)

        XCTAssertFalse(handIds.isEmpty)
        XCTAssertTrue(handIds.allSatisfy { resolver.card(for: $0)?.id == $0 })
    }

    func testBaseGamePlusSharksAndReefsSetupInitialHandsResolveInActiveCatalog() throws {
        let service = try makeStartedService(gameDataMode: .baseGame, enabledExpansions: [.sharksAndReefs])
        let catalog = try CardCatalogFactory().makeCatalog(
            for: .baseGame,
            enabledExpansions: [.sharksAndReefs]
        )
        let resolver = catalog.identityResolver()
        let handIds = service.gameState.playerGameStates.values.flatMap(\.hand)

        XCTAssertFalse(handIds.isEmpty)
        XCTAssertTrue(handIds.allSatisfy { resolver.card(for: $0)?.id == $0 })
    }

    func testCanonicalCardIdentityIsSharedAcrossDeckDiscardAndConsumedFish() throws {
        let catalog = try CardCatalogFactory().makeCatalog(for: .baseGame, enabledExpansions: [])
        let resolver = catalog.identityResolver()
        let canonicalId = try XCTUnwrap(catalog.fishCards.first?.id)

        var state = GameState.empty
        state.phase = .playing
        state.players = [Player(id: "player-1", name: "玩家 1")]
        state.activePlayerId = "player-1"
        state.playerGameStates = [
            "player-1": PlayerGameState(
                playerId: "player-1",
                hand: [canonicalId],
                discardPile: [canonicalId],
                availableDivers: 6,
                usedDivers: 0,
                ocean: OceanState(
                    resources: [],
                    slots: [
                        OceanSlot(
                            address: OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0),
                            diveSiteColor: .blue,
                            content: .fishCard(canonicalId),
                            resources: [],
                            consumedFish: [ConsumedFish(cardId: canonicalId)]
                        )
                    ]
                )
            )
        ]
        state.deckState = DeckState(
            starterFishDrawPile: [canonicalId],
            fishDrawPile: [canonicalId],
            discardPile: [canonicalId]
        )

        let normalized = try state.normalizedCardIdentities(using: resolver)
        let playerState = try XCTUnwrap(normalized.playerGameStates["player-1"])
        let consumedCardId = try XCTUnwrap(playerState.ocean.slots.first?.consumedFish.first?.cardId)

        XCTAssertEqual(playerState.hand, [canonicalId])
        XCTAssertEqual(playerState.discardPile, [canonicalId])
        XCTAssertEqual(normalized.deckState.starterFishDrawPile, [canonicalId])
        XCTAssertEqual(normalized.deckState.fishDrawPile, [canonicalId])
        XCTAssertEqual(normalized.deckState.discardPile, [canonicalId])
        XCTAssertEqual(consumedCardId, canonicalId)
    }

    func testCardCatalogResolvesCanonicalAndLegacyCardIds() throws {
        let catalog = try CardCatalogFactory().makeCatalog(
            for: .baseGame,
            enabledExpansions: [.sharksAndReefs]
        )
        let resolver = catalog.identityResolver()

        XCTAssertEqual(resolver.card(for: "base.main.001")?.id, "base.main.001")
        XCTAssertEqual(resolver.card(for: "001")?.id, "base.main.001")
        XCTAssertEqual(resolver.card(for: "card_173")?.id, "sr.main.173")
        XCTAssertEqual(resolver.card(for: "173")?.id, "sr.main.173")
    }

    func testLegacyBaseCardIdIsCanonicalizedWhenRestoringSnapshot() throws {
        let snapshot = RoomSnapshot(
            id: "room-1",
            players: [],
            state: legacySnapshotState(cardId: "001"),
            events: []
        )
        let service = LocalAuthoritativeRoomService(
            gameDataMode: .baseGame,
            snapshot: snapshot,
            roomId: "room-1"
        )

        let restoredHandId = try XCTUnwrap(service.gameState.playerGameStates["player-1"]?.hand.first)

        XCTAssertEqual(restoredHandId, "base.main.001")
        XCTAssertNil(service.consumeLocalRoomIssueMessage())
    }

    func testUnsafeLegacyCardIdClearsLocalRoomInsteadOfShowingUnknownHandCard() {
        let snapshot = RoomSnapshot(
            id: "room-1",
            players: [],
            state: legacySnapshotState(cardId: "legacy-card-id"),
            events: []
        )
        let service = LocalAuthoritativeRoomService(
            gameDataMode: .baseGame,
            snapshot: snapshot,
            roomId: "room-1"
        )

        XCTAssertEqual(service.gameState, .empty)
        XCTAssertEqual(service.consumeLocalRoomIssueMessage(), AppStrings.Lobby.incompatibleLocalRoom)
    }

    func testRealCatalogSetupHandsDoNotUseUnknownCardFallback() throws {
        let service = try makeStartedService(gameDataMode: .baseGame, enabledExpansions: [.sharksAndReefs])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertFalse(viewModel.handCards.isEmpty)
        XCTAssertTrue(viewModel.handCards.allSatisfy { $0.title != AppStrings.GameBoard.unknownCard })
    }

    func testLobbyCreateRoomDefaultsToBaseGameInsteadOfSample() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let profileStore = PlayerProfileStore(defaults: defaults, profileKey: "profile")
        profileStore.save(nickname: "测试玩家", avatarSymbol: PlayerProfile.defaultAvatarSymbol)

        let roomService = LocalAuthoritativeRoomService()
        let gameDataController = GameDataController()
        let viewModel = LobbyViewModel(
            roomService: roomService,
            gameDataController: gameDataController,
            profileStore: profileStore
        )

        viewModel.createLocalRoom()

        XCTAssertEqual(roomService.gameRoom?.gameConfig.gameDataMode, .baseGame)
        XCTAssertEqual(roomService.gameDataMode, .baseGame)
    }

    private func makeStartedService(
        gameDataMode: GameDataMode,
        enabledExpansions: [Expansion]
    ) throws -> LocalAuthoritativeRoomService {
        let service = LocalAuthoritativeRoomService(
            gameDataMode: gameDataMode,
            roomId: "room-1",
            timestampProvider: { Date(timeIntervalSince1970: 1_000) },
            randomSeedProvider: { 123 }
        )

        try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(
                    playerCount: 3,
                    enabledExpansions: enabledExpansions,
                    randomSeed: 0,
                    gameDataMode: gameDataMode
                )
            )
        )

        for playerIndex in 2...3 {
            try service.submit(
                PlayerCommand(
                    commandId: "join-\(playerIndex)",
                    playerId: "player-\(playerIndex)",
                    roomId: "room-1",
                    payload: .joinRoom(JoinRoomCommand(displayName: "Player \(playerIndex)"))
                )
            )
        }

        for playerIndex in 1...3 {
            try service.submit(
                PlayerCommand(
                    commandId: "ready-\(playerIndex)",
                    playerId: "player-\(playerIndex)",
                    roomId: "room-1",
                    payload: .setReady(SetReadyCommand(isReady: true))
                )
            )
        }

        try service.submit(
            PlayerCommand(
                commandId: "start",
                playerId: "player-1",
                roomId: "room-1",
                payload: .startGame(StartGameCommand())
            )
        )

        return service
    }

    private func legacySnapshotState(cardId: CardID) -> GameState {
        GameState(
            roomId: "room-1",
            players: [Player(id: "player-1", name: "玩家 1")],
            currentWeek: 1,
            currentTurnIndex: 0,
            activePlayerId: "player-1",
            firstPlayerId: "player-1",
            phase: .playing,
            eventSequence: 1,
            randomSeed: 1,
            turnsCompletedThisWeek: 0,
            playerGameStates: [
                "player-1": PlayerGameState(
                    playerId: "player-1",
                    hand: [cardId],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: .baseGameInitial(for: "player-1")
                )
            ],
            deckState: .empty,
            pendingChoices: [:],
            activeDiveQueue: nil,
            weeklyGoals: nil,
            weeklyAchievementResults: [],
            activatedGameEndAbilitySourceIds: [],
            finalScoreResult: nil
        )
    }
}

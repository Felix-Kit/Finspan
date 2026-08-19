import XCTest
@testable import Finspan

@MainActor
final class PlayerBoardPerspectiveTests: XCTestCase {
    func testDefaultViewingPlayerIsLocalActionPlayer() {
        let service = PerspectiveFixture.makeService()
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        XCTAssertEqual(viewModel.activePlayerId, PerspectiveFixture.localPlayerId)
        XCTAssertEqual(viewModel.localPlayerId, PerspectiveFixture.localPlayerId)
        XCTAssertEqual(viewModel.viewingPlayerId, PerspectiveFixture.localPlayerId)
        XCTAssertFalse(viewModel.isViewingOpponentBoard)
    }

    func testActivePlayerDoesNotChangeWhenViewingOpponent() {
        let service = PerspectiveFixture.makeService()
        let originalState = service.gameState
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)

        XCTAssertEqual(service.gameState, originalState)
        XCTAssertEqual(viewModel.activePlayerId, PerspectiveFixture.localPlayerId)
        XCTAssertEqual(viewModel.viewingPlayerId, PerspectiveFixture.opponentPlayerId)
        XCTAssertTrue(viewModel.isViewingOpponentBoard)
    }
}

@MainActor
final class PlayerAvatarSelectionTests: XCTestCase {
    func testAvatarSelectionMarksViewingPlayerSeparatelyFromActivePlayer() {
        let service = PerspectiveFixture.makeService()
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)

        let playerHud = viewModel.gameHudViewState.playerHud
        XCTAssertEqual(playerHud.viewingPlayerId, PerspectiveFixture.opponentPlayerId)
        XCTAssertEqual(playerHud.viewingPlayerName, "玩家 2")
        XCTAssertEqual(playerHud.perspectiveMessage, AppStrings.GameBoard.viewingPlayerBoard(name: "玩家 2"))
        XCTAssertTrue(playerHud.isViewingOpponentBoard)
        XCTAssertEqual(playerHud.players.first { $0.playerId == PerspectiveFixture.localPlayerId }?.isActive, true)
        XCTAssertEqual(playerHud.players.first { $0.playerId == PerspectiveFixture.localPlayerId }?.isViewing, false)
        XCTAssertEqual(playerHud.players.first { $0.playerId == PerspectiveFixture.opponentPlayerId }?.isActive, false)
        XCTAssertEqual(playerHud.players.first { $0.playerId == PerspectiveFixture.opponentPlayerId }?.isViewing, true)
    }

    func testReturnToLocalPlayerRestoresOwnBoardPerspective() {
        let service = PerspectiveFixture.makeService()
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)
        viewModel.returnToLocalPlayerBoard()

        XCTAssertEqual(viewModel.viewingPlayerId, PerspectiveFixture.localPlayerId)
        XCTAssertFalse(viewModel.isViewingOpponentBoard)
        XCTAssertNil(viewModel.gameHudViewState.playerHud.perspectiveMessage)
    }

    func testViewingPlayerChangesNeverSubmitCommandsOrMutateGameState() {
        let service = PerspectiveFixture.makeService()
        let originalState = service.gameState
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)
        viewModel.returnToLocalPlayerBoard()

        XCTAssertEqual(service.gameState, originalState)
        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.activePlayerId, PerspectiveFixture.localPlayerId)
        XCTAssertEqual(viewModel.localPlayerId, PerspectiveFixture.localPlayerId)
        XCTAssertEqual(viewModel.viewingPlayerId, PerspectiveFixture.localPlayerId)
    }
}

@MainActor
final class OpponentBoardViewTests: XCTestCase {
    func testOpponentBoardIsShownReadOnly() throws {
        let service = PerspectiveFixture.makeService()
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)

        XCTAssertTrue(viewModel.oceanSlots.allSatisfy { $0.address.playerId == PerspectiveFixture.opponentPlayerId })
        let opponentSlot = try XCTUnwrap(viewModel.oceanSlots.first { $0.address == PerspectiveFixture.opponentResourceAddress })
        XCTAssertTrue(opponentSlot.isReadOnly)
        XCTAssertEqual(opponentSlot.readOnlyReasonText, AppStrings.GameBoard.readOnlyBoard)
    }

    func testOpponentBoardCannotBePlayFishTarget() {
        let service = PerspectiveFixture.makeService()
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectHandCard(PerspectiveFixture.eggCostCardId)
        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)
        viewModel.selectTargetSlot(PerspectiveFixture.opponentEmptyAddress)

        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.returnToOwnBoardToChooseTarget)
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    func testOpponentResourcesCannotBeSelectedAsPaymentSource() throws {
        let service = PerspectiveFixture.makeService()
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectHandCard(PerspectiveFixture.eggCostCardId)
        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)
        viewModel.toggleResourcePayment(address: PerspectiveFixture.opponentResourceAddress, kind: .egg)

        let opponentSlot = try XCTUnwrap(viewModel.oceanSlots.first { $0.address == PerspectiveFixture.opponentResourceAddress })
        let eggToken = try XCTUnwrap(opponentSlot.resourceTokens.first { $0.kind == .egg })
        XCTAssertFalse(eggToken.isSelectable)
        XCTAssertFalse(eggToken.isSelectedForPayment)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.returnToOwnBoardToChoosePayment)
    }

    func testOpponentBoardCannotStagePendingRewardTarget() {
        let choice = PerspectiveFixture.placeEggPendingChoice()
        let service = PerspectiveFixture.makeService(pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)
        let token = viewModel.rewardPoolViewState.rewards[0]

        viewModel.selectRewardToken(token.id)
        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)

        XCTAssertEqual(
            viewModel.boardInteractionPromptViewState?.text,
            AppStrings.GameBoard.returnToOwnBoardToChooseTarget
        )

        viewModel.selectTargetSlot(PerspectiveFixture.opponentResourceAddress)

        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.returnToOwnBoardToChooseTarget)
        XCTAssertEqual(viewModel.bottomRewardDockState.warningText, AppStrings.GameBoard.returnToOwnBoardToChooseTarget)
    }

    func testViewingOpponentDoesNotExposeOpponentHand() {
        let service = PerspectiveFixture.makeService()
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)

        XCTAssertEqual(viewModel.handViewState.cards.map(\.cardId), [
            PerspectiveFixture.eggCostCardId,
            PerspectiveFixture.freeCardId
        ])
        XCTAssertFalse(viewModel.handViewState.cards.map(\.cardId).contains(PerspectiveFixture.opponentHandCardId))
        XCTAssertEqual(viewModel.handViewState.perspectiveMessage, AppStrings.GameBoard.handRemainsOwnWhileViewingOpponent)
    }
}

@MainActor
final class BottomDockPerspectiveTests: XCTestCase {
    func testPendingDockContextPersistsWhileViewingOpponentAndPromptsReturn() {
        let choice = PerspectiveFixture.placeEggPendingChoice()
        let service = PerspectiveFixture.makeService(pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        let initialTokens = viewModel.bottomRewardDockState.tokens
        viewModel.selectPlayerAvatar(PerspectiveFixture.opponentPlayerId)

        XCTAssertEqual(viewModel.bottomRewardDockState.tokens, initialTokens)
        XCTAssertEqual(viewModel.bottomRewardDockState.warningText, AppStrings.GameBoard.returnToOwnBoardToChooseTarget)
        XCTAssertFalse(viewModel.bottomRewardDockState.usesMainBoardRightPanel)
    }
}

@MainActor
final class AllPlayersSourcePerspectiveTests: XCTestCase {
    func testAllPlayersTargetDockSourceSummaryCanSwitchToSourcePlayerBoard() {
        var choice = PerspectiveFixture.placeEggPendingChoice(
            choiceId: "all-players-target",
            source: .allPlayers
        )
        choice.allPlayersProgress = AllPlayersAbilityProgress(
            abilityId: "all-players-place-egg",
            sourcePlayerId: PerspectiveFixture.opponentPlayerId,
            sourceCardId: PerspectiveFixture.sourceFishCardId,
            sourceAddress: PerspectiveFixture.opponentSourceAddress,
            baseChoiceId: "all-players-base",
            currentTargetPlayerId: PerspectiveFixture.localPlayerId,
            remainingPlayerIds: [PerspectiveFixture.localPlayerId]
        )
        let service = PerspectiveFixture.makeService(pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        XCTAssertEqual(viewModel.bottomRewardDockState.sourcePlayerId, PerspectiveFixture.opponentPlayerId)

        viewModel.performBottomRewardDockAction(.viewSourcePlayer(PerspectiveFixture.opponentPlayerId))

        XCTAssertEqual(viewModel.viewingPlayerId, PerspectiveFixture.opponentPlayerId)
        XCTAssertEqual(viewModel.highlightedViewedSourceSlot, PerspectiveFixture.opponentSourceAddress)
        XCTAssertFalse(service.submittedCommands.contains { command in
            if case .resolvePendingChoice = command.payload {
                return true
            }
            return false
        })
    }

    func testAllPlayersTargetSkipDoesNotImplyOtherPlayersSkipInPresentation() {
        var choice = PerspectiveFixture.placeEggPendingChoice(
            choiceId: "all-players-target",
            source: .allPlayers
        )
        choice.allPlayersProgress = AllPlayersAbilityProgress(
            abilityId: "all-players-place-egg",
            sourcePlayerId: PerspectiveFixture.opponentPlayerId,
            sourceCardId: PerspectiveFixture.sourceFishCardId,
            sourceAddress: PerspectiveFixture.opponentSourceAddress,
            baseChoiceId: "all-players-base",
            currentTargetPlayerId: PerspectiveFixture.localPlayerId,
            remainingPlayerIds: [PerspectiveFixture.localPlayerId, "player-3"],
            resolvedPlayerIds: [],
            skippedPlayerIds: []
        )
        let service = PerspectiveFixture.makeService(pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        viewModel.skipPendingChoice(choice.choiceId)

        guard let command = service.submittedCommands.last else {
            return XCTFail("Expected current target player's skip command.")
        }
        XCTAssertEqual(command.playerId, PerspectiveFixture.localPlayerId)
        switch command.payload {
        case let .resolvePendingChoice(payload):
            XCTAssertEqual(payload.choiceId, choice.choiceId)
            XCTAssertEqual(payload.resolution, .skip)
        case let .skipEffectNode(payload):
            XCTAssertEqual(payload.sourcePlayerId, PerspectiveFixture.opponentPlayerId)
            XCTAssertEqual(payload.targetPlayerId, PerspectiveFixture.localPlayerId)
        case let .skipEffectExecution(payload):
            XCTAssertEqual(payload.sourcePlayerId, PerspectiveFixture.opponentPlayerId)
            XCTAssertEqual(payload.targetPlayerId, PerspectiveFixture.localPlayerId)
        default:
            XCTFail("Expected a pending skip command.")
        }
        XCTAssertEqual(service.gameState.pendingChoices[choice.choiceId]?.allPlayersProgress?.skippedPlayerIds, [])
        XCTAssertEqual(service.gameState.pendingChoices[choice.choiceId]?.allPlayersProgress?.remainingPlayerIds, [
            PerspectiveFixture.localPlayerId,
            "player-3"
        ])
    }
}

@MainActor
final class GameEndPerspectiveTests: XCTestCase {
    func testGameEndCandidateDockSourceCanSwitchToSourcePlayerBoard() throws {
        let service = PerspectiveFixture.makeService(
            phase: .endGamePending,
            currentWeek: 4,
            activePlayerId: nil
        )
        PerspectiveFixture.setContent(
            .fishCard(PerspectiveFixture.gameEndCardId),
            at: PerspectiveFixture.opponentSourceAddress,
            in: service
        )
        let viewModel = GameBoardViewModel(roomService: service, cardCatalog: PerspectiveFixture.catalog)

        let dock = viewModel.bottomRewardDockState
        XCTAssertEqual(dock.sourcePlayerId, PerspectiveFixture.opponentPlayerId)
        XCTAssertFalse(dock.tokens.isEmpty)

        viewModel.performBottomRewardDockAction(.viewSourcePlayer(PerspectiveFixture.opponentPlayerId))

        XCTAssertEqual(viewModel.viewingPlayerId, PerspectiveFixture.opponentPlayerId)
        XCTAssertEqual(viewModel.highlightedViewedSourceSlot, PerspectiveFixture.opponentSourceAddress)
        XCTAssertNotNil(viewModel.gameEndAbilityPhaseViewState)
    }
}

@MainActor
private enum PerspectiveFixture {
    static let localPlayerId: PlayerID = "player-1"
    static let opponentPlayerId: PlayerID = "player-2"
    static let eggCostCardId: CardID = "fixture.egg-cost"
    static let freeCardId: CardID = "fixture.free-card"
    static let opponentHandCardId: CardID = "fixture.opponent-hand"
    static let sourceFishCardId: CardID = "fixture.source-fish"
    static let gameEndCardId: CardID = "fixture.game-end"
    static let ownEmptyAddress = OceanSlotAddress(playerId: localPlayerId, diveSite: .blue, rowIndex: 1)
    static let opponentEmptyAddress = OceanSlotAddress(playerId: opponentPlayerId, diveSite: .blue, rowIndex: 1)
    static let ownResourceAddress = OceanSlotAddress(playerId: localPlayerId, diveSite: .purple, rowIndex: 3)
    static let opponentResourceAddress = OceanSlotAddress(playerId: opponentPlayerId, diveSite: .purple, rowIndex: 3)
    static let opponentSourceAddress = OceanSlotAddress(playerId: opponentPlayerId, diveSite: .blue, rowIndex: 0)

    static let catalog = PerspectiveTestCardCatalog(
        fishCards: [
            Card(
                id: eggCostCardId,
                name: "Egg Cost Fish",
                costs: [.resource(kind: .egg, count: 1)],
                printedPoints: 1,
                lengthCm: 20
            ),
            Card(
                id: freeCardId,
                name: "Free Fish",
                printedPoints: 1,
                lengthCm: 10
            ),
            Card(
                id: opponentHandCardId,
                name: "Opponent Hand Fish",
                printedPoints: 1,
                lengthCm: 10
            ),
            Card(
                id: sourceFishCardId,
                name: "Source Fish",
                printedPoints: 1,
                lengthCm: 30
            ),
            Card(
                id: gameEndCardId,
                name: "Perspective Game End Fish",
                abilityIds: [SharksAndReefsAbilityIDs.greenCoralThreeGameEnd],
                abilityText: "游戏结束：获得 3 个绿色珊瑚",
                printedPoints: 1,
                lengthCm: 25
            )
        ]
    )

    static func makeService(
        phase: GamePhase = .playing,
        currentWeek: Int = 1,
        activePlayerId: PlayerID? = "player-1",
        pendingChoices: [PendingChoiceID: PendingChoice] = [:]
    ) -> PerspectiveRoomService {
        var localOcean = OceanState.baseGameInitial(for: localPlayerId)
        var opponentOcean = OceanState.baseGameInitial(for: opponentPlayerId)
        setSlotContent(.empty, at: ownEmptyAddress, in: &localOcean)
        setSlotContent(.empty, at: opponentEmptyAddress, in: &opponentOcean)
        setSlotResources([ResourceQuantity(kind: .egg, amount: 1)], at: ownResourceAddress, in: &localOcean)
        setSlotResources([ResourceQuantity(kind: .egg, amount: 1)], at: opponentResourceAddress, in: &opponentOcean)
        setSlotContent(.fishCard(sourceFishCardId), at: opponentSourceAddress, in: &opponentOcean)

        let roomPlayers = [
            RoomPlayer(playerId: localPlayerId, displayName: "玩家 1", role: .host),
            RoomPlayer(playerId: opponentPlayerId, displayName: "玩家 2", color: .green)
        ]
        let statePlayers = [
            Player(id: localPlayerId, name: "玩家 1"),
            Player(id: opponentPlayerId, name: "玩家 2")
        ]
        let gameState = GameState(
            roomId: "room-1",
            players: statePlayers,
            currentWeek: currentWeek,
            currentTurnIndex: 0,
            activePlayerId: activePlayerId,
            firstPlayerId: localPlayerId,
            phase: phase,
            eventSequence: 1,
            randomSeed: 1,
            turnsCompletedThisWeek: 0,
            playerGameStates: [
                localPlayerId: PlayerGameState(
                    playerId: localPlayerId,
                    hand: [eggCostCardId, freeCardId],
                    discardPile: [],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: localOcean
                ),
                opponentPlayerId: PlayerGameState(
                    playerId: opponentPlayerId,
                    hand: [opponentHandCardId],
                    discardPile: [],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: opponentOcean
                )
            ],
            deckState: .empty,
            pendingChoices: pendingChoices,
            activeDiveQueue: nil
        )
        return PerspectiveRoomService(
            gameRoom: GameRoom(
                roomId: "room-1",
                roomCode: "LOCAL",
                hostPlayerId: localPlayerId,
                players: roomPlayers,
                gameConfig: GameConfig(playerCount: 2, enabledExpansions: [.sharksAndReefs], randomSeed: 1),
                createdAt: Date(timeIntervalSince1970: 1_000),
                updatedAt: Date(timeIntervalSince1970: 1_000)
            ),
            gameState: gameState
        )
    }

    static func placeEggPendingChoice(
        choiceId: PendingChoiceID = "choice-place-egg",
        source: PendingChoiceSource = .fishAbility("fixture.source-fish")
    ) -> PendingChoice {
        PendingChoice(
            choiceId: choiceId,
            playerId: localPlayerId,
            source: source,
            kind: .placeEgg,
            options: [],
            expectedInput: .targetSlot,
            isOptional: true,
            abilityDefinition: AbilityDefinition(
                abilityId: "fixture-place-egg",
                trigger: .ifActivated,
                effects: [.placeEgg(count: 1)],
                isOptional: true,
                displayText: "发动时：放置 1 个鱼卵"
            ),
            createdAtSequence: 2
        )
    }

    static func setContent(_ content: OceanSlotContent, at address: OceanSlotAddress, in service: PerspectiveRoomService) {
        guard var playerState = service.gameState.playerGameStates[address.playerId] else {
            return
        }
        setSlotContent(content, at: address, in: &playerState.ocean)
        service.gameState.playerGameStates[address.playerId] = playerState
        service.refreshSnapshot()
    }

    private static func setSlotContent(_ content: OceanSlotContent, at address: OceanSlotAddress, in ocean: inout OceanState) {
        guard let slotIndex = ocean.slots.firstIndex(where: { $0.address == address }) else {
            return
        }
        ocean.slots[slotIndex].content = content
    }

    private static func setSlotResources(_ resources: [ResourceQuantity], at address: OceanSlotAddress, in ocean: inout OceanState) {
        guard let slotIndex = ocean.slots.firstIndex(where: { $0.address == address }) else {
            return
        }
        ocean.slots[slotIndex].resources = resources
    }
}

private final class PerspectiveRoomService: RoomService {
    var gameRoom: GameRoom?
    var gameState: GameState
    var snapshot: RoomSnapshot
    var eventLog: [GameEvent] = []
    var submittedCommands: [PlayerCommand] = []

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    init(gameRoom: GameRoom, gameState: GameState) {
        self.gameRoom = gameRoom
        self.gameState = gameState
        self.snapshot = RoomSnapshot(
            id: gameRoom.roomId,
            players: gameRoom.players,
            state: gameState,
            events: []
        )
    }

    @discardableResult
    func submit(_ command: PlayerCommand) throws -> [GameEvent] {
        submittedCommands.append(command)
        return []
    }

    func resetLocalRoomSession() {
        gameRoom = nil
        gameState = .empty
        refreshSnapshot()
        eventLog = []
        submittedCommands = []
    }

    func refreshSnapshot() {
        snapshot = RoomSnapshot(
            id: gameRoom?.roomId ?? "",
            players: gameRoom?.players ?? [],
            state: gameState,
            events: []
        )
    }
}

private struct PerspectiveTestCardCatalog: CardCatalog {
    var starterFishCards: [Card] = []
    var fishCards: [Card]
}

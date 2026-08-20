import CoreGraphics
import XCTest
@testable import Finspan

@MainActor
final class FloatingActionPairViewModelTests: XCTestCase {
    func testStagedPlayFishShowsFloatingActionPairAndHidesControlOnlyDock() throws {
        let service = FloatingActionRoomService(hand: ["floating-fish"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)

        viewModel.selectCard("floating-fish")
        viewModel.selectTargetSlot(target)

        let floating = try XCTUnwrap(viewModel.floatingActionPairState)
        XCTAssertEqual(floating.context, .playFish)
        XCTAssertEqual(floating.leading?.action, .back)
        XCTAssertEqual(floating.trailing?.action, .primary)
        XCTAssertTrue(floating.trailing?.isEnabled == true)
        XCTAssertTrue(floating.avoidsHomeIndicator)
        XCTAssertTrue(floating.avoidsHandArea)
        XCTAssertGreaterThanOrEqual(floating.layoutMetrics.bottomClearance, floating.layoutMetrics.handAvoidanceHeight)
        XCTAssertGreaterThanOrEqual(floating.layoutMetrics.trailingClearance, 44)
        XCTAssertEqual(viewModel.bottomRewardDockState.displayMode, .hidden)
        XCTAssertNil(viewModel.bottomRewardDockState.forwardControl)
        XCTAssertNil(viewModel.bottomRewardDockState.backControl)
    }

    func testFloatingActionPairDisappearsWithoutActiveStagedOrPendingContext() {
        let service = FloatingActionRoomService(hand: ["floating-fish"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )

        XCTAssertNil(viewModel.floatingActionPairState)
        XCTAssertEqual(viewModel.bottomRewardDockState.displayMode, .hidden)
    }

    func testFloatingBackClearsOnlyUnsubmittedStagedSelection() {
        let service = FloatingActionRoomService(hand: ["floating-fish"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        viewModel.selectCard("floating-fish")
        viewModel.selectTargetSlot(target)

        viewModel.performBottomRewardDockAction(.back)

        XCTAssertNil(viewModel.selectedCardId)
        XCTAssertNil(viewModel.selectedTargetSlot)
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    func testFloatingForwardUsesExistingPlayFishCommandPath() throws {
        let service = FloatingActionRoomService(hand: ["floating-fish"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        viewModel.selectCard("floating-fish")
        viewModel.selectTargetSlot(target)

        viewModel.performBottomRewardDockAction(.primary)

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }
        XCTAssertEqual(payload.cardId, "floating-fish")
        XCTAssertEqual(payload.targetSlot, target)
        XCTAssertEqual(payload.payment, .empty)
    }

    func testFloatingBackAfterCommitDoesNotCreateEngineUndo() {
        let service = FloatingActionRoomService(hand: ["floating-fish"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        viewModel.selectCard("floating-fish")
        viewModel.selectTargetSlot(target)
        viewModel.performBottomRewardDockAction(.primary)

        viewModel.performBottomRewardDockAction(.back)

        XCTAssertEqual(service.submittedCommands.count, 1)
        guard case .playFish = service.submittedCommands.first?.payload else {
            return XCTFail("Expected the committed command to remain playFish.")
        }
    }

    func testOverlayPresentationHidesGlobalFloatingActionPair() throws {
        let service = FloatingActionRoomService(
            hand: ["floating-fish"],
            discardPile: ["floating-fish"]
        )
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        viewModel.selectCard("floating-fish")
        viewModel.selectTargetSlot(target)
        XCTAssertNotNil(viewModel.floatingActionPairState)

        viewModel.showDiscardPile()

        XCTAssertNotNil(viewModel.discardPileDetailViewState)
        XCTAssertNil(viewModel.floatingActionPairState)
    }

    func testViewingOpponentBoardPreservesFloatingControlContext() throws {
        let service = FloatingActionRoomService(
            hand: ["floating-fish"],
            additionalPlayers: [
                RoomPlayer(playerId: "player-2", displayName: "玩家 2", color: .green)
            ]
        )
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )
        let target = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 1)
        viewModel.selectCard("floating-fish")
        viewModel.selectTargetSlot(target)

        viewModel.selectPlayerAvatar("player-2")

        let floating = try XCTUnwrap(viewModel.floatingActionPairState)
        XCTAssertEqual(floating.context, .playFish)
        XCTAssertEqual(viewModel.selectedViewedPlayerId, "player-2")
        XCTAssertEqual(viewModel.selectedCardId, "floating-fish")
        XCTAssertEqual(viewModel.selectedTargetSlot, target)
    }

    func testRewardTokenDockRemainsInformationalDockContent() {
        let token = BottomRewardDockToken(
            id: "reward-egg",
            title: "放置鱼卵",
            subtitle: "选择目标",
            icon: GameTokenIconResolver.shared.icon(for: .egg),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: nil,
            continuationSurfaces: [.boardTarget],
            action: .selectRewardToken("reward-egg")
        )
        let state = BottomRewardDockState(
            displayMode: .compact,
            title: "奖励",
            sourceText: nil,
            instructionText: "选择奖励",
            summaryLines: [],
            tokens: [token],
            warningText: nil,
            fallbackReason: nil,
            forwardControl: nil,
            backControl: nil
        )

        XCTAssertTrue(state.hasInformationalContent)
        XCTAssertEqual(state.displayMode, .compact)
        XCTAssertFalse(state.usesMainBoardRightPanel)
    }
}

@MainActor
final class BoardLayoutMappingTests: XCTestCase {
    func testBoardImageRectAspectFitCentersNarrowImage() {
        let rect = BoardLayoutMapper.boardImageRect(
            in: CGSize(width: 1_000, height: 500),
            imageAspectRatio: 1
        )

        XCTAssertEqual(rect.origin.x, 250, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(rect.width, 500, accuracy: 0.001)
        XCTAssertEqual(rect.height, 500, accuracy: 0.001)
    }

    func testBoardImageRectAspectFitFillsMatchingContainer() {
        let rect = BoardLayoutMapper.boardImageRect(
            in: CGSize(width: 1_000, height: 500),
            imageAspectRatio: 2
        )

        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(rect.width, 1_000, accuracy: 0.001)
        XCTAssertEqual(rect.height, 500, accuracy: 0.001)
    }

    func testNormalizedRectAndPointMappingStayInsideBoardImageRect() {
        let boardRect = CGRect(x: 100, y: 50, width: 800, height: 450)
        let normalizedRect = BoardNormalizedRect(x: 0.25, y: 0.2, width: 0.5, height: 0.4)
        let mappedRect = BoardLayoutMapper.mapBoardNormalizedRect(normalizedRect, into: boardRect)
        let mappedPoint = BoardLayoutMapper.mapBoardNormalizedPoint(
            BoardNormalizedPoint(x: 0.5, y: 0.5),
            into: boardRect
        )

        XCTAssertTrue(boardRect.contains(mappedRect))
        XCTAssertTrue(boardRect.contains(mappedPoint))
        XCTAssertEqual(mappedRect.origin.x, 300, accuracy: 0.001)
        XCTAssertEqual(mappedRect.origin.y, 140, accuracy: 0.001)
        XCTAssertEqual(mappedPoint.x, 500, accuracy: 0.001)
        XCTAssertEqual(mappedPoint.y, 275, accuracy: 0.001)
    }

    func testFallbackPlayerMatLayoutContainsBaseGameSlotsAndSharedRects() {
        let layout = BoardLayout.placeholderBaseGame
        let boardRect = CGRect(x: 0, y: 0, width: 1_850, height: 3_454)

        XCTAssertEqual(layout.slots.count, 18)
        XCTAssertNotNil(layout.slot(id: "blue.sunlit.0"))
        XCTAssertNotNil(layout.slot(id: "purple.twilight.0"))
        XCTAssertNotNil(layout.slot(id: "green.midnight.1"))

        for slot in layout.slots {
            let slotRect = BoardLayoutMapper.mapBoardNormalizedRect(slot.slotRect, into: boardRect)
            let cardRect = BoardLayoutMapper.mapBoardNormalizedRect(slot.cardRect, into: boardRect)
            let hitRect = BoardLayoutMapper.mapBoardNormalizedRect(slot.hitRect, into: boardRect)
            let highlightRect = BoardLayoutMapper.mapBoardNormalizedRect(slot.highlightRect, into: boardRect)

            XCTAssertTrue(boardRect.contains(slotRect), slot.slotId)
            XCTAssertTrue(boardRect.contains(cardRect), slot.slotId)
            XCTAssertTrue(boardRect.contains(hitRect), slot.slotId)
            XCTAssertTrue(boardRect.contains(highlightRect), slot.slotId)
        }
    }

    func testBoardLayoutJsonDecodes() throws {
        let url = try boardLayoutJsonURL()
        let data = try Data(contentsOf: url)
        let layout = try JSONDecoder().decode(BoardLayout.self, from: data)

        XCTAssertEqual(layout.id, "base.player-mat.rulebook.v1")
        XCTAssertEqual(layout.imageAspectRatio, 1_850.0 / 3_454.0, accuracy: 0.000_001)
        XCTAssertEqual(layout.backgroundAssetName, "base_player_mat_clean")
        XCTAssertEqual(layout.includesPrintedForageFish, true)
        XCTAssertEqual(layout.slots.count, 18)
        XCTAssertNotNil(layout.slot(id: "blue.sunlit.0"))
    }

    func testPlayerMatCardRectsMatchFishCardRatioAndCoverPrintedSlots() throws {
        let data = try Data(contentsOf: boardLayoutJsonURL())
        let layout = try JSONDecoder().decode(BoardLayout.self, from: data)
        let boardRect = CGRect(x: 0, y: 0, width: 1_850, height: 3_454)

        for slot in layout.slots {
            let slotRect = BoardLayoutMapper.mapBoardNormalizedRect(slot.slotRect, into: boardRect)
            let cardRect = BoardLayoutMapper.mapBoardNormalizedRect(slot.cardRect, into: boardRect)
            XCTAssertEqual(
                cardRect.width / cardRect.height,
                CardRenderMetrics.cardAspectRatio,
                accuracy: 0.01,
                slot.slotId
            )
            XCTAssertGreaterThan(cardRect.width / slotRect.width, 0.99, slot.slotId)
            XCTAssertGreaterThan(cardRect.height / slotRect.height, 0.98, slot.slotId)
        }
    }

    func testPlayerMatAssetsAndSharksAndReefsOverlayAreBundledInputs() throws {
        let data = try Data(contentsOf: boardLayoutJsonURL())
        let layout = try JSONDecoder().decode(BoardLayout.self, from: data)
        let overlayRect = try XCTUnwrap(layout.coralOverlayRect)

        XCTAssertEqual(layout.coralOverlayAssetName, "sharks_reefs_coral_overlay_aligned")
        XCTAssertEqual(overlayRect.y, 1_728.0 / 3_454.0, accuracy: 0.000_001)
        XCTAssertEqual(overlayRect.maxY, 1_909.0 / 3_454.0, accuracy: 0.000_001)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try resourceURL("BoardAssets/base_player_mat_clean.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try resourceURL("BoardAssets/sharks_reefs_coral_overlay_aligned.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try resourceURL("BoardAssets/board_token_egg_orange.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try resourceURL("BoardAssets/board_token_young_yellow.png").path))
    }

    func testStandaloneBoardRasterAssetsResolveFromHostedAppBundle() throws {
        let backgroundURL = try XCTUnwrap(
            BoardImageAssetResolver.resourceURL(named: "base_player_mat_clean", bundle: .main)
        )
        let overlayURL = try XCTUnwrap(
            BoardImageAssetResolver.resourceURL(named: "sharks_reefs_coral_overlay_aligned", bundle: .main)
        )

        XCTAssertEqual(backgroundURL.lastPathComponent, "base_player_mat_clean.png")
        XCTAssertEqual(overlayURL.lastPathComponent, "sharks_reefs_coral_overlay_aligned.png")
        XCTAssertNotNil(BoardImageAssetResolver.image(named: "base_player_mat_clean", bundle: .main))
        XCTAssertNotNil(BoardImageAssetResolver.image(named: "sharks_reefs_coral_overlay_aligned", bundle: .main))
    }

    func testCoralPiecesFillPrintedSpacesWithoutNumericProgressBadge() throws {
        let data = try Data(contentsOf: boardLayoutJsonURL())
        let layout = try JSONDecoder().decode(BoardLayout.self, from: data)
        let boardRect = CGRect(x: 0, y: 0, width: 1_850, height: 3_454)
        let overlayRect = BoardLayoutMapper.mapBoardNormalizedRect(
            try XCTUnwrap(layout.coralOverlayRect),
            into: boardRect
        )
        let reefAnchor = try XCTUnwrap(layout.slot(id: "blue.twilight.0")?.coralAnchor)

        XCTAssertTrue(BoardCoralTokenLayout.frames(coralCount: 0, reefCenter: reefAnchor, boardRect: boardRect).isEmpty)

        let frames = BoardCoralTokenLayout.frames(
            coralCount: 6,
            reefCenter: reefAnchor,
            boardRect: boardRect
        )
        XCTAssertEqual(frames.count, 6)
        XCTAssertTrue(frames.allSatisfy { overlayRect.contains($0.visualRect) })
        XCTAssertGreaterThan(frames[1].visualRect.minX, frames[0].visualRect.maxX)
        XCTAssertEqual(frames[0].visualRect.width, 56, accuracy: 0.01)
    }

    func testPlayerMatUsesPrintedForageFishButStillRendersPlayedFishCards() {
        XCTAssertFalse(
            BoardSlotArtworkPolicy.shouldRenderCardFace(
                kind: .empty,
                includesPrintedForageFish: true
            )
        )
        XCTAssertFalse(
            BoardSlotArtworkPolicy.shouldRenderCardFace(
                kind: .forageFish,
                includesPrintedForageFish: true
            )
        )
        XCTAssertTrue(
            BoardSlotArtworkPolicy.shouldRenderCardFace(
                kind: .fishCard,
                includesPrintedForageFish: true
            )
        )
        XCTAssertTrue(
            BoardSlotArtworkPolicy.shouldRenderCardFace(
                kind: .forageFish,
                includesPrintedForageFish: false
            )
        )
        XCTAssertTrue(
            BoardSlotArtworkPolicy.shouldRenderSeparateResourceTokens(
                kind: .empty,
                includesPrintedForageFish: true
            )
        )
        XCTAssertTrue(
            BoardSlotArtworkPolicy.shouldRenderSeparateResourceTokens(
                kind: .forageFish,
                includesPrintedForageFish: true
            )
        )
        XCTAssertFalse(
            BoardSlotArtworkPolicy.shouldRenderSeparateResourceTokens(
                kind: .fishCard,
                includesPrintedForageFish: true
            )
        )
    }

    func testStartingResourceAnchorsStayInTheLiveTokenArtworkRegion() throws {
        let data = try Data(contentsOf: boardLayoutJsonURL())
        let layout = try JSONDecoder().decode(BoardLayout.self, from: data)
        let startingSlots = [
            "blue.midnight.0",
            "purple.sunlit.2",
            "green.sunlit.1"
        ]

        for slotId in startingSlots {
            let slot = try XCTUnwrap(layout.slot(id: slotId))
            let relativeX = (slot.resourceAnchor.x - slot.cardRect.x) / slot.cardRect.width
            let relativeY = (slot.resourceAnchor.y - slot.cardRect.y) / slot.cardRect.height
            XCTAssertEqual(relativeX, 0.46, accuracy: 0.000_01, slotId)
            XCTAssertEqual(relativeY, 0.42, accuracy: 0.000_01, slotId)
        }
    }

    func testLiveResourceTokenVisualAndHitFramesStayInsideCard() {
        let cardRect = CGRect(x: 100, y: 200, width: 300, height: 300 / CardRenderMetrics.cardAspectRatio)
        let anchor = CGPoint(
            x: cardRect.minX + cardRect.width * 0.46,
            y: cardRect.minY + cardRect.height * 0.42
        )

        for index in 0..<BoardSlotResourceTokenLayout.maxVisibleTokens {
            let frame = BoardSlotResourceTokenLayout.frame(
                at: index,
                anchor: anchor,
                cardRect: cardRect
            )
            XCTAssertTrue(cardRect.contains(frame.visualRect), "visual \(index)")
            XCTAssertTrue(cardRect.contains(frame.hitRect), "hit \(index)")
            XCTAssertTrue(frame.hitRect.contains(frame.visualRect), "hit contains visual \(index)")
        }

        let firstFrame = BoardSlotResourceTokenLayout.frame(
            at: 0,
            anchor: anchor,
            cardRect: cardRect
        )
        XCTAssertEqual(firstFrame.visualRect.width / cardRect.width, 0.155, accuracy: 0.000_1)
        XCTAssertEqual(firstFrame.visualRect.midX, anchor.x, accuracy: 0.001)
        XCTAssertEqual(firstFrame.visualRect.midY, anchor.y, accuracy: 0.001)
    }

    @MainActor
    func testDebugCalibrationOverlayDoesNotSubmitCommandOrMutateState() {
        let service = FloatingActionRoomService(hand: ["floating-fish"])
        let before = service.gameState

        _ = BoardLayoutCalibrationOverlay(
            layout: .placeholderBaseGame,
            showsLabels: true
        )

        XCTAssertEqual(service.gameState, before)
        XCTAssertTrue(service.submittedCommands.isEmpty)
    }

    @MainActor
    func testBoardLayoutDoesNotAffectResourceTokenPaymentStaging() {
        let service = FloatingActionRoomService(
            hand: ["egg-cost"],
            sourceResources: [ResourceQuantity(kind: .egg, amount: 1)]
        )
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: FloatingActionCatalog()
        )
        let sourceAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        viewModel.selectCard("egg-cost")
        viewModel.toggleResourcePayment(address: sourceAddress, kind: .egg, tokenIndex: 0)

        XCTAssertEqual(viewModel.selectedEggSources, [sourceAddress])
        XCTAssertNotNil(BoardLayout.placeholderBaseGame.slot(id: BoardLayout.slotId(for: sourceAddress)))
    }

    private func boardLayoutJsonURL() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot
            .appendingPathComponent("Finspan")
            .appendingPathComponent("Resources")
            .appendingPathComponent("BoardLayout")
            .appendingPathComponent("player_mat_layout.json")
        if !FileManager.default.fileExists(atPath: url.path) {
            throw NSError(
                domain: "BoardLayoutMappingTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing \(url.path)"]
            )
        }
        return url
    }

    private func resourceURL(_ relativePath: String) throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot
            .appendingPathComponent("Finspan")
            .appendingPathComponent("Resources")
            .appendingPathComponent(relativePath)
        if !FileManager.default.fileExists(atPath: url.path) {
            throw NSError(
                domain: "BoardLayoutMappingTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing \(url.path)"]
            )
        }
        return url
    }
}

@MainActor
private final class FloatingActionRoomService: RoomService {
    var gameRoom: GameRoom?
    var gameState: GameState
    var snapshot: RoomSnapshot
    var eventLog: [GameEvent] = []
    var submittedCommands: [PlayerCommand] = []

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in continuation.finish() }
    }

    init(
        hand: [CardID],
        discardPile: [CardID] = [],
        sourceResources: [ResourceQuantity] = [],
        additionalPlayers: [RoomPlayer] = []
    ) {
        let roomPlayers = [
            RoomPlayer(playerId: "player-1", displayName: "玩家 1", role: .host)
        ] + additionalPlayers
        let room = GameRoom(
            roomId: "room-1",
            roomCode: "LOCAL",
            hostPlayerId: "player-1",
            players: roomPlayers,
            gameConfig: GameConfig(
                playerCount: roomPlayers.count,
                enabledExpansions: [],
                randomSeed: 1
            ),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        let playerStates = Dictionary(uniqueKeysWithValues: roomPlayers.map { player -> (PlayerID, PlayerGameState) in
            var ocean = OceanState.baseGameInitial(for: player.playerId)
            for slotIndex in ocean.slots.indices {
                ocean.slots[slotIndex].content = .empty
                ocean.slots[slotIndex].resources = []
            }
            if player.playerId == "player-1",
               let sourceIndex = ocean.slots.firstIndex(where: {
                   $0.address.diveSite == .blue && $0.address.rowIndex == 0
               }) {
                ocean.slots[sourceIndex].content = .fishCard("source-fish")
                ocean.slots[sourceIndex].resources = sourceResources
            }
            return (
                player.playerId,
                PlayerGameState(
                    playerId: player.playerId,
                    hand: player.playerId == "player-1" ? hand : [],
                    discardPile: player.playerId == "player-1" ? discardPile : [],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: ocean
                )
            )
        })

        let state = GameState(
            roomId: room.roomId,
            players: roomPlayers.map { Player(id: $0.playerId, name: $0.displayName) },
            currentWeek: 1,
            currentTurnIndex: 0,
            activePlayerId: "player-1",
            firstPlayerId: "player-1",
            phase: .playing,
            eventSequence: 1,
            randomSeed: 1,
            turnsCompletedThisWeek: 0,
            playerGameStates: playerStates,
            deckState: DeckState(starterFishDrawPile: [], fishDrawPile: [], discardPile: []),
            pendingChoices: [:]
        )
        gameRoom = room
        gameState = state
        snapshot = RoomSnapshot(id: room.roomId, players: room.players, state: state, events: [])
    }

    func submit(_ command: PlayerCommand) throws -> [GameEvent] {
        submittedCommands.append(command)
        return []
    }

    func resetLocalRoomSession() {}
}

private struct FloatingActionCatalog: CardCatalog {
    let starterFishCards: [Card] = []
    let fishCards: [Card] = [
        Card(
            id: "floating-fish",
            name: "Floating Fish",
            costs: [],
            allowedZones: [.sunlit],
            printedPoints: 1,
            lengthCm: 20
        ),
        Card(
            id: "source-fish",
            name: "Source Fish",
            costs: [],
            allowedZones: [.sunlit],
            printedPoints: 1,
            lengthCm: 10
        ),
        Card(
            id: "egg-cost",
            name: "Egg Cost Fish",
            costs: [.resource(kind: .egg, count: 1)],
            allowedZones: [.sunlit],
            printedPoints: 1,
            lengthCm: 30
        )
    ]
}

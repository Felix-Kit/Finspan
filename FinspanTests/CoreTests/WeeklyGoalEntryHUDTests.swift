import XCTest
@testable import Finspan

@MainActor
final class WeeklyGoalEntryHUDTests: XCTestCase {
    func testHudUsesFourHorizontalTopTrailingEntryTiles() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()
        let hud = viewModel.weeklyGoalHudViewState

        XCTAssertEqual(hud.boxes.map(\.index), [1, 2, 3, 4])
        XCTAssertEqual(hud.layout, .horizontalEntryStrip)
        XCTAssertEqual(hud.placement, .topTrailing)
        XCTAssertTrue(hud.boxes.allSatisfy { !$0.weekLabel.isEmpty && !$0.pointsText.isEmpty })
        XCTAssertTrue(hud.boxes.allSatisfy { !$0.showsFullTitle })
        XCTAssertEqual(hud.boxes.first?.iconScale, 1.15)
    }

    func testSelectingEntryPresentsThatWeekOnly() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()

        viewModel.selectWeeklyGoalBox(2)

        XCTAssertEqual(viewModel.weeklyGoalHudViewState.selectedDetailWeek, 2)
        XCTAssertEqual(viewModel.weeklyGoalDetailViewState?.sections.map(\.index), [1, 2, 3, 4])
        XCTAssertEqual(viewModel.weeklyGoalDetailViewState?.sections.first(where: { $0.isSelected })?.index, 2)
    }
}

@MainActor
final class WeeklyAchievementDetailPanelTests: XCTestCase {
    func testDetailHeaderStateOrdersWeekBeforeIconsAndTitle() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()
        viewModel.selectWeeklyGoalBox(1)

        guard let item = viewModel.weeklyGoalDetailViewState?.sections.first(where: { $0.index == 1 }) else {
            return XCTFail("Expected selected weekly goal detail.")
        }

        XCTAssertEqual(item.weekLabel, "第 1 周")
        XCTAssertFalse(item.icons.isEmpty)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testFourthWeekUsesFixedGameEndDetail() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()
        viewModel.selectWeeklyGoalBox(4)

        XCTAssertEqual(viewModel.weeklyGoalDetailViewState?.sections.count, 4)
        XCTAssertNotNil(viewModel.weeklyGoalDetailViewState?.sections.first(where: { $0.index == 4 })?.gameEndInfo)
    }
}

@MainActor
final class FishCardResourceOverlayTests: XCTestCase {
    func testResourceTokensUseUnframedFishArtworkPlacement() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()
        guard let cardFace = viewModel.oceanSlots.first(where: { $0.cardFace.cardId == "starter-fish-1" })?.cardFace else {
            return XCTFail("Expected visible sample fish card.")
        }

        XCTAssertEqual(cardFace.resourceTokens.count, 4)
        XCTAssertTrue(cardFace.resourceTokens.allSatisfy { $0.placement == .fishArtworkRegion })
        XCTAssertTrue(cardFace.resourceTokens.allSatisfy { !$0.usesBadgeFrame })
        XCTAssertTrue(cardFace.resourceTokens.allSatisfy { $0.icon.isResolved })
    }
}

@MainActor
final class CoralBoardDisplayTests: XCTestCase {
    func testCoralIsPresentedBeforeTwilightInsteadOfCompactHud() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()

        XCTAssertFalse(viewModel.compactResourceHUDState.entries.contains { $0.id.hasPrefix("coral-") })
        XCTAssertEqual(viewModel.oceanColumns.compactMap(\.coralReef).count, 3)
        XCTAssertTrue(viewModel.oceanColumns.compactMap(\.coralReef).allSatisfy {
            $0.placement == .beforeTwilightZone && $0.icon.isResolved
        })
    }
}

final class RealCardCatalogRuntimeTests: XCTestCase {
    func testNormalRuntimeDefaultsToReviewedBaseCatalog() throws {
        let controller = GameDataController()
        let catalog = controller.currentCatalog()

        XCTAssertEqual(controller.mode, .baseGame)
        XCTAssertEqual(GameDataMode.runtimeCases, [.baseGame])
        XCTAssertFalse(catalog.fishCards.isEmpty)
        XCTAssertFalse(catalog.fishCards.contains { $0.id.hasPrefix("fish-") })
    }
}

@MainActor
enum WeeklyDisplayTestFactory {
    static func makeViewModel() -> GameBoardViewModel {
        GameBoardViewModel(
            roomService: WeeklyDisplayRoomService(),
            cardCatalog: SampleCardCatalog()
        )
    }
}

@MainActor
final class WeeklyDisplayRoomService: RoomService {
    var gameRoom: GameRoom?
    var gameState: GameState
    var snapshot: RoomSnapshot
    var eventLog: [GameEvent] = []

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in continuation.finish() }
    }

    init(
        roomPlayers: [RoomPlayer] = [
            RoomPlayer(playerId: "player-1", displayName: "玩家 1", role: .host)
        ],
        currentWeek: Int = 1,
        weeklyGoals: [WeeklyGoalDefinition]? = nil,
        weeklyAchievementResults: [WeeklyAchievementResult] = []
    ) {
        let roomPlayer = roomPlayers[0]
        let room = GameRoom(
            roomId: "room-1",
            roomCode: "LOCAL",
            hostPlayerId: "player-1",
            players: roomPlayers,
            gameConfig: GameConfig(playerCount: roomPlayers.count, enabledExpansions: [.sharksAndReefs], randomSeed: 1),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        var ocean = OceanState.baseGameInitial(for: "player-1")
        if let index = ocean.slots.firstIndex(where: {
            $0.address.diveSite == .blue && $0.address.rowIndex == 0
        }) {
            ocean.slots[index].content = .fishCard("starter-fish-1")
            ocean.slots[index].resources = [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 2),
                ResourceQuantity(kind: .school, amount: 1)
            ]
        }
        ocean.coralReefs = DiveSite.allCases.map {
            CoralReefState(diveSite: $0, coralCount: 1, maxCoral: 4, completionBonus: 6)
        }
        let playerStates = Dictionary(uniqueKeysWithValues: roomPlayers.map { player in
            let playerOcean = player.playerId == roomPlayer.playerId
                ? ocean
                : OceanState.baseGameInitial(for: player.playerId)
            return (
                player.playerId,
                PlayerGameState(
                    playerId: player.playerId,
                    hand: [],
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: playerOcean
                )
            )
        })
        let state = GameState(
            roomId: room.roomId,
            players: roomPlayers.map { Player(id: $0.playerId, name: $0.displayName) },
            currentWeek: currentWeek,
            currentTurnIndex: 0,
            activePlayerId: "player-1",
            firstPlayerId: "player-1",
            phase: .playing,
            eventSequence: 1,
            randomSeed: 1,
            turnsCompletedThisWeek: 0,
            playerGameStates: playerStates,
            deckState: DeckState(starterFishDrawPile: [], fishDrawPile: [], discardPile: []),
            weeklyGoals: weeklyGoals,
            weeklyAchievementResults: weeklyAchievementResults
        )

        gameRoom = room
        gameState = state
        snapshot = RoomSnapshot(id: room.roomId, players: room.players, state: state, events: [])
    }

    func submit(_ command: PlayerCommand) throws -> [GameEvent] { [] }
    func resetLocalRoomSession() {}
}

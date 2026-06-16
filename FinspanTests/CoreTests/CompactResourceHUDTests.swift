import XCTest
@testable import Finspan

@MainActor
final class CompactResourceHUDTests: XCTestCase {
    func testCompactResourceHUDUsesRealIconResolverAssets() {
        let viewModel = GameBoardViewModel(
            roomService: CompactHUDRoomService(
                hand: ["starter-fish-1", "fish-1", "fish-2"],
                resources: [
                    ResourceQuantity(kind: .egg, amount: 2),
                    ResourceQuantity(kind: .young, amount: 1),
                    ResourceQuantity(kind: .school, amount: 1)
                ],
                coralReefs: [
                    CoralReefState(diveSite: .blue, coralCount: 1, maxCoral: 4, completionBonus: 6),
                    CoralReefState(diveSite: .purple, coralCount: 2, maxCoral: 4, completionBonus: 8),
                    CoralReefState(diveSite: .green, coralCount: 3, maxCoral: 4, completionBonus: 5)
                ]
            ),
            cardCatalog: SampleCardCatalog()
        )

        let hud = viewModel.compactResourceHUDState

        XCTAssertEqual(hud.entries.map(\.id), [
            "fish",
            ResourceKind.egg.rawValue,
            ResourceKind.young.rawValue,
            ResourceKind.school.rawValue,
            "coral-blue",
            "coral-purple",
            "coral-green"
        ])
        XCTAssertEqual(hud.entries.map(\.count), [3, 2, 1, 1, 1, 2, 3])
        XCTAssertTrue(hud.entries.allSatisfy { $0.icon.isResolved })
        XCTAssertTrue(hud.entries.allSatisfy { $0.icon.asset?.fileExtension.lowercased() == "png" })
    }

    func testCompactResourceHUDSummaryDoesNotDependOnTextOnlyFallbacks() {
        let viewModel = GameBoardViewModel(
            roomService: CompactHUDRoomService(hand: [], resources: [], coralReefs: []),
            cardCatalog: SampleCardCatalog()
        )

        for entry in viewModel.gameHudViewState.compactResourceHUD.entries {
            XCTAssertNotNil(entry.icon.asset)
            XCTAssertNil(entry.icon.icon.missingAsset)
            XCTAssertTrue(entry.icon.isResolved)
        }
    }
}

@MainActor
private final class CompactHUDRoomService: RoomService {
    var gameRoom: GameRoom?
    var gameState: GameState
    var snapshot: RoomSnapshot
    var eventLog: [GameEvent] = []

    var eventStream: AsyncStream<GameEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    init(
        hand: [CardID],
        resources: [ResourceQuantity],
        coralReefs: [CoralReefState]
    ) {
        let player = RoomPlayer(playerId: "player-1", displayName: "玩家 1", role: .host)
        let room = GameRoom(
            roomId: "room-1",
            roomCode: "LOCAL",
            hostPlayerId: "player-1",
            players: [player],
            gameConfig: GameConfig(playerCount: 1, enabledExpansions: [], randomSeed: 1),
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        var ocean = OceanState.baseGameInitial(for: "player-1")
        ocean.coralReefs = coralReefs
        for slotIndex in ocean.slots.indices {
            ocean.slots[slotIndex].resources = []
        }
        if let slotIndex = ocean.slots.firstIndex(where: { $0.address.diveSite == .blue && $0.address.rowIndex == 0 }) {
            ocean.slots[slotIndex].resources = resources
        }
        let state = GameState(
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
                    hand: hand,
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: ocean
                )
            ],
            deckState: DeckState(starterFishDrawPile: [], fishDrawPile: [], discardPile: [])
        )

        gameRoom = room
        gameState = state
        snapshot = RoomSnapshot(id: room.roomId, players: room.players, state: state, events: [])
    }

    func submit(_ command: PlayerCommand) throws -> [GameEvent] {
        []
    }

    func resetLocalRoomSession() {}
}

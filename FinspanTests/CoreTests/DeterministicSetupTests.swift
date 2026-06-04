import XCTest
@testable import Finspan

final class DeterministicSetupTests: XCTestCase {

    func testSameSeedProducesSameSetup() throws {
        let first = try makeStartedService(seed: 123)
        let second = try makeStartedService(seed: 123)

        XCTAssertEqual(first.gameState.playerGameStates, second.gameState.playerGameStates)
        XCTAssertEqual(first.gameState.deckState, second.gameState.deckState)
        XCTAssertEqual(first.gameState.activePlayerId, second.gameState.activePlayerId)
    }

    func testDifferentSeedChangesStartingPlayerOrDeckOrder() throws {
        let first = try makeStartedService(seed: 123)
        let second = try makeStartedService(seed: 124)

        let activePlayerChanged = first.gameState.activePlayerId != second.gameState.activePlayerId
        let starterDeckChanged = first.gameState.deckState.starterFishDrawPile != second.gameState.deckState.starterFishDrawPile
        let fishDeckChanged = first.gameState.deckState.fishDrawPile != second.gameState.deckState.fishDrawPile

        XCTAssertTrue(activePlayerChanged || starterDeckChanged || fishDeckChanged)
    }

    func testEachPlayerStartsWithFiveCardsAndSixDivers() throws {
        let service = try makeStartedService(seed: 123)

        XCTAssertEqual(service.gameState.playerGameStates.count, 3)
        for playerState in service.gameState.playerGameStates.values {
            XCTAssertEqual(playerState.hand.count, 5)
            XCTAssertEqual(playerState.availableDivers, 6)
        }
    }

    func testEachPlayerStartsWithBaseOceanResources() throws {
        let service = try makeStartedService(seed: 123)

        for playerState in service.gameState.playerGameStates.values {
            XCTAssertEqual(
                playerState.ocean.resources,
                [
                    ResourceQuantity(kind: ResourceKind(rawValue: "egg"), amount: 2),
                    ResourceQuantity(kind: ResourceKind(rawValue: "young"), amount: 1)
                ]
            )
        }
    }

    func testEachPlayerStartsWithThreeForageFishSlots() throws {
        let service = try makeStartedService(seed: 123)

        for playerState in service.gameState.playerGameStates.values {
            let forageSlots = playerState.ocean.slots.filter { slot in
                if case .forageFish = slot.content {
                    return true
                }
                return false
            }

            XCTAssertEqual(forageSlots.count, 3)
            XCTAssertEqual(
                Set(forageSlots.map(\.address)),
                [
                    OceanSlotAddress(playerId: playerState.playerId, diveSite: .blue, rowIndex: 4),
                    OceanSlotAddress(playerId: playerState.playerId, diveSite: .purple, rowIndex: 3),
                    OceanSlotAddress(playerId: playerState.playerId, diveSite: .green, rowIndex: 1)
                ]
            )
        }
    }

    func testEachPlayerStartsWithEighteenOceanSlots() throws {
        let service = try makeStartedService(seed: 123)

        for playerState in service.gameState.playerGameStates.values {
            XCTAssertEqual(playerState.ocean.slots.count, 18)

            for diveSite in DiveSite.allCases {
                let siteSlots = playerState.ocean.slots.filter { $0.address.diveSite == diveSite }
                XCTAssertEqual(siteSlots.count, 6)
                XCTAssertEqual(siteSlots.filter { $0.address.zone == .sunlit }.count, 3)
                XCTAssertEqual(siteSlots.filter { $0.address.zone == .twilight }.count, 1)
                XCTAssertEqual(siteSlots.filter { $0.address.zone == .midnight }.count, 2)
                XCTAssertEqual(siteSlots.first(where: { $0.address.rowIndex == 0 })?.rowTrait, .topRow)
                XCTAssertEqual(siteSlots.first(where: { $0.address.rowIndex == 5 })?.rowTrait, .bottomRow)
            }
        }
    }

    func testOnlyThreeSampleForageFishSlotsAreOccupiedAtSetup() throws {
        let service = try makeStartedService(seed: 123)

        for playerState in service.gameState.playerGameStates.values {
            let forageAddresses = Set(
                playerState.ocean.slots.compactMap { slot -> OceanSlotAddress? in
                    if case .forageFish = slot.content {
                        return slot.address
                    }
                    return nil
                }
            )
            let expectedForageAddresses: Set<OceanSlotAddress> = [
                OceanSlotAddress(playerId: playerState.playerId, diveSite: .blue, rowIndex: 4),
                OceanSlotAddress(playerId: playerState.playerId, diveSite: .purple, rowIndex: 3),
                OceanSlotAddress(playerId: playerState.playerId, diveSite: .green, rowIndex: 1)
            ]

            XCTAssertEqual(forageAddresses, expectedForageAddresses)
            XCTAssertEqual(playerState.ocean.slots.filter { $0.content == .empty }.count, 15)
        }
    }

    func testEachPlayerStartsWithDistributedEggAndYoungResources() throws {
        let service = try makeStartedService(seed: 123)

        for playerState in service.gameState.playerGameStates.values {
            let eggSlots = playerState.ocean.slots.filter { resourceAmount(.egg, in: $0) > 0 }
            let youngSlots = playerState.ocean.slots.filter { resourceAmount(.young, in: $0) > 0 }
            let eggTotal = playerState.ocean.slots.reduce(0) { $0 + resourceAmount(.egg, in: $1) }
            let youngTotal = playerState.ocean.slots.reduce(0) { $0 + resourceAmount(.young, in: $1) }

            XCTAssertEqual(eggTotal, 2)
            XCTAssertEqual(youngTotal, 1)
            XCTAssertEqual(eggSlots.count, 2)
            XCTAssertNotEqual(eggSlots[0].address, eggSlots[1].address)
            XCTAssertEqual(youngSlots.count, 1)
            XCTAssertFalse(eggSlots.allSatisfy { $0.address == youngSlots[0].address })
        }
    }

    func testActivePlayerComesFromPlayerList() throws {
        let service = try makeStartedService(seed: 123)
        let activePlayerId = try XCTUnwrap(service.gameState.activePlayerId)

        XCTAssertTrue(service.gameState.players.map(\.id).contains(activePlayerId))
        XCTAssertEqual(service.gameState.currentWeek, 1)
        XCTAssertEqual(service.gameState.phase, .playing)
    }

    func testSetupCanBeRebuiltFromEventLog() throws {
        let service = try makeStartedService(seed: 123)
        let rebuiltState = service.eventLog.reduce(GameState.empty) { state, event in
            GameEngine().reduce(state: state, event: event)
        }

        XCTAssertEqual(rebuiltState, service.gameState)
    }

    private func makeStartedService(seed: Int) throws -> LocalAuthoritativeRoomService {
        let service = LocalAuthoritativeRoomService(
            roomId: "room-1",
            timestampProvider: { Date(timeIntervalSince1970: 1_000) },
            randomSeedProvider: { seed }
        )

        try service.submit(
            .createRoom(
                commandId: "command-1",
                playerId: "player-1",
                roomId: "room-1",
                roomCode: "ABCD",
                displayName: "Player 1",
                gameConfig: GameConfig(playerCount: 3, randomSeed: 0)
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-2",
                playerId: "player-2",
                roomId: "room-1",
                payload: .joinRoom(JoinRoomCommand(displayName: "Player 2"))
            )
        )
        try service.submit(
            PlayerCommand(
                commandId: "command-3",
                playerId: "player-3",
                roomId: "room-1",
                payload: .joinRoom(JoinRoomCommand(displayName: "Player 3"))
            )
        )

        for playerId in ["player-1", "player-2", "player-3"] {
            try service.submit(
                PlayerCommand(
                    commandId: "ready-\(playerId)",
                    playerId: playerId,
                    roomId: "room-1",
                    payload: .setReady(SetReadyCommand(isReady: true))
                )
            )
        }

        try service.submit(
            PlayerCommand(
                commandId: "start-game",
                playerId: "player-1",
                roomId: "room-1",
                payload: .startGame(StartGameCommand())
            )
        )

        return service
    }

    private func resourceAmount(_ kind: ResourceKind, in slot: OceanSlot) -> Int {
        slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
    }
}

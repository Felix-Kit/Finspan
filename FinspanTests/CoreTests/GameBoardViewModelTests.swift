import XCTest
@testable import Finspan

@MainActor
final class GameBoardViewModelTests: XCTestCase {
    func testSubmitPlayFishBuildsPlayerCommandFromSelection() {
        let slotAddress = Self.slotAddress
        let service = makeService(hand: ["starter-fish-1"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }

        XCTAssertEqual(service.submittedCommands.last?.playerId, "player-1")
        XCTAssertEqual(service.submittedCommands.last?.roomId, "room-1")
        XCTAssertEqual(payload.cardId, "starter-fish-1")
        XCTAssertEqual(payload.targetSlot, slotAddress)
        XCTAssertEqual(payload.payment, PlayFishPayment.empty)
    }

    func testSubmitPlayFishIncludesSelectedEggSources() {
        let slotAddress = Self.slotAddress
        let sourceAddress = Self.resourceSourceAddress
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.toggleEggSource(sourceAddress)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }

        XCTAssertEqual(payload.cardId, "fish-2")
        XCTAssertEqual(payload.targetSlot, slotAddress)
        XCTAssertEqual(payload.payment.eggSources, [sourceAddress])
        XCTAssertEqual(payload.payment.youngSources, [])
        XCTAssertEqual(payload.payment.discardedCardIds, [])
    }

    func testSubmitPlayFishIncludesSelectedYoungSources() {
        let slotAddress = Self.slotAddress
        let sourceAddress = Self.resourceSourceAddress
        let service = makeService(hand: ["fish-3"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-3")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.toggleYoungSource(sourceAddress)
        viewModel.submitPlayFish()

        guard case let .playFish(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected playFish command.")
        }

        XCTAssertEqual(payload.cardId, "fish-3")
        XCTAssertEqual(payload.targetSlot, slotAddress)
        XCTAssertEqual(payload.payment.eggSources, [])
        XCTAssertEqual(payload.payment.youngSources, [sourceAddress])
        XCTAssertEqual(payload.payment.discardedCardIds, [])
    }

    func testResourceSourceOptionsAreNotFilteredByTargetSlot() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(Self.slotAddress)

        XCTAssertTrue(
            viewModel.eggSourceOptions.contains { $0.address == Self.resourceSourceAddress }
        )
        XCTAssertNotEqual(Self.slotAddress, Self.resourceSourceAddress)
    }

    func testSubmitDiveBuildsPlayerCommand() {
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.submitDive(to: .purple)

        guard case let .dive(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected dive command.")
        }

        XCTAssertEqual(service.submittedCommands.last?.playerId, "player-1")
        XCTAssertEqual(service.submittedCommands.last?.roomId, "room-1")
        XCTAssertEqual(payload.diveSite, .purple)
    }

    func testSubmitPlayFishDoesNotSubmitWhenResourceSourcesAreIncomplete() {
        let slotAddress = Self.slotAddress
        let service = makeService(hand: ["fish-2"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-2")
        viewModel.selectTargetSlot(slotAddress)
        viewModel.submitPlayFish()

        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.eggPaymentIncomplete)
    }

    func testSkipPendingChoiceBuildsResolvePendingChoiceCommand() {
        let choice = PendingChoice(
            choiceId: "choice-1",
            playerId: "player-1",
            source: .diveBonus(.blue),
            kind: .bottomBonus,
            options: [],
            expectedInput: .none,
            isOptional: true,
            createdAtSequence: 2
        )
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.skipPendingChoice(choice.choiceId)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }

        XCTAssertEqual(service.submittedCommands.last?.playerId, "player-1")
        XCTAssertEqual(service.submittedCommands.last?.roomId, "room-1")
        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .skip)
    }

    private static let slotAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .coast,
        zone: .sunlit,
        slotIndex: 0
    )

    private static let resourceSourceAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .reef,
        zone: .twilight,
        slotIndex: 0
    )

    private func makeService(
        hand: [CardID],
        pendingChoices: [PendingChoiceID: PendingChoice] = [:]
    ) -> CapturingRoomService {
        var ocean = OceanState.baseGameInitial(for: "player-1")
        if let sourceIndex = ocean.slots.firstIndex(where: { $0.address == Self.resourceSourceAddress }) {
            ocean.slots[sourceIndex].resources = [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 1)
            ]
        }

        return CapturingRoomService(
            gameRoom: GameRoom(
                roomId: "room-1",
                roomCode: "LOCAL",
                hostPlayerId: "player-1",
                players: [
                    RoomPlayer(
                        playerId: "player-1",
                        displayName: "玩家 1",
                        role: .host
                    )
                ],
                gameConfig: GameConfig(playerCount: 1, randomSeed: 1),
                createdAt: Date(timeIntervalSince1970: 1_000),
                updatedAt: Date(timeIntervalSince1970: 1_000)
            ),
            gameState: GameState(
                roomId: "room-1",
                players: [Player(id: "player-1", name: "玩家 1")],
                currentWeek: 1,
                currentTurnIndex: 0,
                activePlayerId: "player-1",
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
                deckState: .empty,
                pendingChoices: pendingChoices
            )
        )
    }
}

@MainActor
private final class CapturingRoomService: RoomService {
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

    func submit(_ command: PlayerCommand) throws -> [GameEvent] {
        submittedCommands.append(command)
        return []
    }
}

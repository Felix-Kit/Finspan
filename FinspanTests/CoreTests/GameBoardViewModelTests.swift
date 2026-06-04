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

    func testDiscardCostCardKeepsLegalEmptySlotAvailable() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertTrue(slot.playFishPreview.isSelectable)
    }

    func testTogglingDiscardPaymentKeepsLegalEmptySlotAvailable() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.toggleDiscardPaymentCard("fish-6")

        let slot = oceanSlot(in: viewModel, address: Self.slotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .available)
        XCTAssertTrue(slot.playFishPreview.isSelectable)
        XCTAssertEqual(viewModel.selectedTargetSlot, Self.slotAddress)
    }

    func testOccupiedSlotPreviewIsUnavailable() {
        let service = makeService(hand: ["fish-1"], emptySlots: [])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.forageTargetAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .occupied)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.slotOccupied)
    }

    func testZoneMismatchPreviewIsUnavailable() {
        let service = makeService(hand: ["fish-1"], emptySlots: [Self.slotAddress, Self.resourceSourceAddress])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-1")

        let slot = oceanSlot(in: viewModel, address: Self.resourceSourceAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .zoneMismatch)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.slotZoneMismatch)
    }

    func testRequiredDiveSiteColorMismatchPreviewIsUnavailable() {
        let service = makeService(hand: ["fish-4"], emptySlots: [Self.slotAddress])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("fish-4")

        let slot = oceanSlot(in: viewModel, address: Self.blueTwilightSlotAddress)
        XCTAssertEqual(slot.playFishPreview.availability, .unavailable)
        XCTAssertEqual(slot.playFishPreview.unavailableReason, .diveSiteMismatch)
        XCTAssertEqual(slot.playFishPreview.message, AppStrings.GameBoard.slotDiveSiteMismatch)
    }

    func testSelectingFishMarksDiveUnavailableDuringPlayFishSelection() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertTrue(viewModel.canDive)

        viewModel.selectCard("fish-1")

        XCTAssertTrue(viewModel.isSelectingPlayFish)
        XCTAssertFalse(viewModel.canDive)
    }

    func testOceanSlotPreviewsUseBaseGameEighteenSlotLayout() {
        let service = makeService(hand: ["fish-1", "fish-6"])
        let viewModel = GameBoardViewModel(roomService: service)

        XCTAssertEqual(viewModel.oceanSlots.count, 18)
        XCTAssertEqual(viewModel.oceanColumns.count, 3)
        XCTAssertEqual(viewModel.oceanColumns.map(\.slots.count), [6, 6, 6])
        XCTAssertEqual(viewModel.oceanColumns[0].diveSite, .blue)
        XCTAssertEqual(viewModel.oceanColumns[1].diveSite, .purple)
        XCTAssertEqual(viewModel.oceanColumns[2].diveSite, .green)
        XCTAssertEqual(
            Set(viewModel.oceanSlots.filter { $0.address.rowTrait == .topRow }.map(\.address.rowIndex)),
            [0]
        )
        XCTAssertEqual(
            Set(viewModel.oceanSlots.filter { $0.address.rowTrait == .bottomRow }.map(\.address.rowIndex)),
            [5]
        )
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

    func testBlockingPendingChoicePreventsPlayFishAndDiveSubmission() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: ["starter-fish-1"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.selectCard("starter-fish-1")
        viewModel.selectTargetSlot(Self.slotAddress)
        viewModel.submitPlayFish()
        viewModel.submitDive(to: .blue)

        XCTAssertTrue(viewModel.hasBlockingPendingChoices)
        XCTAssertFalse(viewModel.canSubmitPlayFish)
        XCTAssertFalse(viewModel.canDive)
        XCTAssertTrue(service.submittedCommands.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.GameBoard.resolveCurrentRewardFirst)
    }

    func testDrawFishPendingChoiceShowsDrawAndSkipActions() {
        let choice = pendingChoice(kind: .drawFish)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertTrue(pendingChoice.canResolve)
        XCTAssertEqual(pendingChoice.title, AppStrings.pendingChoiceKindName(.drawFish))
        XCTAssertEqual(pendingChoice.actions.map(\.title), [
            AppStrings.GameBoard.drawOneFishCard,
            AppStrings.GameBoard.skipChoice
        ])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [true, true])
    }

    func testPlaceEggPendingChoiceShowsDisabledTargetAndSkipActions() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.actions.map(\.title), [
            AppStrings.GameBoard.chooseTargetUnsupported,
            AppStrings.GameBoard.skipChoice
        ])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [false, true])
    }

    func testHatchEggPendingChoiceShowsDisabledTargetAndSkipActions() {
        let choice = pendingChoice(kind: .hatchEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        let pendingChoice = viewModel.pendingChoices[0]

        XCTAssertEqual(pendingChoice.actions.map(\.title), [
            AppStrings.GameBoard.chooseTargetUnsupported,
            AppStrings.GameBoard.skipChoice
        ])
        XCTAssertEqual(pendingChoice.actions.map(\.isEnabled), [false, true])
    }

    func testPerformSkipPendingChoiceActionBuildsResolvePendingChoiceCommand() {
        let choice = pendingChoice(kind: .placeEgg)
        let service = makeService(hand: ["fish-2"], pendingChoices: [choice.choiceId: choice])
        let viewModel = GameBoardViewModel(roomService: service)

        viewModel.performPendingChoiceAction(.skip, for: choice.choiceId)

        guard case let .resolvePendingChoice(payload) = service.submittedCommands.last?.payload else {
            return XCTFail("Expected resolvePendingChoice command.")
        }

        XCTAssertEqual(payload.choiceId, choice.choiceId)
        XCTAssertEqual(payload.resolution, .skip)
    }

    private static let slotAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .blue,
        rowIndex: 0
    )

    private static let resourceSourceAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .purple,
        rowIndex: 3
    )

    private static let blueTwilightSlotAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .blue,
        rowIndex: 3
    )

    private static let forageTargetAddress = OceanSlotAddress(
        playerId: "player-1",
        diveSite: .blue,
        rowIndex: 4
    )

    private func makeService(
        hand: [CardID],
        pendingChoices: [PendingChoiceID: PendingChoice] = [:],
        emptySlots: [OceanSlotAddress] = [GameBoardViewModelTests.slotAddress],
        additionalSlots: [OceanSlot] = []
    ) -> CapturingRoomService {
        var ocean = OceanState.baseGameInitial(for: "player-1")
        for emptySlot in emptySlots {
            if let targetIndex = ocean.slots.firstIndex(where: { $0.address == emptySlot }) {
                ocean.slots[targetIndex].content = .empty
            }
        }
        if let sourceIndex = ocean.slots.firstIndex(where: { $0.address == Self.resourceSourceAddress }) {
            ocean.slots[sourceIndex].resources = [
                ResourceQuantity(kind: .egg, amount: 1),
                ResourceQuantity(kind: .young, amount: 1)
            ]
        }
        ocean.slots.append(contentsOf: additionalSlots)

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

    private func pendingChoice(kind: PendingChoiceKind) -> PendingChoice {
        PendingChoice(
            choiceId: "choice-\(kind.rawValue)",
            playerId: "player-1",
            source: .diveBonus(.blue),
            kind: kind,
            options: [],
            expectedInput: kind == .placeEgg || kind == .hatchEgg ? .targetSlot : .none,
            isOptional: true,
            createdAtSequence: 2
        )
    }

    private func oceanSlot(
        in viewModel: GameBoardViewModel,
        address: OceanSlotAddress,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> OceanSlotViewData {
        guard let slot = viewModel.oceanSlots.first(where: { $0.address == address }) else {
            XCTFail("Expected ocean slot.", file: file, line: line)
            return OceanSlotViewData(
                address: address,
                title: "",
                subtitle: "",
                resourcesText: "",
                isOccupied: false,
                isSelected: false,
                playFishPreview: PlayFishSlotPreview(
                    availability: .unavailable,
                    unavailableReason: .noSelectedCard,
                    message: ""
                )
            )
        }
        return slot
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

import Foundation

struct GameEngine {
    private static let turnsPerWeek = 6
    private static let finalWeek = 4

    private let rules: GameRuleSet
    private let cardCatalog: any CardCatalog

    init(
        rules: GameRuleSet = GameRuleSet(),
        cardCatalog: any CardCatalog = SampleCardCatalog()
    ) {
        self.rules = rules
        self.cardCatalog = cardCatalog
    }

    func validate(command: PlayerCommand, in state: GameState) throws {
        try rules.validate(command, in: state)

        switch command.payload {
        case .startGame:
            guard !state.players.isEmpty else {
                throw GameEngineError.invalidCommand("A game needs at least one player.")
            }
            guard state.phase == .lobby || state.phase == .setup else {
                throw GameEngineError.invalidCommand("The game cannot be started from the current phase.")
            }
            guard state.players.contains(where: { $0.id == command.playerId }) else {
                throw GameEngineError.invalidCommand("Only a joined player can start the game.")
            }
        case .endTurn:
            guard state.phase == .playing else {
                throw GameEngineError.invalidCommand("Turns can only end while the game is playing.")
            }
            guard state.activePlayerId == command.playerId else {
                throw GameEngineError.invalidCommand("Only the active player can end the turn.")
            }
        case let .playFish(payload):
            try validatePlayFish(payload, playerId: command.playerId, in: state)
        case .createRoom,
             .joinRoom,
             .leaveRoom,
             .setReady,
             .chooseSeat,
             .chooseColor,
             .dive,
             .chooseAbilityOption:
            return
        }
    }

    func makeEventDrafts(
        for command: PlayerCommand,
        in state: GameState
    ) throws -> [DomainEventDraft] {
        try validate(command: command, in: state)
        return makeEventDrafts(from: command, in: state)
    }

    func reduce(state: GameState, event: GameEvent) -> GameState {
        var nextState = state
        nextState.roomId = event.roomId
        nextState.eventSequence = event.sequenceNumber

        switch event.payload {
        case let .roomCreated(payload):
            nextState.players = [
                Player(id: payload.hostPlayerId, name: payload.hostDisplayName)
            ]
            nextState.phase = .lobby
            nextState.currentWeek = 0
            nextState.currentTurnIndex = 0
            nextState.activePlayerId = nil
            nextState.randomSeed = payload.gameConfig.randomSeed
            nextState.turnsCompletedThisWeek = 0
        case let .playerJoined(payload):
            let player = Player(id: payload.player.playerId, name: payload.player.displayName)
            if !nextState.players.contains(where: { $0.id == player.id }) {
                nextState.players.append(player)
            }
        case let .playerLeft(payload):
            nextState.players.removeAll { $0.id == payload.playerId }
            if nextState.activePlayerId == payload.playerId {
                nextState.currentTurnIndex = min(nextState.currentTurnIndex, max(nextState.players.count - 1, 0))
                nextState.activePlayerId = nextState.players[safe: nextState.currentTurnIndex]?.id
            }
        case let .gameStarted(payload):
            let startingIndex = nextState.players.firstIndex(where: { $0.id == payload.startingPlayerId }) ?? 0
            nextState.phase = .playing
            nextState.currentWeek = 1
            nextState.currentTurnIndex = startingIndex
            nextState.activePlayerId = nextState.players[safe: startingIndex]?.id
            nextState.randomSeed = payload.randomSeed
            nextState.turnsCompletedThisWeek = 0
        case let .setupCompleted(payload):
            let setup = payload.setup
            let startingIndex = nextState.players.firstIndex(where: { $0.id == setup.startingPlayerId }) ?? 0
            nextState.phase = .playing
            nextState.currentWeek = 1
            nextState.currentTurnIndex = startingIndex
            nextState.activePlayerId = nextState.players[safe: startingIndex]?.id
            nextState.randomSeed = setup.randomSeed
            nextState.turnsCompletedThisWeek = 0
            nextState.playerGameStates = Dictionary(
                uniqueKeysWithValues: setup.playerStates.map { ($0.playerId, $0) }
            )
            nextState.deckState = setup.deckState
        case let .turnEnded(payload):
            let fallbackNextIndex = nextTurnIndex(after: nextState.currentTurnIndex, playerCount: nextState.players.count)
            let nextIndex = payload.nextPlayerId
                .flatMap { nextPlayerId in nextState.players.firstIndex(where: { $0.id == nextPlayerId }) }
                ?? fallbackNextIndex
            nextState.currentTurnIndex = nextIndex
            nextState.activePlayerId = nextState.players[safe: nextIndex]?.id
            nextState.turnsCompletedThisWeek += 1
        case let .weekEnded(payload):
            nextState.phase = .playing
            nextState.currentWeek = min(payload.weekNumber + 1, Self.finalWeek)
            nextState.turnsCompletedThisWeek = 0
        case .gameEnded:
            nextState.phase = .gameEnded
            nextState.activePlayerId = nil
        case let .fishPlayed(payload):
            applyFishPlayed(payload, to: &nextState)
        case .playerReadyChanged,
             .seatChanged,
             .colorChanged,
             .diverMoved,
             .abilityOptionChosen,
             .snapshotCreated:
            break
        }

        return nextState
    }

    private func makeEventDrafts(from command: PlayerCommand, in state: GameState) -> [DomainEventDraft] {
        switch command.payload {
        case let .createRoom(payload):
            return [.roomCreated(
                RoomCreatedEvent(
                    roomCode: payload.roomCode,
                    hostPlayerId: command.playerId,
                    hostDisplayName: payload.displayName,
                    gameConfig: payload.gameConfig
                )
            )]
        case let .joinRoom(payload):
            return [.playerJoined(
                PlayerJoinedEvent(
                    player: RoomPlayer(
                        playerId: command.playerId,
                        displayName: payload.displayName
                    )
                )
            )]
        case .leaveRoom:
            return [.playerLeft(PlayerLeftEvent(playerId: command.playerId))]
        case let .setReady(payload):
            return [.playerReadyChanged(
                PlayerReadyChangedEvent(
                    playerId: command.playerId,
                    isReady: payload.isReady
                )
            )]
        case .startGame:
            return [.gameStarted(GameStartedDraft(startingPlayerId: command.playerId))]
        case let .chooseSeat(payload):
            return [.seatChanged(
                SeatChangedEvent(
                    playerId: command.playerId,
                    seatIndex: payload.seatIndex
                )
            )]
        case let .chooseColor(payload):
            return [.colorChanged(
                ColorChangedEvent(
                    playerId: command.playerId,
                    color: payload.color
                )
            )]
        case let .playFish(payload):
            return [.fishPlayed(
                FishPlayedEvent(
                    playerId: command.playerId,
                    cardId: payload.cardId,
                    targetSlot: payload.targetSlot,
                    payment: payload.payment,
                    nextActivePlayerId: nil
                )
            )]
        case let .dive(payload):
            return [.diverMoved(
                DiverMovedEvent(
                    playerId: command.playerId,
                    destination: payload.destination
                )
            )]
        case let .chooseAbilityOption(payload):
            return [.abilityOptionChosen(
                AbilityOptionChosenEvent(
                    playerId: command.playerId,
                    optionId: payload.optionId
                )
            )]
        case .endTurn:
            let nextPlayerId = nextPlayer(after: command.playerId, in: state.players)?.id
            var drafts: [DomainEventDraft] = [
                .turnEnded(
                TurnEndedEvent(
                    playerId: command.playerId,
                    nextPlayerId: nextPlayerId
                )
                )
            ]

            if state.turnsCompletedThisWeek + 1 >= Self.turnsPerWeek {
                drafts.append(.weekEnded(WeekEndedEvent(weekNumber: state.currentWeek)))

                if state.currentWeek >= Self.finalWeek {
                    drafts.append(.gameEnded(GameEndedEvent(reason: "Completed 4 weeks.")))
                }
            }

            return drafts
        }
    }

    private func nextPlayer(after playerId: PlayerID, in players: [Player]) -> Player? {
        guard
            !players.isEmpty,
            let currentIndex = players.firstIndex(where: { $0.id == playerId })
        else {
            return nil
        }
        return players[nextTurnIndex(after: currentIndex, playerCount: players.count)]
    }

    private func nextTurnIndex(after currentIndex: Int, playerCount: Int) -> Int {
        guard playerCount > 0 else {
            return 0
        }
        return (currentIndex + 1) % playerCount
    }

    private func validatePlayFish(
        _ payload: PlayFishCommand,
        playerId: PlayerID,
        in state: GameState
    ) throws {
        guard state.phase == .playing else {
            throw CommandValidationError.gameNotPlaying
        }
        guard state.activePlayerId == playerId else {
            throw CommandValidationError.inactivePlayer(
                expected: state.activePlayerId,
                actual: playerId
            )
        }
        guard let playerState = state.playerGameStates[playerId] else {
            throw CommandValidationError.missingPlayerState(playerId)
        }
        guard playerState.hand.contains(payload.cardId) else {
            throw CommandValidationError.cardNotInHand(payload.cardId)
        }
        guard let card = card(withId: payload.cardId) else {
            throw CommandValidationError.unknownCard(payload.cardId)
        }
        guard payload.targetSlot.playerId == playerId else {
            throw CommandValidationError.targetSlotNotOwnedByPlayer
        }
        guard let targetSlot = playerState.ocean.slots.first(where: { $0.address == payload.targetSlot }) else {
            throw CommandValidationError.targetSlotNotFound(payload.targetSlot)
        }
        guard targetSlot.fishCardId == nil else {
            throw CommandValidationError.targetSlotOccupied(payload.targetSlot)
        }
        guard card.allowedZones.contains(targetSlot.address.zone) else {
            throw CommandValidationError.targetZoneNotAllowed(targetSlot.address.zone)
        }
        if let requiredColor = card.requiredDiveSiteColor,
           targetSlot.diveSiteColor != requiredColor {
            throw CommandValidationError.requiredDiveSiteColorMismatch(
                expected: requiredColor,
                actual: targetSlot.diveSiteColor
            )
        }
        guard card.requirements.isEmpty else {
            throw CommandValidationError.unsupportedRequirement(card.requirements[0])
        }

        try validatePayment(payload.payment, for: card, payload: payload, playerState: playerState)
    }

    private func validatePayment(
        _ payment: PlayFishPayment,
        for card: Card,
        payload: PlayFishCommand,
        playerState: PlayerGameState
    ) throws {
        for cost in card.costs where !isSupported(cost) {
            throw CommandValidationError.unsupportedCost(cost)
        }

        for discardedCardId in payment.discardedCardIds {
            guard discardedCardId != payload.cardId else {
                throw CommandValidationError.paymentCannotDiscardPlayedCard(discardedCardId)
            }
            guard playerState.hand.contains(discardedCardId) else {
                throw CommandValidationError.paymentCardNotInHand(discardedCardId)
            }
        }

        for cost in card.costs {
            switch cost {
            case let .discardCards(count):
                guard payment.discardedCardIds.count == count else {
                    throw CommandValidationError.paymentDiscardCountMismatch(
                        expected: count,
                        actual: payment.discardedCardIds.count
                    )
                }
            case let .resource(kind, count):
                let sources = resourceSources(for: kind, in: payment)
                guard sources.count == count else {
                    throw CommandValidationError.paymentResourceCountMismatch(
                        kind: kind,
                        expected: count,
                        actual: sources.count
                    )
                }
                try validateResourceSources(sources, kind: kind, playerState: playerState)
            }
        }
    }

    private func validateResourceSources(
        _ sources: [OceanSlotAddress],
        kind: ResourceKind,
        playerState: PlayerGameState
    ) throws {
        var availableBySource = Dictionary(
            uniqueKeysWithValues: playerState.ocean.slots.map { slot in
                (
                    slot.address,
                    slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
                )
            }
        )

        for source in sources {
            guard source.playerId == playerState.playerId,
                  let available = availableBySource[source],
                  available > 0
            else {
                throw CommandValidationError.paymentResourceUnavailable(kind: kind, source: source)
            }
            availableBySource[source] = available - 1
        }
    }

    private func applyFishPlayed(_ payload: FishPlayedEvent, to state: inout GameState) {
        guard var playerState = state.playerGameStates[payload.playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == payload.targetSlot })
        else {
            return
        }

        let discardedCardIds = Set(payload.payment.discardedCardIds + [payload.cardId])
        playerState.hand.removeAll { discardedCardIds.contains($0) }
        playerState.ocean.slots[slotIndex].fishCardId = payload.cardId
        applyResourcePayment(payload.payment, to: &playerState)

        state.deckState.discardPile.append(contentsOf: payload.payment.discardedCardIds)
        state.playerGameStates[payload.playerId] = playerState

        if let nextActivePlayerId = payload.nextActivePlayerId,
           let nextIndex = state.players.firstIndex(where: { $0.id == nextActivePlayerId }) {
            state.currentTurnIndex = nextIndex
            state.activePlayerId = nextActivePlayerId
        }
    }

    private func applyResourcePayment(
        _ payment: PlayFishPayment,
        to playerState: inout PlayerGameState
    ) {
        for source in payment.eggSources {
            removeResource(.egg, from: source, in: &playerState)
        }
        for source in payment.youngSources {
            removeResource(.young, from: source, in: &playerState)
        }
    }

    private func removeResource(
        _ kind: ResourceKind,
        from source: OceanSlotAddress,
        in playerState: inout PlayerGameState
    ) {
        guard let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == source }),
              let resourceIndex = playerState.ocean.slots[slotIndex].resources.firstIndex(where: { $0.kind == kind })
        else {
            return
        }

        playerState.ocean.slots[slotIndex].resources[resourceIndex].amount -= 1
        if playerState.ocean.slots[slotIndex].resources[resourceIndex].amount <= 0 {
            playerState.ocean.slots[slotIndex].resources.remove(at: resourceIndex)
        }
    }

    private func resourceSources(
        for kind: ResourceKind,
        in payment: PlayFishPayment
    ) -> [OceanSlotAddress] {
        if kind == .egg {
            return payment.eggSources
        }
        if kind == .young {
            return payment.youngSources
        }
        return []
    }

    private func isSupported(_ cost: Cost) -> Bool {
        switch cost {
        case .discardCards:
            return true
        case let .resource(kind, _):
            return kind == .egg || kind == .young
        }
    }

    private func card(withId cardId: CardID) -> Card? {
        (cardCatalog.starterFishCards + cardCatalog.fishCards).first { $0.id == cardId }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

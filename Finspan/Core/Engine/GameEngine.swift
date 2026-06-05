import Foundation

struct GameEngine {
    private static let turnsPerWeek = 6
    private static let finalWeek = 4

    private let rules: GameRuleSet
    private let cardCatalog: any CardCatalog
    private let diveBonusLayout: DiveSiteBonusLayout
    private let weeklyAchievementScorer: SideAWeeklyAchievementScorer
    private let finalScoreCalculator: FinalScoreCalculator

    init(
        rules: GameRuleSet = GameRuleSet(),
        cardCatalog: any CardCatalog = SampleCardCatalog(),
        diveBonusLayout: DiveSiteBonusLayout = .baseGame,
        weeklyAchievementScorer: SideAWeeklyAchievementScorer = SideAWeeklyAchievementScorer(),
        finalScoreCalculator: FinalScoreCalculator = FinalScoreCalculator()
    ) {
        self.rules = rules
        self.cardCatalog = cardCatalog
        self.diveBonusLayout = diveBonusLayout
        self.weeklyAchievementScorer = weeklyAchievementScorer
        self.finalScoreCalculator = finalScoreCalculator
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
            throw CommandValidationError.passTurnNotAllowed
        case let .playFish(payload):
            try validatePlayFish(payload, playerId: command.playerId, in: state)
        case let .dive(payload):
            try validateDive(payload, playerId: command.playerId, in: state)
        case let .resolvePendingChoice(payload):
            try validateResolvePendingChoice(payload, playerId: command.playerId, in: state)
        case .createRoom,
             .joinRoom,
             .leaveRoom,
             .setReady,
             .chooseSeat,
             .chooseColor,
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
            nextState.firstPlayerId = nil
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
            nextState.firstPlayerId = nextState.players[safe: startingIndex]?.id
            nextState.randomSeed = payload.randomSeed
            nextState.turnsCompletedThisWeek = 0
        case let .setupCompleted(payload):
            let setup = payload.setup
            let startingIndex = nextState.players.firstIndex(where: { $0.id == setup.startingPlayerId }) ?? 0
            nextState.phase = .playing
            nextState.currentWeek = 1
            nextState.currentTurnIndex = startingIndex
            nextState.activePlayerId = nextState.players[safe: startingIndex]?.id
            nextState.firstPlayerId = nextState.players[safe: startingIndex]?.id
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
            applyWeekEnded(payload, to: &nextState)
        case let .gameEnded(payload):
            nextState.phase = .gameEnded
            nextState.activePlayerId = nil
            nextState.finalScoreResult = payload.finalScoreResult
        case let .fishPlayed(payload):
            applyFishPlayed(payload, to: &nextState)
        case let .diverMoved(payload):
            applyDiverMoved(payload, to: &nextState)
        case let .pendingChoiceCreated(payload):
            nextState.pendingChoices[payload.choiceId] = payload
        case let .pendingChoiceResolved(payload):
            applyPendingChoiceEffects(payload.appliedEffects, to: &nextState)
            nextState.pendingChoices.removeValue(forKey: payload.choiceId)
            applyDiveQueueUpdate(payload.diveQueueUpdate, to: &nextState)
        case let .turnAdvanced(payload):
            applyTurnAdvanced(payload, to: &nextState)
        case .playerReadyChanged,
             .seatChanged,
             .colorChanged,
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
            let drafts: [DomainEventDraft] = [.fishPlayed(
                FishPlayedEvent(
                    playerId: command.playerId,
                    cardId: payload.cardId,
                    targetSlot: payload.targetSlot,
                    payment: payload.payment,
                    nextActivePlayerId: nil
                )
            )]
            return drafts + actionCompletionDrafts(
                afterApplying: drafts,
                actorPlayerId: command.playerId,
                in: state
            )
        case let .dive(payload):
            let bottomBonusAvailable = bottomBonusAvailable(
                for: payload.diveSite,
                playerId: command.playerId,
                in: state
            )
            let diveQueue = diveResolutionQueue(
                for: payload.diveSite,
                commandId: command.commandId,
                playerId: command.playerId,
                includeBottomBonus: bottomBonusAvailable,
                in: state
            )
            let diverMoved = DomainEventDraft.diverMoved(
                DiverMovedEvent(
                    playerId: command.playerId,
                    diveSite: payload.diveSite,
                    bottomBonusAvailable: bottomBonusAvailable,
                    bottomBonusClaimed: bottomBonusAvailable,
                    nextActivePlayerId: diveQueue == nil ? nextPlayer(after: command.playerId, in: state.players)?.id : nil,
                    diveResolutionQueue: diveQueue
                )
            )
            guard let firstChoice = diveQueue?.currentStep?.pendingChoice else {
                let drafts = [diverMoved]
                return drafts + actionCompletionDrafts(
                    afterApplying: drafts,
                    actorPlayerId: command.playerId,
                    in: state
                )
            }
            return [diverMoved, .pendingChoiceCreated(firstChoice)]
        case let .resolvePendingChoice(payload):
            let queueProgress = diveQueueProgressAfterResolving(payload, in: state)
            var drafts: [DomainEventDraft] = [
                .pendingChoiceResolved(
                    PendingChoiceResolvedEvent(
                        choiceId: payload.choiceId,
                        playerId: command.playerId,
                        resolution: payload.resolution,
                        appliedEffects: appliedEffects(
                            for: payload,
                            playerId: command.playerId,
                            in: state
                        ),
                        diveQueueUpdate: queueProgress.update
                    )
                )
            ]
            if let nextChoice = queueProgress.nextChoice {
                drafts.append(.pendingChoiceCreated(nextChoice))
                return drafts
            }
            if shouldAdvanceTurnAfterResolving(payload, playerId: command.playerId, in: state) {
                drafts.append(
                    contentsOf: actionCompletionDrafts(
                        afterApplying: drafts,
                        actorPlayerId: command.playerId,
                        in: state
                    )
                )
            }
            return drafts
        case let .chooseAbilityOption(payload):
            return [.abilityOptionChosen(
                AbilityOptionChosenEvent(
                    playerId: command.playerId,
                    optionId: payload.optionId
                )
            )]
        case .endTurn:
            return []
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

    private func actionCompletionDrafts(
        afterApplying drafts: [DomainEventDraft],
        actorPlayerId: PlayerID,
        in state: GameState
    ) -> [DomainEventDraft] {
        let projectedState = stateAfterApplying(drafts, to: state)
        guard projectedState.pendingChoices.isEmpty,
              projectedState.activeDiveQueue == nil
        else {
            return []
        }
        guard allDiversUsed(in: projectedState) else {
            return [
                .turnAdvanced(
                    TurnAdvancedEvent(
                        playerId: actorPlayerId,
                        nextPlayerId: nextPlayerWithAvailableDiver(after: actorPlayerId, in: projectedState)?.id
                    )
                )
            ]
        }
        let weekEnded = weekEndedEvent(in: projectedState)
        let weekEndedDraft = DomainEventDraft.weekEnded(weekEnded)
        guard weekEnded.isGameEndTriggered else {
            return [weekEndedDraft]
        }

        let endGamePendingState = stateAfterApplying([weekEndedDraft], to: projectedState)
        return [
            weekEndedDraft,
            .gameEnded(
                GameEndedEvent(
                    finalScoreResult: finalScoreCalculator.calculate(
                        in: endGamePendingState,
                        cardCatalog: cardCatalog
                    )
                )
            )
        ]
    }

    private func stateAfterApplying(_ drafts: [DomainEventDraft], to state: GameState) -> GameState {
        var projectedState = state
        for draft in drafts {
            apply(draft, to: &projectedState)
        }
        return projectedState
    }

    private func apply(_ draft: DomainEventDraft, to state: inout GameState) {
        switch draft {
        case let .fishPlayed(payload):
            applyFishPlayed(payload, to: &state)
        case let .diverMoved(payload):
            applyDiverMoved(payload, to: &state)
        case let .pendingChoiceCreated(payload):
            state.pendingChoices[payload.choiceId] = payload
        case let .pendingChoiceResolved(payload):
            applyPendingChoiceEffects(payload.appliedEffects, to: &state)
            state.pendingChoices.removeValue(forKey: payload.choiceId)
            applyDiveQueueUpdate(payload.diveQueueUpdate, to: &state)
        case let .turnAdvanced(payload):
            applyTurnAdvanced(payload, to: &state)
        case let .weekEnded(payload):
            applyWeekEnded(payload, to: &state)
        case let .gameEnded(payload):
            state.phase = .gameEnded
            state.activePlayerId = nil
            state.finalScoreResult = payload.finalScoreResult
        case .roomCreated,
             .playerJoined,
             .playerLeft,
             .playerReadyChanged,
             .seatChanged,
             .colorChanged,
             .gameStarted,
             .setupCompleted,
             .abilityOptionChosen,
             .turnEnded,
             .snapshotCreated:
            break
        }
    }

    private func allDiversUsed(in state: GameState) -> Bool {
        guard !state.playerGameStates.isEmpty else {
            return false
        }
        return state.playerGameStates.values.allSatisfy { $0.availableDivers == 0 }
    }

    private func nextPlayerWithAvailableDiver(after playerId: PlayerID, in state: GameState) -> Player? {
        guard !state.players.isEmpty,
              let currentIndex = state.players.firstIndex(where: { $0.id == playerId })
        else {
            return nil
        }

        for offset in 1...state.players.count {
            let index = (currentIndex + offset) % state.players.count
            let candidate = state.players[index]
            if (state.playerGameStates[candidate.id]?.availableDivers ?? 0) > 0 {
                return candidate
            }
        }
        return nil
    }

    private func weekEndedEvent(in state: GameState) -> WeekEndedEvent {
        let previousFirstPlayerId = state.firstPlayerId ?? state.players.first?.id
        let nextFirstPlayerId = previousFirstPlayerId.flatMap { nextPlayer(after: $0, in: state.players)?.id }
        let isGameEndTriggered = state.currentWeek >= Self.finalWeek
        let orderedPlayerStates = state.players.compactMap { state.playerGameStates[$0.id] }
        let achievementResults = isGameEndTriggered
            ? []
            : weeklyAchievementScorer.score(
                week: state.currentWeek,
                playerStates: orderedPlayerStates
            )
        return WeekEndedEvent(
            endedWeek: state.currentWeek,
            nextWeek: isGameEndTriggered ? nil : min(state.currentWeek + 1, Self.finalWeek),
            previousFirstPlayerId: previousFirstPlayerId,
            nextFirstPlayerId: isGameEndTriggered ? nil : nextFirstPlayerId,
            nextActivePlayerId: isGameEndTriggered ? nil : nextFirstPlayerId,
            isGameEndTriggered: isGameEndTriggered,
            achievementResults: achievementResults
        )
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
        guard state.activeDiveQueue == nil,
              !hasBlockingPendingChoices(for: playerId, in: state)
        else {
            throw CommandValidationError.unresolvedPendingChoices(playerId)
        }
        guard playerState.availableDivers > 0 else {
            throw CommandValidationError.noAvailableDiver
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
        guard targetSlot.content == .empty else {
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

    private func validateDive(
        _ payload: DiveCommand,
        playerId: PlayerID,
        in state: GameState
    ) throws {
        guard state.phase == .playing else {
            throw CommandValidationError.invalidPhase(state.phase)
        }
        guard state.activePlayerId == playerId else {
            throw CommandValidationError.notActivePlayer(
                expected: state.activePlayerId,
                actual: playerId
            )
        }
        guard DiveActionSite.baseGameSites.contains(payload.diveSite) else {
            throw CommandValidationError.invalidDiveSite(payload.diveSite)
        }
        guard state.activeDiveQueue == nil,
              !hasBlockingPendingChoices(for: playerId, in: state)
        else {
            throw CommandValidationError.unresolvedPendingChoices(playerId)
        }
        guard let playerState = state.playerGameStates[playerId] else {
            throw CommandValidationError.missingPlayerState(playerId)
        }
        guard playerState.availableDivers > 0 else {
            throw CommandValidationError.noAvailableDiver
        }
    }

    private func bottomBonusAvailable(
        for diveSite: DiveActionSite,
        playerId: PlayerID,
        in state: GameState
    ) -> Bool {
        guard let playerState = state.playerGameStates[playerId] else {
            return false
        }
        return !playerState.diveSitesReachedBottomThisWeek.contains(diveSite)
    }

    private func validateResolvePendingChoice(
        _ payload: ResolvePendingChoiceCommand,
        playerId: PlayerID,
        in state: GameState
    ) throws {
        guard let choice = state.pendingChoices[payload.choiceId] else {
            throw CommandValidationError.pendingChoiceNotFound(payload.choiceId)
        }
        guard choice.playerId == playerId else {
            throw CommandValidationError.pendingChoiceNotOwned(
                choiceId: payload.choiceId,
                expected: choice.playerId,
                actual: playerId
            )
        }
        if choice.diveQueueId != nil {
            guard let activeDiveQueue = state.activeDiveQueue,
                  activeDiveQueue.queueId == choice.diveQueueId,
                  activeDiveQueue.currentStep?.stepId == choice.diveStepId,
                  activeDiveQueue.currentStep?.pendingChoice.choiceId == choice.choiceId
            else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
        }
        if case .skip = payload.resolution, !choice.isOptional {
            throw CommandValidationError.pendingChoiceRequired(payload.choiceId)
        }
        switch payload.resolution {
        case .skip:
            return
        case let .draw(count):
            guard choice.kind == .drawFish, count == 1 else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
            guard !state.deckState.fishDrawPile.isEmpty else {
                // TODO: decide whether empty fish draw pile should become a no-op or reshuffle discard pile.
                throw CommandValidationError.fishDrawPileEmpty
            }
        case let .chooseTarget(target):
            guard choice.kind == .placeEgg || choice.kind == .hatchEgg else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
            try validatePendingChoiceTarget(
                target,
                for: choice,
                in: state
            )
        case let .recoverCard(cardId):
            guard choice.kind == .recoverFromDiscardOrDraw,
                  let playerState = state.playerGameStates[playerId],
                  playerState.discardPile.contains(cardId)
            else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
        case .drawFromDeck:
            guard choice.kind == .recoverFromDiscardOrDraw,
                  let playerState = state.playerGameStates[playerId],
                  playerState.discardPile.isEmpty
            else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
            guard !state.deckState.fishDrawPile.isEmpty else {
                throw CommandValidationError.fishDrawPileEmpty
            }
        case let .moveResource(source, target, kind):
            guard choice.kind == .moveYoungOrSchool else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
            try validateMoveResource(
                source: source,
                target: target,
                kind: kind,
                for: choice,
                in: state
            )
        case .chooseOption:
            throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
        }
    }

    private func validatePendingChoiceTarget(
        _ target: OceanSlotAddress,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard target.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              let slot = playerState.ocean.slots.first(where: { $0.address == target })
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        switch choice.kind {
        case .placeEgg:
            guard slot.content.hasFish,
                  resourceAmount(.egg, in: slot) == 0
            else {
                throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
            }
        case .hatchEgg:
            guard resourceAmount(.egg, in: slot) > 0 else {
                throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
            }
        case .drawFish,
             .recoverFromDiscardOrDraw,
             .moveYoungOrSchool,
             .bottomBonus,
             .placeholder,
             .unsupported:
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateMoveResource(
        source: OceanSlotAddress,
        target: OceanSlotAddress,
        kind: ResourceKind,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard source != target,
              source.playerId == choice.playerId,
              target.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              let sourceSlot = playerState.ocean.slots.first(where: { $0.address == source }),
              let targetSlot = playerState.ocean.slots.first(where: { $0.address == target }),
              kind == .young || kind == .school,
              resourceAmount(kind, in: sourceSlot) > 0
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        if kind == .school, resourceAmount(.school, in: targetSlot) > 0 {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        // TODO: Enforce the full straight-line movement and occupied-school path rules.
    }

    private func hasBlockingPendingChoices(for playerId: PlayerID, in state: GameState) -> Bool {
        state.pendingChoices.values.contains { choice in
            choice.playerId == playerId
        }
    }

    private func shouldAdvanceTurnAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        playerId: PlayerID,
        in state: GameState
    ) -> Bool {
        guard state.activePlayerId == playerId,
              let choice = state.pendingChoices[payload.choiceId],
              choice.playerId == playerId
        else {
            return false
        }

        if choice.diveQueueId != nil {
            guard let activeDiveQueue = state.activeDiveQueue,
                  activeDiveQueue.queueId == choice.diveQueueId
            else {
                return false
            }
            return activeDiveQueue.currentStepIndex + 1 >= activeDiveQueue.steps.count
        }

        return !state.pendingChoices.values.contains { pendingChoice in
            pendingChoice.playerId == playerId && pendingChoice.choiceId != payload.choiceId
        }
    }

    private func diveResolutionQueue(
        for diveSite: DiveActionSite,
        commandId: CommandID,
        playerId: PlayerID,
        includeBottomBonus: Bool,
        in state: GameState
    ) -> DiveResolutionQueue? {
        guard let playerState = state.playerGameStates[playerId] else {
            return nil
        }

        let queueId = "\(commandId)-dive-queue"
        let indexedBonuses = diveBonusLayout.bonuses(for: diveSite).enumerated().map { ($0.offset, $0.element) }
        let orderedBonuses = OceanZone.allCases.flatMap { zone in
            indexedBonuses.filter { _, bonus in
                bonus.position == .zone(zone)
            }
        } + indexedBonuses.filter { _, bonus in
            bonus.position == .bottom
        }
        let availableBonuses = orderedBonuses.filter { _, bonus in
            bonusIsAvailable(bonus, playerState: playerState, includeBottomBonus: includeBottomBonus)
        }
        let steps = availableBonuses.enumerated().map { stepIndex, indexedBonus in
            let (bonusIndex, bonus) = indexedBonus
            let stepId = "\(queueId)-step-\(stepIndex)"
            return DiveResolutionStep(
                stepId: stepId,
                source: diveResolutionStepSource(for: bonus.position),
                pendingChoice: pendingChoice(
                    for: bonus,
                    choiceId: "\(commandId)-dive-bonus-\(bonusIndex)",
                    playerId: playerId,
                    diveQueueId: queueId,
                    diveStepId: stepId
                )
            )
        }

        guard !steps.isEmpty else {
            return nil
        }

        return DiveResolutionQueue(
            queueId: queueId,
            playerId: playerId,
            diveSite: diveSite,
            steps: steps,
            currentStepIndex: 0
        )
    }

    private func diveResolutionStepSource(for position: DiveBonusPosition) -> DiveResolutionStepSource {
        switch position {
        case let .zone(zone):
            return .printedDiveBonus(zone)
        case .bottom:
            return .bottomBonus
        }
    }

    private func bonusIsAvailable(
        _ bonus: DiveBonusDefinition,
        playerState: PlayerGameState,
        includeBottomBonus: Bool
    ) -> Bool {
        switch bonus.position {
        case .bottom:
            return includeBottomBonus
        case let .zone(zone):
            return playerHasFish(in: bonus.diveSite, zone: zone, playerState: playerState)
        }
    }

    private func playerHasFish(
        in diveSite: DiveActionSite,
        zone: OceanZone,
        playerState: PlayerGameState
    ) -> Bool {
        guard let mappedDiveSite = diveBonusLayout.oceanDiveSite(for: diveSite) else {
            return false
        }
        let hasSlotFish = playerState.ocean.slots.contains { slot in
            slot.address.diveSite == mappedDiveSite
                && slot.address.zone == zone
                && slot.content.hasFish
        }
        return hasSlotFish
    }

    private func pendingChoice(
        for bonus: DiveBonusDefinition,
        choiceId: PendingChoiceID,
        playerId: PlayerID,
        diveQueueId: DiveResolutionQueueID,
        diveStepId: DiveResolutionStepID
    ) -> PendingChoice {
        PendingChoice(
            choiceId: choiceId,
            playerId: playerId,
            source: .diveBonus(bonus.diveSite),
            diveQueueId: diveQueueId,
            diveStepId: diveStepId,
            kind: pendingChoiceKind(for: bonus.kind),
            options: [],
            expectedInput: expectedInput(for: bonus.kind),
            isOptional: true,
            createdAtSequence: 0
        )
    }

    private func diveQueueProgressAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?) {
        guard let choice = state.pendingChoices[payload.choiceId],
              let queueId = choice.diveQueueId,
              var queue = state.activeDiveQueue,
              queue.queueId == queueId,
              queue.currentStep?.stepId == choice.diveStepId
        else {
            return (nil, nil)
        }

        queue.currentStepIndex += 1
        guard let nextChoice = queue.currentStep?.pendingChoice else {
            return (.completed(queueId: queue.queueId), nil)
        }
        return (.advanced(queue), nextChoice)
    }

    private func pendingChoiceKind(for bonusKind: DiveBonusKind) -> PendingChoiceKind {
        switch bonusKind {
        case .drawFish:
            return .drawFish
        case .placeEgg:
            return .placeEgg
        case .hatchEgg:
            return .hatchEgg
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw
        case .moveYoungOrSchool:
            return .moveYoungOrSchool
        case .unsupported:
            return .unsupported
        }
    }

    private func expectedInput(for bonusKind: DiveBonusKind) -> PendingChoiceExpectedInput {
        switch bonusKind {
        case .drawFish:
            return .none
        case .placeEgg,
             .hatchEgg:
            return .targetSlot
        case .recoverFromDiscardOrDraw:
            return .cardSelection
        case .moveYoungOrSchool:
            return .sourceAndTargetSlots
        case .unsupported:
            return .none
        }
    }

    private func appliedEffects(
        for payload: ResolvePendingChoiceCommand,
        playerId: PlayerID,
        in state: GameState
    ) -> [PendingChoiceAppliedEffect] {
        switch payload.resolution {
        case .skip:
            return [.none]
        case .draw:
            guard let cardId = state.deckState.fishDrawPile.first else {
                return [.none]
            }
            return [.drawFish(playerId: playerId, cardIds: [cardId])]
        case let .recoverCard(cardId):
            return [.recoverFromDiscard(playerId: playerId, cardId: cardId)]
        case .drawFromDeck:
            guard let cardId = state.deckState.fishDrawPile.first else {
                return [.none]
            }
            return [.drawFish(playerId: playerId, cardIds: [cardId])]
        case let .moveResource(source, target, kind):
            return [.moveResource(source: source, target: target, kind: kind, amount: 1)]
        case let .chooseTarget(target):
            guard let choice = state.pendingChoices[payload.choiceId] else {
                return [.none]
            }
            switch choice.kind {
            case .placeEgg:
                return [.placeEgg(target: target, amount: 1)]
            case .hatchEgg:
                return [.hatchEgg(target: target, amount: 1)]
            case .drawFish,
                 .recoverFromDiscardOrDraw,
                 .moveYoungOrSchool,
                 .bottomBonus,
                 .placeholder,
                 .unsupported:
                return [.none]
            }
        case .chooseOption:
            return [.none]
        }
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
        playerState.availableDivers = max(playerState.availableDivers - 1, 0)
        playerState.usedDivers += 1
        playerState.ocean.slots[slotIndex].content = .fishCard(payload.cardId)
        applyResourcePayment(payload.payment, to: &playerState)

        playerState.discardPile.append(contentsOf: payload.payment.discardedCardIds)
        state.playerGameStates[payload.playerId] = playerState

        if let nextActivePlayerId = payload.nextActivePlayerId,
           let nextIndex = state.players.firstIndex(where: { $0.id == nextActivePlayerId }) {
            state.currentTurnIndex = nextIndex
            state.activePlayerId = nextActivePlayerId
        }
    }

    private func applyDiverMoved(_ payload: DiverMovedEvent, to state: inout GameState) {
        guard var playerState = state.playerGameStates[payload.playerId] else {
            return
        }

        playerState.availableDivers = max(playerState.availableDivers - 1, 0)
        playerState.usedDivers += 1
        if payload.bottomBonusAvailable {
            playerState.diveSitesReachedBottomThisWeek.insert(payload.diveSite)
        }
        state.playerGameStates[payload.playerId] = playerState
        state.activeDiveQueue = payload.diveResolutionQueue
    }

    private func applyDiveQueueUpdate(
        _ update: DiveResolutionQueueUpdate?,
        to state: inout GameState
    ) {
        guard let update else {
            return
        }

        switch update {
        case let .advanced(queue):
            state.activeDiveQueue = queue
        case let .completed(queueId):
            if state.activeDiveQueue?.queueId == queueId {
                state.activeDiveQueue = nil
            }
        }
    }

    private func applyTurnAdvanced(_ payload: TurnAdvancedEvent, to state: inout GameState) {
        guard let nextActivePlayerId = payload.nextPlayerId,
              let nextIndex = state.players.firstIndex(where: { $0.id == nextActivePlayerId })
        else {
            return
        }

        state.currentTurnIndex = nextIndex
        state.activePlayerId = nextActivePlayerId
        state.turnsCompletedThisWeek += 1
    }

    private func applyWeekEnded(_ payload: WeekEndedEvent, to state: inout GameState) {
        state.turnsCompletedThisWeek = 0
        state.weeklyAchievementResults.append(contentsOf: payload.achievementResults)

        if payload.isGameEndTriggered {
            state.phase = .endGamePending
            state.currentWeek = payload.endedWeek
            state.activePlayerId = nil
            state.firstPlayerId = payload.previousFirstPlayerId
            return
        }

        state.phase = .playing
        state.currentWeek = payload.nextWeek ?? min(payload.endedWeek + 1, Self.finalWeek)
        state.firstPlayerId = payload.nextFirstPlayerId

        if let nextActivePlayerId = payload.nextActivePlayerId,
           let nextIndex = state.players.firstIndex(where: { $0.id == nextActivePlayerId }) {
            state.currentTurnIndex = nextIndex
            state.activePlayerId = nextActivePlayerId
        } else if let nextFirstPlayerId = payload.nextFirstPlayerId,
                  let nextIndex = state.players.firstIndex(where: { $0.id == nextFirstPlayerId }) {
            state.currentTurnIndex = nextIndex
            state.activePlayerId = nextFirstPlayerId
        }

        for playerId in state.playerGameStates.keys {
            state.playerGameStates[playerId]?.availableDivers = 6
            state.playerGameStates[playerId]?.usedDivers = 0
            state.playerGameStates[playerId]?.diveSitesReachedBottomThisWeek = []
        }
    }

    private func applyPendingChoiceEffects(
        _ effects: [PendingChoiceAppliedEffect],
        to state: inout GameState
    ) {
        for effect in effects {
            switch effect {
            case .none,
                 .placeholder:
                break
            case let .drawFish(playerId, cardIds):
                guard var playerState = state.playerGameStates[playerId] else {
                    break
                }
                for cardId in cardIds {
                    if let deckIndex = state.deckState.fishDrawPile.firstIndex(of: cardId) {
                        state.deckState.fishDrawPile.remove(at: deckIndex)
                    }
                    playerState.hand.append(cardId)
                }
                state.playerGameStates[playerId] = playerState
            case let .recoverFromDiscard(playerId, cardId):
                guard var playerState = state.playerGameStates[playerId],
                      let discardIndex = playerState.discardPile.firstIndex(of: cardId)
                else {
                    break
                }
                playerState.discardPile.remove(at: discardIndex)
                playerState.hand.append(cardId)
                state.playerGameStates[playerId] = playerState
            case let .placeEgg(target, amount):
                applyResourceChange(.egg, amount: amount, at: target, to: &state)
            case let .hatchEgg(target, amount):
                applyResourceChange(.egg, amount: -amount, at: target, to: &state)
                applyResourceChange(.young, amount: amount, at: target, to: &state)
            case let .moveResource(source, target, kind, amount):
                applyResourceChange(kind, amount: -amount, at: source, to: &state)
                applyResourceChange(kind, amount: amount, at: target, to: &state)
            }
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

    private func applyResourceChange(
        _ kind: ResourceKind,
        amount: Int,
        at target: OceanSlotAddress,
        to state: inout GameState
    ) {
        guard amount != 0,
              var playerState = state.playerGameStates[target.playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == target })
        else {
            return
        }

        if let resourceIndex = playerState.ocean.slots[slotIndex].resources.firstIndex(where: { $0.kind == kind }) {
            playerState.ocean.slots[slotIndex].resources[resourceIndex].amount += amount
            if playerState.ocean.slots[slotIndex].resources[resourceIndex].amount <= 0 {
                playerState.ocean.slots[slotIndex].resources.remove(at: resourceIndex)
            }
        } else if amount > 0 {
            playerState.ocean.slots[slotIndex].resources.append(
                ResourceQuantity(kind: kind, amount: amount)
            )
        }

        if kind == .young && amount > 0 {
            applySchoolFormationIfNeeded(to: &playerState.ocean.slots[slotIndex])
        }

        state.playerGameStates[target.playerId] = playerState
    }

    private func applySchoolFormationIfNeeded(to slot: inout OceanSlot) {
        // School formation is a deterministic automatic base game rule, not a player choice.
        guard slot.youngCount >= 3, !slot.hasSchool else {
            return
        }

        updateResource(.young, amountDelta: -3, in: &slot)
        updateResource(.school, amountDelta: 1, in: &slot)
    }

    private func updateResource(
        _ kind: ResourceKind,
        amountDelta: Int,
        in slot: inout OceanSlot
    ) {
        guard amountDelta != 0 else {
            return
        }

        if let resourceIndex = slot.resources.firstIndex(where: { $0.kind == kind }) {
            slot.resources[resourceIndex].amount += amountDelta
            if slot.resources[resourceIndex].amount <= 0 {
                slot.resources.remove(at: resourceIndex)
            }
        } else if amountDelta > 0 {
            slot.resources.append(ResourceQuantity(kind: kind, amount: amountDelta))
        }
    }

    private func resourceAmount(_ kind: ResourceKind, in slot: OceanSlot) -> Int {
        slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
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

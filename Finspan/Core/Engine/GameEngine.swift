import Foundation

struct GameEngine {
    private static let turnsPerWeek = 6
    private static let finalWeek = 4

    private let rules: GameRuleSet
    private let cardCatalog: any CardCatalog
    private let abilityResolver: AbilityResolver
    private let diveBonusLayout: DiveSiteBonusLayout
    private let weeklyAchievementScorer: SideAWeeklyAchievementScorer
    private let finalScoreCalculator: FinalScoreCalculator

    init(
        rules: GameRuleSet = GameRuleSet(),
        cardCatalog: any CardCatalog = SampleCardCatalog(),
        abilityResolver: AbilityResolver = AbilityResolver(),
        diveBonusLayout: DiveSiteBonusLayout = .baseGame,
        weeklyAchievementScorer: SideAWeeklyAchievementScorer = SideAWeeklyAchievementScorer(),
        finalScoreCalculator: FinalScoreCalculator = FinalScoreCalculator()
    ) {
        self.rules = rules
        self.cardCatalog = cardCatalog
        self.abilityResolver = abilityResolver
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
        case let .resolveEffectNode(payload):
            try validateResolveEffectNode(payload, playerId: command.playerId, in: state)
        case let .skipEffectNode(payload):
            try validateSkipEffectNode(payload, playerId: command.playerId, in: state)
        case let .skipEffectExecution(payload):
            try validateSkipEffectExecution(payload, playerId: command.playerId, in: state)
        case let .activateGameEndAbility(payload):
            try validateActivateGameEndAbility(payload, playerId: command.playerId, in: state)
        case .finishGameEndAbilities:
            try validateFinishGameEndAbilities(playerId: command.playerId, in: state)
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
        return try makeEventDrafts(from: command, in: state)
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
            nextState.weeklyGoals = setup.weeklyGoals
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
        case let .gameEndAbilityActivated(payload):
            nextState.activatedGameEndAbilitySourceIds.insert(payload.source.id)
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

    private func makeEventDrafts(from command: PlayerCommand, in state: GameState) throws -> [DomainEventDraft] {
        switch command.payload {
        case let .createRoom(payload):
            return [.roomCreated(
                RoomCreatedEvent(
                    roomCode: payload.roomCode,
                    hostPlayerId: command.playerId,
                    hostDisplayName: payload.displayName,
                    hostAvatarSymbol: payload.avatarSymbol,
                    gameConfig: payload.gameConfig
                )
            )]
        case let .joinRoom(payload):
            return [.playerJoined(
                PlayerJoinedEvent(
                    player: RoomPlayer(
                        playerId: command.playerId,
                        displayName: payload.displayName,
                        avatarSymbol: payload.avatarSymbol
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
            let fishPlayed = DomainEventDraft.fishPlayed(
                FishPlayedEvent(
                    playerId: command.playerId,
                    cardId: payload.cardId,
                    targetSlot: payload.targetSlot,
                    payment: payload.payment,
                    nextActivePlayerId: nil
                )
            )
            var drafts: [DomainEventDraft] = [fishPlayed]
            if let choice = whenPlayedPendingChoice(
                for: payload.cardId,
                sourceAddress: payload.targetSlot,
                choiceId: "\(command.commandId)-when-played-ability",
                playerId: command.playerId,
                in: state
            ) {
                drafts.append(.pendingChoiceCreated(choice))
                return drafts
            }
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
            return pendingChoiceResolvedDrafts(for: payload, command: command, in: state)
        case let .resolveEffectNode(payload):
            let legacyPayload = try nativeResolvePendingChoiceCommand(for: payload, in: state)
            return pendingChoiceResolvedDrafts(for: legacyPayload, command: command, in: state)
        case let .skipEffectNode(payload):
            let legacyPayload = try nativeSkipPendingChoiceCommand(for: payload, in: state)
            return pendingChoiceResolvedDrafts(for: legacyPayload, command: command, in: state)
        case let .skipEffectExecution(payload):
            let legacyPayload = try nativeSkipExecutionPendingChoiceCommand(for: payload, in: state)
            return pendingChoiceResolvedDrafts(for: legacyPayload, command: command, in: state)
        case let .chooseAbilityOption(payload):
            return [.abilityOptionChosen(
                AbilityOptionChosenEvent(
                    playerId: command.playerId,
                    optionId: payload.optionId
                )
            )]
        case let .activateGameEndAbility(payload):
            guard let choice = gameEndAbilityPendingChoice(
                source: payload.source,
                commandId: command.commandId,
                in: state
            ) else {
                return []
            }
            return [.pendingChoiceCreated(choice)]
        case .finishGameEndAbilities:
            return [
                .gameEnded(
                    GameEndedEvent(
                        finalScoreResult: finalScoreCalculator.calculate(
                            in: state,
                            cardCatalog: cardCatalog
                        )
                    )
                )
            ]
        case .endTurn:
            return []
        }
    }

    private func pendingChoiceResolvedDrafts(
        for payload: ResolvePendingChoiceCommand,
        command: PlayerCommand,
        in state: GameState
    ) -> [DomainEventDraft] {
        let queueProgress = diveQueueProgressAfterResolving(payload, in: state)
        let nonQueueNextChoice = nonQueueCompoundChoiceAfterResolving(payload, in: state)
        let resolvedChoice = state.pendingChoices[payload.choiceId]
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
        if let nextChoice = nonQueueNextChoice {
            if shouldMarkGameEndSourceBeforeNextChoice(payload),
               let source = gameEndAbilitySource(for: resolvedChoice) {
                drafts.append(.gameEndAbilityActivated(GameEndAbilityActivatedEvent(source: source)))
            }
            drafts.append(.pendingChoiceCreated(nextChoice))
            return drafts
        }
        if let source = gameEndAbilitySource(for: resolvedChoice) {
            drafts.append(.gameEndAbilityActivated(GameEndAbilityActivatedEvent(source: source)))
        }
        let completionActorPlayerId = resolvedChoice?.allPlayersProgress?.sourcePlayerId ?? command.playerId
        if shouldAdvanceTurnAfterResolving(payload, playerId: completionActorPlayerId, in: state) {
            drafts.append(
                contentsOf: actionCompletionDrafts(
                    afterApplying: drafts,
                    actorPlayerId: completionActorPlayerId,
                    in: state
                )
            )
        }
        return drafts
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

        return [weekEndedDraft]
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
        case let .gameEndAbilityActivated(payload):
            state.activatedGameEndAbilitySourceIds.insert(payload.source.id)
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
                playerStates: orderedPlayerStates,
                weeklyGoals: state.weeklyGoals,
                cardCatalog: cardCatalog,
                abilityResolver: abilityResolver
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
        try validateFishPlacement(card, targetSlot: targetSlot, playerState: playerState)

        try validatePayment(payload.payment, for: card, payload: payload, playerState: playerState)
    }

    private func validateFishPlacement(
        _ card: Card,
        targetSlot: OceanSlot,
        playerState: PlayerGameState
    ) throws {
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
        try validateRequirements(card.requirements, targetSlot: targetSlot, playerState: playerState)

        if let existingLength = try visibleFishLength(in: targetSlot.content) {
            guard card.lengthCm > existingLength else {
                throw CommandValidationError.targetFishTooLongToCover(
                    target: targetSlot.address,
                    newFishLengthCm: card.lengthCm,
                    existingFishLengthCm: existingLength
                )
            }
        } else if card.requiresCoveringShorterFish {
            throw CommandValidationError.targetMustCoverShorterFish(targetSlot.address)
        }
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

    private func validateRequirements(
        _ requirements: [Requirement],
        targetSlot: OceanSlot,
        playerState: PlayerGameState
    ) throws {
        for requirement in requirements {
            guard let coralRequirement = requirement.coralRequirement else {
                throw CommandValidationError.unsupportedRequirement(requirement)
            }
            try validateCoralRequirement(
                coralRequirement,
                targetSlot: targetSlot,
                ocean: playerState.ocean
            )
        }
    }

    private func validateCoralRequirement(
        _ requirement: CoralRequirement,
        targetSlot: OceanSlot,
        ocean: OceanState
    ) throws {
        guard targetSlot.address.zone == .sunlit else {
            throw CommandValidationError.coralRequirementMustBeSunlit(targetSlot.address)
        }
        if requirement.diveSite != .any,
           requirement.diveSite.rawValue != targetSlot.address.diveSite.rawValue {
            throw CommandValidationError.coralRequirementDiveSiteMismatch(
                expected: requirement.diveSite,
                actual: targetSlot.address.diveSite
            )
        }
        guard let reef = ocean.coralReefs.first(where: { $0.diveSite == targetSlot.address.diveSite }) else {
            throw CommandValidationError.coralReefMissing(targetSlot.address.diveSite)
        }
        guard reef.coralCount >= requirement.count else {
            throw CommandValidationError.insufficientCoral(
                diveSite: reef.diveSite,
                required: requirement.count,
                actual: reef.coralCount
            )
        }
    }

    private func visibleFishLength(in content: OceanSlotContent) throws -> Int? {
        switch content {
        case .empty:
            return nil
        case let .forageFish(fish):
            return fish.lengthCm
        case let .fishCard(cardId):
            guard let card = card(withId: cardId) else {
                throw CommandValidationError.unknownCard(cardId)
            }
            return card.lengthCm
        }
    }

    private func consumedFish(from content: OceanSlotContent) -> ConsumedFish? {
        switch content {
        case .empty:
            return nil
        case let .forageFish(fish):
            return ConsumedFish(forageFish: fish)
        case let .fishCard(cardId):
            return ConsumedFish(cardId: cardId, lengthCm: card(withId: cardId)?.lengthCm)
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
            guard choice.kind == .drawFish,
                  count > 0,
                  count == drawCount(for: choice)
            else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
            guard !state.deckState.fishDrawPile.isEmpty else {
                // TODO: decide whether empty fish draw pile should become a no-op or reshuffle discard pile.
                throw CommandValidationError.fishDrawPileEmpty
            }
        case let .chooseTarget(target):
            guard choice.kind == .placeEgg
                || choice.kind == .hatchEgg
                || choice.kind == .placeYoung
                || choice.kind == .placeEggOnMatchingFish
            else {
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
            guard choice.kind == .recoverFromDiscardOrDraw else {
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
        case let .gainCoralWithEgg(source):
            try validateCoralPayment(
                .egg(source: source),
                for: choice,
                in: state
            )
        case let .gainCoralWithYoung(source):
            try validateCoralPayment(
                .young(source: source),
                for: choice,
                in: state
            )
        case let .gainCoralByDiscard(cardId):
            try validateCoralPayment(
                .discard(cardId: cardId),
                for: choice,
                in: state
            )
        case let .gainCoralFromAbility(diveSite):
            try validateAbilityCoralGain(diveSite: diveSite, for: choice, in: state)
        case let .chooseScatterSchoolSource(source):
            try validateScatterSchoolSource(source, for: choice, in: state)
        case let .placeScatterSchoolYoung(target):
            try validateScatterSchoolYoungTarget(target, for: choice, in: state)
        case let .scatterSchool(source, targets):
            try validateScatterSchool(source: source, targets: targets, for: choice, in: state)
        case let .chooseConsumeFishConsumer(consumerSlot):
            try validateConsumeFishConsumer(consumerSlot, for: choice, in: state)
        case let .consumeFishFromHand(cardId):
            try validateConsumeFishFromHand(cardId, for: choice, in: state)
        case let .consumeFishFromHandWithConsumer(consumerSlot, consumedCardId):
            try validateConsumeFishFromHand(
                consumedCardId,
                consumerSlot: consumerSlot,
                for: choice,
                in: state
            )
        case let .chooseFreePlayFish(cardId):
            try validateFreePlayFishSelection(cardId, for: choice, in: state)
        case let .playFishForFree(cardId, targetSlot):
            try validatePlayFishForFree(cardId: cardId, targetSlot: targetSlot, for: choice, in: state)
        case let .choosePlayFishFromHand(cardId):
            try validatePlayFishFromHandSelection(cardId, for: choice, in: state)
        case let .choosePlayFishFromHandTarget(targetSlot):
            try validatePlayFishFromHandTarget(targetSlot, for: choice, in: state)
        case let .playFishFromHand(cardId, targetSlot, payment):
            try validatePlayFishFromHand(
                cardId: cardId,
                targetSlot: targetSlot,
                payment: payment,
                for: choice,
                in: state
            )
        case .chooseOption:
            throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
        case let .chooseAbilityEffect(effect):
            guard choice.kind == .compoundAbility,
                  abilityProgressCanChoose(effect, in: choice, state: state)
            else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
        case .finishAbility:
            if choice.kind == .placeEggOnMatchingFish,
               case let .placeEggOnMatchingFish(_, mode) = selectedEffect(for: choice),
               mode == .onEachEligibleFish,
               choice.isOptional {
                return
            }
            guard choice.kind == .compoundAbility, choice.isOptional else {
                throw CommandValidationError.invalidPendingChoiceResolution(payload.choiceId)
            }
        }
    }

    private func validateResolveEffectNode(
        _ payload: ResolveEffectNodeCommand,
        playerId: PlayerID,
        in state: GameState
    ) throws {
        let legacyPayload = try nativeResolvePendingChoiceCommand(for: payload, in: state)
        try validateResolvePendingChoice(legacyPayload, playerId: playerId, in: state)
    }

    private func validateSkipEffectNode(
        _ payload: SkipEffectNodeCommand,
        playerId: PlayerID,
        in state: GameState
    ) throws {
        let legacyPayload = try nativeSkipPendingChoiceCommand(for: payload, in: state)
        try validateResolvePendingChoice(legacyPayload, playerId: playerId, in: state)
    }

    private func validateSkipEffectExecution(
        _ payload: SkipEffectExecutionCommand,
        playerId: PlayerID,
        in state: GameState
    ) throws {
        let legacyPayload = try nativeSkipExecutionPendingChoiceCommand(for: payload, in: state)
        try validateResolvePendingChoice(legacyPayload, playerId: playerId, in: state)
    }

    private func nativeResolvePendingChoiceCommand(
        for payload: ResolveEffectNodeCommand,
        in state: GameState
    ) throws -> ResolvePendingChoiceCommand {
        let intent = PendingEffectIntent.resolveEffect(
            executionId: payload.executionId,
            effectNodeId: payload.effectNodeId,
            sourcePlayerId: payload.sourcePlayerId,
            targetPlayerId: payload.targetPlayerId,
            payload: payload.payload
        )
        return try nativePendingChoiceCommand(for: intent, in: state)
    }

    private func nativeSkipPendingChoiceCommand(
        for payload: SkipEffectNodeCommand,
        in state: GameState
    ) throws -> ResolvePendingChoiceCommand {
        let intent = PendingEffectIntent.skipEffect(
            executionId: payload.executionId,
            effectNodeId: payload.effectNodeId,
            sourcePlayerId: payload.sourcePlayerId,
            targetPlayerId: payload.targetPlayerId
        )
        return try nativePendingChoiceCommand(for: intent, in: state)
    }

    private func nativeSkipExecutionPendingChoiceCommand(
        for payload: SkipEffectExecutionCommand,
        in state: GameState
    ) throws -> ResolvePendingChoiceCommand {
        let intent = PendingEffectIntent.skipRemaining(
            executionId: payload.executionId,
            sourcePlayerId: payload.sourcePlayerId,
            targetPlayerId: payload.targetPlayerId
        )
        return try nativePendingChoiceCommand(for: intent, in: state)
    }

    private func nativePendingChoiceCommand(
        for intent: PendingEffectIntent,
        in state: GameState
    ) throws -> ResolvePendingChoiceCommand {
        guard let choice = pendingChoice(forExecutionId: intent.executionId, in: state) else {
            throw CommandValidationError.invalidPendingChoiceResolution(intent.executionId)
        }
        let effectSet = choice.v2PendingEffectSet
        guard intent.sourcePlayerId == effectSet.sourcePlayerId,
              intent.targetPlayerId == effectSet.targetPlayerId
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        do {
            return ResolvePendingChoiceCommand(
                choiceId: choice.choiceId,
                resolution: try AbilityEngineV2Adapter.nativeResolution(for: intent, in: choice)
            )
        } catch is PendingEffectIntentAdapterError {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func pendingChoice(
        forExecutionId executionId: AbilityExecutionId,
        in state: GameState
    ) -> PendingChoice? {
        state.pendingChoices.values
            .sorted { $0.choiceId < $1.choiceId }
            .first { $0.v2PendingEffectSet.executionId == executionId }
    }

    private func validateActivateGameEndAbility(
        _ payload: ActivateGameEndAbilityCommand,
        playerId: PlayerID,
        in state: GameState
    ) throws {
        guard state.phase == .endGamePending else {
            throw CommandValidationError.invalidPhase(state.phase)
        }
        guard payload.source.playerId == playerId else {
            throw CommandValidationError.inactivePlayer(expected: payload.source.playerId, actual: playerId)
        }
        guard state.pendingChoices.isEmpty else {
            throw CommandValidationError.unresolvedPendingChoices(playerId)
        }
        guard !state.activatedGameEndAbilitySourceIds.contains(payload.source.id),
              let availableSource = gameEndAbilitySources(for: playerId, in: state)
                .first(where: { $0.source == payload.source }),
              availableSource.isSupported
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(payload.source.id)
        }
    }

    private func validateFinishGameEndAbilities(
        playerId: PlayerID,
        in state: GameState
    ) throws {
        guard state.phase == .endGamePending else {
            throw CommandValidationError.invalidPhase(state.phase)
        }
        guard state.players.contains(where: { $0.id == playerId }) else {
            throw CommandValidationError.missingPlayerState(playerId)
        }
        guard state.pendingChoices.isEmpty else {
            throw CommandValidationError.unresolvedPendingChoices(playerId)
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
        case .placeYoung:
            guard slot.content.hasFish || slot.content == .empty else {
                throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
            }
        case .placeEggOnMatchingFish:
            guard choice.expectedInput == .matchingEggTarget,
                  matchingEggTargetIsLegal(slot, for: choice)
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
             .gainCoral,
             .scatterSchool,
             .consumeFishFromHand,
             .playFishForFree,
             .playFishFromHand,
             .compoundAbility,
             .bottomBonus,
             .placeholder,
             .unsupported:
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateScatterSchoolSource(
        _ source: OceanSlotAddress,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .scatterSchool,
              choice.expectedInput == .scatterSchoolSource,
              source.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              let sourceSlot = playerState.ocean.slots.first(where: { $0.address == source }),
              resourceAmount(.school, in: sourceSlot) > 0
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateScatterSchoolYoungTarget(
        _ target: OceanSlotAddress,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .scatterSchool,
              choice.expectedInput == .scatterSchoolYoungTarget || choice.expectedInput == .scatterSchoolSource,
              target.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.ocean.slots.contains(where: { $0.address == target })
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        let progress = scatterSchoolProgress(for: choice, playerState: playerState)
        guard progress.targetSlots.contains(target) == false,
              progress.completedTargetCount < progress.requiredTargetCount
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        if progress.requiresSchoolSource {
            guard progress.sourceSlot != nil else {
                throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
            }
        } else if playerHasSchool(playerState) {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateScatterSchool(
        source: OceanSlotAddress,
        targets: [OceanSlotAddress],
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        try validateScatterSchoolSource(source, for: choice, in: state)
        guard let playerState = state.playerGameStates[choice.playerId] else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        let requiredTargetCount = scatterSchoolProgress(for: choice, playerState: playerState).requiredTargetCount
        guard targets.count == requiredTargetCount,
              Set(targets).count == targets.count
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        var targetProgress = ScatterSchoolProgress(
            sourceSlot: source,
            targetSlots: [],
            requiredTargetCount: requiredTargetCount,
            requiresSchoolSource: true
        )
        for target in targets {
            var targetChoice = choice
            targetChoice.expectedInput = .scatterSchoolYoungTarget
            targetChoice.scatterSchoolProgress = targetProgress
            try validateScatterSchoolYoungTarget(target, for: targetChoice, in: state)
            targetProgress.targetSlots.append(target)
        }
    }

    private func scatterSchoolProgress(
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> ScatterSchoolProgress {
        if let progress = choice.scatterSchoolProgress {
            return progress
        }
        let hasSchool = playerHasSchool(playerState)
        return ScatterSchoolProgress(
            requiredTargetCount: hasSchool ? 4 : 1,
            requiresSchoolSource: hasSchool
        )
    }

    private func playerHasSchool(_ playerState: PlayerGameState) -> Bool {
        playerState.ocean.slots.contains { resourceAmount(.school, in: $0) > 0 }
    }

    private func validateConsumeFishConsumer(
        _ consumerSlot: OceanSlotAddress,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .consumeFishFromHand,
              choice.expectedInput == .consumeFishConsumer,
              consumerSlot.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              let slot = playerState.ocean.slots.first(where: { $0.address == consumerSlot }),
              case let .fishCard(cardId) = slot.content,
              card(withId: cardId) != nil
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateConsumeFishFromHand(
        _ consumedCardId: CardID,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .consumeFishFromHand,
              choice.expectedInput == .consumeFishHandCard,
              let consumerSlotAddress = choice.consumeFishFromHandProgress?.consumerSlot,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.hand.contains(consumedCardId),
              let consumerSlot = playerState.ocean.slots.first(where: { $0.address == consumerSlotAddress }),
              case let .fishCard(consumerCardId) = consumerSlot.content,
              let consumerCard = card(withId: consumerCardId),
              let consumedCard = card(withId: consumedCardId),
              consumedCard.lengthCm < consumerCard.lengthCm
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateConsumeFishFromHand(
        _ consumedCardId: CardID,
        consumerSlot consumerSlotAddress: OceanSlotAddress,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .consumeFishFromHand,
              consumerSlotAddress.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.hand.contains(consumedCardId),
              let consumerSlot = playerState.ocean.slots.first(where: { $0.address == consumerSlotAddress }),
              case let .fishCard(consumerCardId) = consumerSlot.content,
              let consumerCard = card(withId: consumerCardId),
              let consumedCard = card(withId: consumedCardId),
              consumedCard.lengthCm < consumerCard.lengthCm
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateFreePlayFishSelection(
        _ cardId: CardID,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .playFishForFree,
              choice.expectedInput == .freePlayHandCard,
              let playerState = state.playerGameStates[choice.playerId],
              freePlaySourceConditionSatisfied(for: choice, playerState: playerState),
              playerState.hand.contains(cardId),
              let card = card(withId: cardId),
              freePlayFilterMatches(card, for: choice)
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validatePlayFishForFree(
        cardId: CardID,
        targetSlot: OceanSlotAddress,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .playFishForFree,
              targetSlot.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.hand.contains(cardId),
              let card = card(withId: cardId),
              freePlayFilterMatches(card, for: choice),
              let slot = playerState.ocean.slots.first(where: { $0.address == targetSlot })
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        guard freePlaySourceConditionSatisfied(for: choice, playerState: playerState),
              freePlayPlacementConstraintMatches(targetSlot, for: choice, playerState: playerState)
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        try validateFishPlacement(card, targetSlot: slot, playerState: playerState)
    }

    private func validatePlayFishFromHandSelection(
        _ cardId: CardID,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .playFishFromHand,
              choice.expectedInput == .playFishFromHandCard,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.hand.contains(cardId),
              let card = card(withId: cardId),
              handFishFilterMatches(card, for: choice)
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validatePlayFishFromHandTarget(
        _ targetSlot: OceanSlotAddress,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .playFishFromHand,
              choice.expectedInput == .playFishFromHandTargetSlot,
              let selectedCardId = choice.playFishFromHandProgress?.selectedCardId,
              targetSlot.playerId == choice.playerId,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.hand.contains(selectedCardId),
              let card = card(withId: selectedCardId),
              handFishFilterMatches(card, for: choice),
              let slot = playerState.ocean.slots.first(where: { $0.address == targetSlot })
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        guard placementConstraintMatches(slot.address, for: choice, playerState: playerState) else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        try validateFishPlacement(card, targetSlot: slot, playerState: playerState)
    }

    private func validatePlayFishFromHand(
        cardId: CardID,
        targetSlot: OceanSlotAddress,
        payment: PlayFishPayment,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .playFishFromHand,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.hand.contains(cardId),
              let card = card(withId: cardId),
              handFishFilterMatches(card, for: choice),
              let slot = playerState.ocean.slots.first(where: { $0.address == targetSlot })
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        guard placementConstraintMatches(slot.address, for: choice, playerState: playerState) else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        try validateFishPlacement(card, targetSlot: slot, playerState: playerState)
        try validatePayment(
            payment,
            for: card,
            payload: PlayFishCommand(cardId: cardId, targetSlot: targetSlot, payment: payment),
            playerState: playerState
        )
    }

    private func handFishFilterMatches(_ card: Card, for choice: PendingChoice) -> Bool {
        guard case let .playFishFromHand(filter, _, _) = selectedEffect(for: choice) else {
            return false
        }
        return handFishFilterMatches(card, filter: filter)
    }

    private func handFishFilterMatches(_ card: Card, filter: HandFishFilter) -> Bool {
        switch filter {
        case .any:
            return true
        case let .tag(kind):
            return card.tags.contains { $0.kind == kind && $0.count > 0 }
        case let .lengthBucket(bucket):
            return lengthBucket(for: card.lengthCm) == bucket
        case .unsupported:
            return false
        }
    }

    private func placementConstraintMatches(
        _ address: OceanSlotAddress,
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        guard case let .playFishFromHand(_, placement, _) = selectedEffect(for: choice) else {
            return false
        }
        return placementConstraintMatches(address, placement: placement, playerState: playerState)
    }

    private func placementConstraintMatches(
        _ address: OceanSlotAddress,
        placement: FishPlacementConstraint,
        playerState: PlayerGameState? = nil,
        sourceAddress: OceanSlotAddress? = nil
    ) -> Bool {
        switch placement {
        case .any:
            return true
        case .topRow:
            return address.rowIndex == 0
        case .bottomRow:
            return address.rowIndex == 5
        case .sunlight:
            return address.zone == .sunlit
        case let .diveSite(diveSite):
            return address.diveSite == diveSite
        case let .diveSiteWithCoralAtLeast(requiredCoral):
            guard let reef = playerState?.ocean.coralReefs.first(where: { $0.diveSite == address.diveSite }) else {
                return false
            }
            return reef.coralCount >= requiredCoral
        case .sameDiveSiteAsSource:
            return sourceAddress?.diveSite == address.diveSite
        }
    }

    private func selectedEffect(for choice: PendingChoice) -> AbilityEffectUnit {
        choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first ?? .unsupported
    }

    private func matchingEggTargetIsLegal(_ slot: OceanSlot, for choice: PendingChoice) -> Bool {
        guard slot.address.playerId == choice.playerId,
              slot.content.hasFish,
              resourceAmount(.egg, in: slot) == 0,
              case let .placeEggOnMatchingFish(filter, _) = selectedEffect(for: choice)
        else {
            return false
        }
        return eggPlacementFilterMatches(slot, filter: filter)
    }

    private func eggPlacementTargets(for choice: PendingChoice, in state: GameState) -> [OceanSlotAddress] {
        guard let playerState = state.playerGameStates[choice.playerId] else {
            return []
        }
        return playerState.ocean.slots
            .filter { matchingEggTargetIsLegal($0, for: choice) }
            .map(\.address)
    }

    private func eggPlacementFilterMatches(_ slot: OceanSlot, filter: EggPlacementFilter) -> Bool {
        switch filter {
        case let .lengthBucket(bucket):
            guard let lengthCm = fishLengthForEggFilter(in: slot.content) else {
                return false
            }
            return lengthBucket(for: lengthCm) == bucket
        case .topRow:
            return slot.address.rowIndex == 0
        case .bottomRow:
            return slot.address.rowIndex == 5
        case let .diveSite(diveSite):
            return slot.address.diveSite == diveSite
        case let .tag(kind):
            guard case let .fishCard(cardId) = slot.content,
                  let card = card(withId: cardId)
            else {
                return false
            }
            return card.tags.contains { $0.kind == kind && $0.count > 0 }
        }
    }

    private func fishLengthForEggFilter(in content: OceanSlotContent) -> Int? {
        switch content {
        case .empty:
            return nil
        case let .forageFish(fish):
            return fish.lengthCm
        case let .fishCard(cardId):
            return card(withId: cardId)?.lengthCm
        }
    }

    private func freePlayFilterMatches(_ card: Card, for choice: PendingChoice) -> Bool {
        guard let filter = freePlayFilter(for: choice) else {
            return false
        }
        return freePlayFilterMatches(card, filter: filter)
    }

    private func freePlayFilter(for choice: PendingChoice) -> FreePlayFishFilter? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishForFree(filter, _, _, _) = effect else {
            return nil
        }
        return filter
    }

    private func freePlayPlacementConstraint(for choice: PendingChoice) -> FishPlacementConstraint? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishForFree(_, placement, _, _) = effect else {
            return nil
        }
        return placement
    }

    private func freePlaySourceCondition(for choice: PendingChoice) -> FreePlaySourceCondition? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishForFree(_, _, sourceCondition, _) = effect else {
            return nil
        }
        return sourceCondition
    }

    private func freePlayFilterMatches(_ card: Card, filter: FreePlayFishFilter) -> Bool {
        switch filter {
        case .any:
            return true
        case let .tag(kind):
            return card.tags.contains { $0.kind == kind && $0.count > 0 }
        case let .lengthBucket(bucket):
            return lengthBucket(for: card.lengthCm) == bucket
        case .unsupported:
            return false
        }
    }

    private func freePlayPlacementConstraintMatches(
        _ address: OceanSlotAddress,
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        let placement = freePlayPlacementConstraint(for: choice) ?? .any
        return placementConstraintMatches(
            address,
            placement: placement,
            playerState: playerState,
            sourceAddress: sourceAddress(for: choice)
        )
    }

    private func freePlaySourceConditionSatisfied(
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        switch freePlaySourceCondition(for: choice) ?? .none {
        case .none:
            return true
        case .sourceDiveSiteHasNoCoral:
            guard let sourceAddress = sourceAddress(for: choice),
                  let sourceSlot = playerState.ocean.slots.first(where: { $0.address == sourceAddress }),
                  case let .fishCard(visibleCardId) = sourceSlot.content,
                  visibleCardId == abilitySourceCardId(for: choice),
                  let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == sourceAddress.diveSite })
            else {
                return false
            }
            return reef.coralCount == 0
        }
    }

    private func hasAnyLegalMoveYoungOrSchool(
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        for sourceSlot in playerState.ocean.slots {
            for kind in [ResourceKind.young, .school] where resourceAmount(kind, in: sourceSlot) > 0 {
                for targetSlot in playerState.ocean.slots where targetSlot.address != sourceSlot.address {
                    if canMoveResource(
                        source: sourceSlot,
                        target: targetSlot,
                        kind: kind,
                        choice: choice
                    ) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func canMoveResource(
        source: OceanSlot,
        target: OceanSlot,
        kind: ResourceKind,
        choice: PendingChoice
    ) -> Bool {
        guard resourceAmount(kind, in: source) > 0,
              moveDistance(from: source.address, to: target.address) == 1
        else {
            return false
        }
        if kind == .school, resourceAmount(.school, in: target) > 0 {
            return false
        }
        return source.address.playerId == choice.playerId && target.address.playerId == choice.playerId
    }

    private func hasAnyLegalCoralGain(
        selector: CoralDiveSiteSelector,
        playerState: PlayerGameState
    ) -> Bool {
        if let fixedDiveSite = selector.fixedDiveSite {
            guard let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == fixedDiveSite }) else {
                return false
            }
            return reef.coralCount < reef.maxCoral
        }
        return playerState.ocean.coralReefs.contains { $0.coralCount < $0.maxCoral }
    }

    private func hasAnyLegalConsumeFishFromHand(playerState: PlayerGameState) -> Bool {
        let handCards = playerState.hand.compactMap { card(withId: $0) }
        guard !handCards.isEmpty else {
            return false
        }

        for slot in playerState.ocean.slots {
            guard case let .fishCard(consumerCardId) = slot.content,
                  let consumerCard = card(withId: consumerCardId)
            else {
                continue
            }
            if handCards.contains(where: { $0.lengthCm < consumerCard.lengthCm }) {
                return true
            }
        }
        return false
    }

    private func hasAnyLegalPlayFishForFree(
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        guard freePlaySourceConditionSatisfied(for: choice, playerState: playerState) else {
            return false
        }

        for cardId in playerState.hand {
            guard let card = card(withId: cardId),
                  freePlayFilterMatches(card, for: choice)
            else {
                continue
            }
            if hasAnyLegalPlacement(for: card, playerState: playerState, additionalConstraint: { address in
                freePlayPlacementConstraintMatches(address, for: choice, playerState: playerState)
            }) {
                return true
            }
        }
        return false
    }

    private func hasAnyLegalPaidPlayFishFromHand(
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        for cardId in playerState.hand {
            guard let card = card(withId: cardId),
                  handFishFilterMatches(card, for: choice)
            else {
                continue
            }
            if hasAnyLegalPlacement(for: card, playerState: playerState, additionalConstraint: { address in
                placementConstraintMatches(address, for: choice, playerState: playerState)
            }) {
                return true
            }
        }
        return false
    }

    private func hasAnyLegalPlacement(
        for card: Card,
        playerState: PlayerGameState,
        additionalConstraint: (OceanSlotAddress) -> Bool
    ) -> Bool {
        for slot in playerState.ocean.slots where additionalConstraint(slot.address) {
            if (try? validateFishPlacement(card, targetSlot: slot, playerState: playerState)) != nil {
                return true
            }
        }
        return false
    }

    private func lengthBucket(for lengthCm: Int) -> FishLengthBucket {
        if lengthCm < 50 {
            return .small
        }
        if lengthCm < 150 {
            return .medium
        }
        return .large
    }

    private func validateCoralPayment(
        _ payment: CoralPayment,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .gainCoral,
              let diveSite = coralDiveSite(for: choice),
              let playerState = state.playerGameStates[choice.playerId],
              let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == diveSite }),
              reef.coralCount < reef.maxCoral
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        switch payment {
        case let .egg(source):
            try validateCoralPaymentKind(.egg, for: diveSite, choice: choice)
            try validateCoralResourcePayment(source: source, kind: .egg, for: choice, playerState: playerState)
        case let .young(source):
            try validateCoralPaymentKind(.young, for: diveSite, choice: choice)
            try validateCoralResourcePayment(source: source, kind: .young, for: choice, playerState: playerState)
        case let .discard(cardId):
            try validateCoralPaymentKind(.handCard, for: diveSite, choice: choice)
            guard playerState.hand.contains(cardId) else {
                throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
            }
        }
    }

    private func validateCoralPaymentKind(
        _ paymentKind: EffectPaymentSourceKind,
        for diveSite: DiveSite,
        choice: PendingChoice
    ) throws {
        guard printedCoralPaymentSource(for: diveSite) == paymentKind else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateAbilityCoralGain(
        diveSite: DiveSite,
        for choice: PendingChoice,
        in state: GameState
    ) throws {
        guard choice.kind == .gainCoral,
              choice.expectedInput == .coralPlacement,
              let playerState = state.playerGameStates[choice.playerId],
              let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == diveSite }),
              reef.coralCount < reef.maxCoral
        else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        guard let selector = gainCoralSelector(for: choice) else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
        if let fixedDiveSite = selector.fixedDiveSite, fixedDiveSite != diveSite {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }
    }

    private func validateCoralResourcePayment(
        source: OceanSlotAddress,
        kind: ResourceKind,
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) throws {
        guard source.playerId == choice.playerId,
              let slot = playerState.ocean.slots.first(where: { $0.address == source }),
              resourceAmount(kind, in: slot) > 0
        else {
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

        guard moveDistance(from: source, to: target) == 1 else {
            throw CommandValidationError.invalidPendingChoiceResolution(choice.choiceId)
        }

        // TODO: Expand this to the full straight-line movement and path rules.
    }

    private func moveDistance(from source: OceanSlotAddress, to target: OceanSlotAddress) -> Int {
        let diveSiteDistance = abs(diveSiteSortIndex(source.diveSite) - diveSiteSortIndex(target.diveSite))
        let rowDistance = abs(source.rowIndex - target.rowIndex)
        return max(diveSiteDistance, rowDistance)
    }

    private func hasBlockingPendingChoices(for playerId: PlayerID, in state: GameState) -> Bool {
        state.pendingChoices.values.contains { choice in
            choice.playerId == playerId || choice.allPlayersProgress?.sourcePlayerId == playerId
        }
    }

    private func shouldAdvanceTurnAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        playerId: PlayerID,
        in state: GameState
    ) -> Bool {
        guard state.activePlayerId == playerId,
              let choice = state.pendingChoices[payload.choiceId]
        else {
            return false
        }
        guard choice.playerId == playerId || choice.allPlayersProgress?.sourcePlayerId == playerId else {
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
            pendingChoice.choiceId != payload.choiceId
                && (pendingChoice.playerId == playerId || pendingChoice.allPlayersProgress?.sourcePlayerId == playerId)
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
        var stepInputs: [(source: DiveResolutionStepSource, pendingChoice: PendingChoice)] = []

        for zone in OceanZone.allCases {
            for (bonusIndex, bonus) in indexedBonuses where bonus.position == .zone(zone) {
                if bonusIsAvailable(bonus, playerState: playerState, includeBottomBonus: includeBottomBonus) {
                    stepInputs.append((
                        source: diveResolutionStepSource(for: bonus.position),
                        pendingChoice: pendingChoice(
                            for: bonus,
                            choiceId: "\(commandId)-dive-bonus-\(bonusIndex)",
                            playerId: playerId,
                            diveQueueId: queueId,
                            diveStepId: ""
                        )
                    ))
                }
            }
            if zone == .twilight,
               let coralReefStep = coralReefStepInput(
                diveSite: diveSite,
                commandId: commandId,
                playerId: playerId,
                queueId: queueId,
                playerState: playerState
               ) {
                stepInputs.append(coralReefStep)
            }
            stepInputs.append(
                contentsOf: ifActivatedAbilityStepInputs(
                    zone: zone,
                    diveSite: diveSite,
                    commandId: commandId,
                    playerId: playerId,
                    queueId: queueId,
                    playerState: playerState,
                    in: state
                )
            )
        }

        for (bonusIndex, bonus) in indexedBonuses where bonus.position == .bottom {
            if bonusIsAvailable(bonus, playerState: playerState, includeBottomBonus: includeBottomBonus) {
                stepInputs.append((
                    source: diveResolutionStepSource(for: bonus.position),
                    pendingChoice: pendingChoice(
                        for: bonus,
                        choiceId: "\(commandId)-dive-bonus-\(bonusIndex)",
                        playerId: playerId,
                        diveQueueId: queueId,
                        diveStepId: ""
                    )
                ))
            }
        }

        let steps = stepInputs.enumerated().map { stepIndex, input in
            let stepId = "\(queueId)-step-\(stepIndex)"
            var choice = input.pendingChoice
            choice.diveStepId = stepId
            return DiveResolutionStep(
                stepId: stepId,
                source: input.source,
                pendingChoice: choice
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

    private func coralReefStepInput(
        diveSite: DiveActionSite,
        commandId: CommandID,
        playerId: PlayerID,
        queueId: DiveResolutionQueueID,
        playerState: PlayerGameState
    ) -> (source: DiveResolutionStepSource, pendingChoice: PendingChoice)? {
        guard let oceanDiveSite = diveBonusLayout.oceanDiveSite(for: diveSite),
              let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == oceanDiveSite }),
              reef.coralCount < reef.maxCoral
        else {
            return nil
        }

        return (
            source: .coralReefOverlay(diveSite: oceanDiveSite),
            pendingChoice: PendingChoice(
                choiceId: "\(commandId)-coral-reef-\(oceanDiveSite.rawValue)",
                playerId: playerId,
                source: .coralReef(oceanDiveSite),
                diveQueueId: queueId,
                diveStepId: "",
                kind: .gainCoral,
                options: [
                    coralPaymentOption(for: oceanDiveSite)
                ],
                expectedInput: .coralPayment,
                isOptional: true,
                createdAtSequence: 0
            )
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

        if let scatterUpdate = scatterSchoolDiveQueueProgressAfterResolving(
            choice: choice,
            resolution: payload.resolution,
            queue: queue,
            in: state
        ) {
            return scatterUpdate
        }
        if let consumeUpdate = consumeFishFromHandDiveQueueProgressAfterResolving(
            choice: choice,
            resolution: payload.resolution,
            queue: queue,
            in: state
        ) {
            return consumeUpdate
        }
        if let freePlayUpdate = playFishForFreeDiveQueueProgressAfterResolving(
            choice: choice,
            resolution: payload.resolution,
            queue: queue,
            in: state
        ) {
            return freePlayUpdate
        }
        if let compoundUpdate = compoundDiveQueueProgressAfterResolving(
            choice: choice,
            resolution: payload.resolution,
            queue: queue,
            in: state
        ) {
            return compoundUpdate
        }

        return advanceDiveQueueOrAllPlayersNext(
            queue,
            afterCompleting: choice,
            didSkip: payload.resolution == .skip,
            in: state
        )
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
            guard let choice = state.pendingChoices[payload.choiceId],
                  choice.kind == .gainCoral,
                  let diveSite = coralDiveSite(for: choice)
            else {
                return [.none]
            }
            return [.skipCoral(playerId: playerId, diveSite: diveSite)]
        case let .draw(count):
            let cardIds = Array(state.deckState.fishDrawPile.prefix(count))
            guard !cardIds.isEmpty else {
                return [.none]
            }
            return [.drawFish(playerId: playerId, cardIds: cardIds)]
        case let .recoverCard(cardId):
            return [.recoverFromDiscard(playerId: playerId, cardId: cardId)]
        case .drawFromDeck:
            guard let cardId = state.deckState.fishDrawPile.first else {
                return [.none]
            }
            return [.drawFish(playerId: playerId, cardIds: [cardId])]
        case let .moveResource(source, target, kind):
            return [.moveResource(source: source, target: target, kind: kind, amount: 1)]
        case let .gainCoralWithEgg(source):
            guard let choice = state.pendingChoices[payload.choiceId],
                  let diveSite = coralDiveSite(for: choice)
            else {
                return [.none]
            }
            return [.gainCoral(playerId: playerId, diveSite: diveSite, payment: .egg(source: source))]
        case let .gainCoralWithYoung(source):
            guard let choice = state.pendingChoices[payload.choiceId],
                  let diveSite = coralDiveSite(for: choice)
            else {
                return [.none]
            }
            return [.gainCoral(playerId: playerId, diveSite: diveSite, payment: .young(source: source))]
        case let .gainCoralByDiscard(cardId):
            guard let choice = state.pendingChoices[payload.choiceId],
                  let diveSite = coralDiveSite(for: choice)
            else {
                return [.none]
            }
            return [.gainCoral(playerId: playerId, diveSite: diveSite, payment: .discard(cardId: cardId))]
        case let .gainCoralFromAbility(diveSite):
            guard let choice = state.pendingChoices[payload.choiceId],
                  let sourceCardId = abilitySourceCardId(for: choice)
            else {
                return [.none]
            }
            return [.gainCoralFromAbility(playerId: playerId, diveSite: diveSite, sourceCardId: sourceCardId)]
        case let .chooseScatterSchoolSource(source):
            return [.scatterSchoolSourceRemoved(playerId: playerId, source: source)]
        case let .placeScatterSchoolYoung(target):
            return [.scatterSchoolYoungPlaced(playerId: playerId, target: target)]
        case let .scatterSchool(source, targets):
            return [.scatterSchoolSourceRemoved(playerId: playerId, source: source)]
                + targets.map { .scatterSchoolYoungPlaced(playerId: playerId, target: $0) }
        case .chooseConsumeFishConsumer:
            return [.none]
        case let .consumeFishFromHand(cardId):
            guard let choice = state.pendingChoices[payload.choiceId],
                  let consumerSlot = choice.consumeFishFromHandProgress?.consumerSlot
            else {
                return [.none]
            }
            return [
                .fishConsumedFromHand(
                    playerId: playerId,
                    consumerSlot: consumerSlot,
                    consumedCardId: cardId
                )
            ]
        case let .consumeFishFromHandWithConsumer(consumerSlot, consumedCardId):
            return [
                .fishConsumedFromHand(
                    playerId: playerId,
                    consumerSlot: consumerSlot,
                    consumedCardId: consumedCardId
                )
            ]
        case .chooseFreePlayFish:
            return [.none]
        case let .playFishForFree(cardId, targetSlot):
            return [.fishPlayedForFree(playerId: playerId, cardId: cardId, targetSlot: targetSlot)]
        case .choosePlayFishFromHand,
             .choosePlayFishFromHandTarget:
            return [.none]
        case let .playFishFromHand(cardId, targetSlot, payment):
            return [
                .fishPlayedFromHand(
                    playerId: playerId,
                    cardId: cardId,
                    targetSlot: targetSlot,
                    payment: payment
                )
            ]
        case let .chooseTarget(target):
            guard let choice = state.pendingChoices[payload.choiceId] else {
                return [.none]
            }
            switch choice.kind {
            case .placeEgg:
                return [.placeEgg(target: target, amount: 1)]
            case .placeEggOnMatchingFish:
                return [.placeEgg(target: target, amount: 1)]
            case .hatchEgg:
                return [.hatchEgg(target: target, amount: 1)]
            case .placeYoung:
                return [.placeYoung(target: target, amount: 1)]
            case .drawFish,
                 .recoverFromDiscardOrDraw,
                 .moveYoungOrSchool,
                 .gainCoral,
                 .scatterSchool,
                 .consumeFishFromHand,
                 .playFishForFree,
                 .playFishFromHand,
                 .compoundAbility,
                 .bottomBonus,
                 .placeholder,
                 .unsupported:
                return [.none]
            }
        case .chooseOption,
             .chooseAbilityEffect:
            return [.none]
        case .finishAbility:
            guard let choice = state.pendingChoices[payload.choiceId],
                  choice.kind == .placeEggOnMatchingFish
            else {
                return [.none]
            }
            let targets = eggPlacementTargets(for: choice, in: state)
            guard !targets.isEmpty else {
                return [.none]
            }
            return targets.map { .placeEgg(target: $0, amount: 1) }
        }
    }

    private func coralDiveSite(for choice: PendingChoice) -> DiveSite? {
        guard case let .coralReef(diveSite) = choice.source else {
            return nil
        }
        return diveSite
    }

    private func coralPaymentOption(for diveSite: DiveSite) -> PendingChoiceOption {
        switch printedCoralPaymentSource(for: diveSite) {
        case .egg:
            return PendingChoiceOption(optionId: "egg", label: "egg")
        case .young:
            return PendingChoiceOption(optionId: "young", label: "young")
        case .handCard:
            return PendingChoiceOption(optionId: "discard", label: "discard")
        case .discardCard,
             .coralReef,
             .waivedCost:
            return PendingChoiceOption(optionId: "unsupported", label: "unsupported")
        }
    }

    private func printedCoralPaymentSource(for diveSite: DiveSite) -> EffectPaymentSourceKind {
        switch diveSite {
        case .blue:
            return .egg
        case .purple:
            return .young
        case .green:
            return .handCard
        }
    }

    private func sourceAddress(for choice: PendingChoice) -> OceanSlotAddress? {
        if let sourceAddress = choice.conditionalBonusProgress?.sourceAddress {
            return sourceAddress
        }
        if let sourceAddress = choice.compoundAbilityProgress?.sourceAddress {
            return sourceAddress
        }
        if case let .endGameAbility(sourceId) = choice.source {
            return gameEndAbilitySource(from: sourceId)?.slotAddress
        }
        return nil
    }

    private func abilitySourceCardId(for choice: PendingChoice) -> CardID? {
        if case let .fishAbility(cardId) = choice.source {
            return cardId
        }
        if case let .endGameAbility(sourceId) = choice.source {
            return gameEndAbilitySource(from: sourceId)?.cardId
        }
        if let sourceCardId = choice.conditionalBonusProgress?.sourceCardId {
            return sourceCardId
        }
        return choice.compoundAbilityProgress?.sourceCardId
    }

    private func gameEndAbilitySource(for choice: PendingChoice?) -> GameEndAbilitySource? {
        guard let choice,
              case let .endGameAbility(sourceId) = choice.source
        else {
            return nil
        }
        return gameEndAbilitySource(from: sourceId)
    }

    private func shouldMarkGameEndSourceBeforeNextChoice(_ payload: ResolvePendingChoiceCommand) -> Bool {
        switch payload.resolution {
        case .playFishForFree,
             .playFishFromHand:
            return true
        case .skip,
             .chooseTarget,
             .draw,
             .recoverCard,
             .drawFromDeck,
             .moveResource,
             .gainCoralWithEgg,
             .gainCoralWithYoung,
             .gainCoralByDiscard,
             .gainCoralFromAbility,
             .chooseScatterSchoolSource,
             .placeScatterSchoolYoung,
             .scatterSchool,
             .chooseConsumeFishConsumer,
             .consumeFishFromHand,
             .consumeFishFromHandWithConsumer,
             .chooseFreePlayFish,
             .choosePlayFishFromHand,
             .choosePlayFishFromHandTarget,
             .chooseOption,
             .chooseAbilityEffect,
             .finishAbility:
            return false
        }
    }

    private func gameEndAbilitySource(from sourceId: String) -> GameEndAbilitySource? {
        let parts = sourceId.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              let diveSite = DiveSite(rawValue: parts[1]),
              let rowIndex = Int(parts[2])
        else {
            return nil
        }
        return GameEndAbilitySource(
            playerId: parts[0],
            slotAddress: OceanSlotAddress(playerId: parts[0], diveSite: diveSite, rowIndex: rowIndex),
            cardId: parts[3],
            abilityId: parts[4]
        )
    }

    private func gainCoralSelector(for choice: PendingChoice) -> CoralDiveSiteSelector? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .gainCoral(selector, _) = effect else {
            return nil
        }
        return selector
    }

    private func drawCount(for choice: PendingChoice) -> Int {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .drawFish(count) = effect else {
            return 1
        }
        return count
    }

    private func ifActivatedAbilityStepInputs(
        zone: OceanZone,
        diveSite: DiveActionSite,
        commandId: CommandID,
        playerId: PlayerID,
        queueId: DiveResolutionQueueID,
        playerState: PlayerGameState,
        in state: GameState
    ) -> [(source: DiveResolutionStepSource, pendingChoice: PendingChoice)] {
        guard let mappedDiveSite = diveBonusLayout.oceanDiveSite(for: diveSite) else {
            return []
        }

        return playerState.ocean.slots
            .filter { slot in
                slot.address.diveSite == mappedDiveSite
                    && slot.address.zone == zone
            }
            .sorted { left, right in
                left.address.rowIndex < right.address.rowIndex
            }
            .flatMap { slot -> [(source: DiveResolutionStepSource, pendingChoice: PendingChoice)] in
                guard case let .fishCard(cardId) = slot.content,
                      let card = card(withId: cardId)
                else {
                    return []
                }
                return abilityResolver.abilityDefinitions(for: card, trigger: .ifActivated)
                    .enumerated()
                    .map { abilityIndex, ability in
                        let choiceId = "\(commandId)-if-activated-\(slot.address.diveSite.rawValue)-\(slot.address.rowIndex)-\(abilityIndex)"
                        return (
                            source: ability.effects.count > 1 || ability.canResolveInAnyOrder
                                ? .compoundFishAbility(cardId: cardId, address: slot.address)
                                : .fishAbility(cardId: cardId, address: slot.address),
                            pendingChoice: abilityPendingChoice(
                                ability,
                                cardId: cardId,
                                sourceAddress: slot.address,
                                choiceId: choiceId,
                                playerId: playerId,
                                diveQueueId: queueId,
                                diveStepId: "",
                                allPlayerIds: allPlayerIds(startingAt: playerId, in: state)
                            )
                        )
                    }
            }
    }

    private func whenPlayedPendingChoice(
        for cardId: CardID,
        sourceAddress: OceanSlotAddress,
        choiceId: PendingChoiceID,
        playerId: PlayerID,
        diveQueueId: DiveResolutionQueueID? = nil,
        diveStepId: DiveResolutionStepID? = nil,
        in state: GameState
    ) -> PendingChoice? {
        guard let card = card(withId: cardId),
              let ability = abilityResolver.abilityDefinitions(for: card, trigger: .whenPlayed).first
        else {
            return nil
        }
        return abilityPendingChoice(
            ability,
            cardId: cardId,
            sourceAddress: sourceAddress,
            choiceId: choiceId,
            playerId: playerId,
            diveQueueId: diveQueueId,
            diveStepId: diveStepId,
            allPlayerIds: allPlayerIds(startingAt: playerId, in: state)
        )
    }

    private struct GameEndAbilityCandidate: Equatable {
        var source: GameEndAbilitySource
        var card: Card
        var ability: AbilityDefinition

        var isSupported: Bool {
            isExecutable
        }

        var isExecutable: Bool {
            !ability.effects.contains(.unsupported) && !isScoringOnly
        }

        var isScoringOnly: Bool {
            ability.effects.allSatisfy { effect in
                if case .gameEndScore = effect {
                    return true
                }
                return false
            }
        }
    }

    private func gameEndAbilitySources(
        for playerId: PlayerID,
        in state: GameState
    ) -> [GameEndAbilityCandidate] {
        guard let playerState = state.playerGameStates[playerId] else {
            return []
        }

        return playerState.ocean.slots.flatMap { slot -> [GameEndAbilityCandidate] in
            guard case let .fishCard(cardId) = slot.content,
                  let card = card(withId: cardId)
            else {
                return []
            }
            return abilityResolver.abilityDefinitions(for: card, trigger: .gameEnd).map { ability in
                GameEndAbilityCandidate(
                    source: GameEndAbilitySource(
                        playerId: playerId,
                        slotAddress: slot.address,
                        cardId: cardId,
                        abilityId: ability.abilityId
                    ),
                    card: card,
                    ability: ability
                )
            }
        }
    }

    private func gameEndAbilityPendingChoice(
        source: GameEndAbilitySource,
        commandId: CommandID,
        in state: GameState
    ) -> PendingChoice? {
        guard let candidate = gameEndAbilitySources(for: source.playerId, in: state)
            .first(where: { $0.source == source }),
              candidate.isSupported
        else {
            return nil
        }
        var choice = abilityPendingChoice(
            candidate.ability,
            cardId: source.cardId,
            sourceAddress: source.slotAddress,
            choiceId: "\(commandId)-game-end-ability",
            playerId: source.playerId,
            diveQueueId: nil,
            diveStepId: nil,
            allPlayerIds: allPlayerIds(startingAt: source.playerId, in: state)
        )
        choice.source = .endGameAbility(source.id)
        return choice
    }

    private func abilityPendingChoice(
        _ ability: AbilityDefinition,
        cardId: CardID,
        sourceAddress: OceanSlotAddress,
        choiceId: PendingChoiceID,
        playerId: PlayerID,
        diveQueueId: DiveResolutionQueueID?,
        diveStepId: DiveResolutionStepID?,
        allPlayerIds: [PlayerID] = []
    ) -> PendingChoice {
        if let conditionalBonus = ability.conditionalBonus {
            let progress = ConditionalBonusAbilityProgress(
                abilityId: ability.abilityId,
                playerId: playerId,
                sourceCardId: cardId,
                sourceAddress: sourceAddress,
                baseChoiceId: choiceId,
                phase: .base,
                requirement: conditionalBonus.requirement
            )
            return conditionalBonusPendingChoice(
                ability,
                progress: progress,
                effects: conditionalBonus.baseEffects,
                canResolveInAnyOrder: conditionalBonus.baseCanResolveInAnyOrder,
                source: .fishAbility(cardId),
                diveQueueId: diveQueueId,
                diveStepId: diveStepId,
                createdAtSequence: 0
            )
        }

        if ability.appliesToAllPlayers == true,
           let firstTargetPlayerId = allPlayerIds.first {
            let progress = AllPlayersAbilityProgress(
                abilityId: ability.abilityId,
                sourcePlayerId: playerId,
                sourceCardId: cardId,
                sourceAddress: sourceAddress,
                baseChoiceId: choiceId,
                currentTargetPlayerId: firstTargetPlayerId,
                remainingPlayerIds: Array(allPlayerIds.dropFirst())
            )
            return allPlayersPendingChoice(
                ability,
                progress: progress,
                source: .fishAbility(cardId),
                diveQueueId: diveQueueId,
                diveStepId: diveStepId,
                createdAtSequence: 0
            )
        }

        let isCompound = ability.effects.count > 1 || ability.canResolveInAnyOrder
        let progress = isCompound
            ? CompoundAbilityProgress(
                abilityId: ability.abilityId,
                playerId: playerId,
                sourceCardId: cardId,
                sourceAddress: sourceAddress,
                remainingEffects: ability.effects,
                completedEffects: [],
                canResolveInAnyOrder: ability.canResolveInAnyOrder,
                isOptional: ability.isOptional
            )
            : nil
        let firstEffect = ability.effects.first ?? .unsupported

        return PendingChoice(
            choiceId: choiceId,
            playerId: playerId,
            source: .fishAbility(cardId),
            diveQueueId: diveQueueId,
            diveStepId: diveStepId,
            kind: isCompound ? .compoundAbility : pendingChoiceKind(for: firstEffect),
            options: [],
            expectedInput: isCompound ? .abilityEffectSelection : expectedInput(for: firstEffect),
            isOptional: ability.isOptional,
            abilityDefinition: ability,
            compoundAbilityProgress: progress,
            createdAtSequence: 0
        )
    }

    private func allPlayersPendingChoice(
        _ ability: AbilityDefinition,
        progress: AllPlayersAbilityProgress,
        source: PendingChoiceSource,
        diveQueueId: DiveResolutionQueueID?,
        diveStepId: DiveResolutionStepID?,
        createdAtSequence: EventID
    ) -> PendingChoice {
        let isCompound = ability.effects.count > 1 || ability.canResolveInAnyOrder
        let compoundProgress = isCompound
            ? CompoundAbilityProgress(
                abilityId: ability.abilityId,
                playerId: progress.currentTargetPlayerId,
                sourceCardId: progress.sourceCardId,
                sourceAddress: progress.sourceAddress,
                remainingEffects: ability.effects,
                completedEffects: [],
                canResolveInAnyOrder: ability.canResolveInAnyOrder,
                isOptional: ability.isOptional
            )
            : nil
        let firstEffect = ability.effects.first ?? .unsupported
        return PendingChoice(
            choiceId: allPlayersChoiceId(progress),
            playerId: progress.currentTargetPlayerId,
            source: source,
            diveQueueId: diveQueueId,
            diveStepId: diveStepId,
            kind: isCompound ? .compoundAbility : pendingChoiceKind(for: firstEffect),
            options: [],
            expectedInput: isCompound ? .abilityEffectSelection : expectedInput(for: firstEffect),
            isOptional: true,
            abilityDefinition: ability,
            compoundAbilityProgress: compoundProgress,
            allPlayersProgress: progress,
            conditionalBonusProgress: nil,
            createdAtSequence: createdAtSequence
        )
    }

    private func conditionalBonusPendingChoice(
        _ ability: AbilityDefinition,
        progress: ConditionalBonusAbilityProgress,
        effects: [AbilityEffectUnit],
        canResolveInAnyOrder: Bool,
        source: PendingChoiceSource,
        diveQueueId: DiveResolutionQueueID?,
        diveStepId: DiveResolutionStepID?,
        createdAtSequence: EventID
    ) -> PendingChoice {
        let isCompound = effects.count > 1 || canResolveInAnyOrder
        let compoundProgress = isCompound
            ? CompoundAbilityProgress(
                abilityId: ability.abilityId,
                playerId: progress.playerId,
                sourceCardId: progress.sourceCardId,
                sourceAddress: progress.sourceAddress,
                remainingEffects: effects,
                completedEffects: [],
                canResolveInAnyOrder: canResolveInAnyOrder,
                isOptional: true
            )
            : nil
        let firstEffect = effects.first ?? .unsupported
        return PendingChoice(
            choiceId: conditionalBonusChoiceId(progress),
            playerId: progress.playerId,
            source: source,
            diveQueueId: diveQueueId,
            diveStepId: diveStepId,
            kind: isCompound ? .compoundAbility : pendingChoiceKind(for: firstEffect),
            options: [],
            expectedInput: isCompound ? .abilityEffectSelection : expectedInput(for: firstEffect),
            isOptional: true,
            abilityDefinition: ability,
            compoundAbilityProgress: compoundProgress,
            selectedAbilityEffect: isCompound ? nil : firstEffect,
            allPlayersProgress: nil,
            conditionalBonusProgress: progress,
            createdAtSequence: createdAtSequence
        )
    }

    private func conditionalBonusChoiceId(_ progress: ConditionalBonusAbilityProgress) -> PendingChoiceID {
        "\(progress.baseChoiceId)-conditional-\(progress.phase.rawValue)"
    }

    private func allPlayersChoiceId(_ progress: AllPlayersAbilityProgress) -> PendingChoiceID {
        "\(progress.baseChoiceId)-all-\(progress.currentTargetPlayerId)"
    }

    private func allPlayerIds(startingAt playerId: PlayerID, in state: GameState) -> [PlayerID] {
        let ids = state.players.map(\.id).filter { state.playerGameStates[$0] != nil }
        guard let startIndex = ids.firstIndex(of: playerId) else {
            return ids
        }
        return Array(ids[startIndex...]) + Array(ids[..<startIndex])
    }

    private func nextAllPlayersChoiceAfterCompletingCurrentPlayer(
        _ choice: PendingChoice,
        didSkip: Bool
    ) -> PendingChoice? {
        guard var progress = choice.allPlayersProgress,
              let ability = choice.abilityDefinition,
              ability.appliesToAllPlayers == true
        else {
            return nil
        }

        if didSkip {
            progress.skippedPlayerIds.append(choice.playerId)
        } else {
            progress.resolvedPlayerIds.append(choice.playerId)
        }

        guard let nextTargetPlayerId = progress.remainingPlayerIds.first else {
            return nil
        }

        progress.currentTargetPlayerId = nextTargetPlayerId
        progress.remainingPlayerIds = Array(progress.remainingPlayerIds.dropFirst())
        return allPlayersPendingChoice(
            ability,
            progress: progress,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func compoundDiveQueueProgressAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution,
        queue: DiveResolutionQueue,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?)? {
        if choice.kind == .compoundAbility {
            switch resolution {
            case let .chooseAbilityEffect(effect):
                guard let progress = choice.compoundAbilityProgress else {
                    return nil
                }
                var updatedQueue = queue
                var targetChoice = compoundTargetChoice(
                    from: choice,
                    progress: progress,
                    effect: normalizedSingleEffect(effect)
                )
                targetChoice.diveStepId = choice.diveStepId
                setCurrentStepPendingChoice(targetChoice, in: &updatedQueue)
                return (.updated(updatedQueue), targetChoice)
            case .finishAbility,
                 .skip:
                return advanceDiveQueueOrAllPlayersNext(
                    queue,
                    afterCompleting: choice,
                    didSkip: resolution == .skip,
                    in: state
                )
            default:
                return nil
            }
        }

        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return nil
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        if abilityProgressIsComplete(updatedProgress) {
            return advanceDiveQueueOrAllPlayersNext(
                queue,
                afterCompleting: choice,
                didSkip: false,
                in: state
            )
        }

        var updatedQueue = queue
        var selectorChoice = compoundSelectorChoice(
            from: choice,
            progress: updatedProgress
        )
        selectorChoice.diveStepId = choice.diveStepId
        setCurrentStepPendingChoice(selectorChoice, in: &updatedQueue)
        return (.updated(updatedQueue), selectorChoice)
    }

    private func scatterSchoolDiveQueueProgressAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution,
        queue: DiveResolutionQueue,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?)? {
        guard choice.kind == .scatterSchool else {
            return nil
        }
        if case .skip = resolution {
            if choice.allPlayersProgress != nil {
                return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: true, in: state)
            }
            if choice.conditionalBonusProgress != nil {
                return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: true, in: state)
            }
            return advanceDiveQueue(queue)
        }
        guard let nextChoice = scatterSchoolChoiceAfterResolving(
            choice: choice,
            resolution: resolution,
            in: state
        ) else {
            if choice.compoundAbilityProgress != nil {
                return compoundDiveQueueProgressAfterScatterSchoolCompletion(choice: choice, queue: queue, in: state)
            }
            return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: false, in: state)
        }

        var updatedQueue = queue
        var updatedChoice = nextChoice
        updatedChoice.diveStepId = choice.diveStepId
        setCurrentStepPendingChoice(updatedChoice, in: &updatedQueue)
        return (.updated(updatedQueue), updatedChoice)
    }

    private func compoundDiveQueueProgressAfterScatterSchoolCompletion(
        choice: PendingChoice,
        queue: DiveResolutionQueue,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?) {
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return advanceDiveQueue(queue)
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        if abilityProgressIsComplete(updatedProgress) {
            return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: false, in: state)
        }

        var updatedQueue = queue
        var selectorChoice = compoundSelectorChoice(from: choice, progress: updatedProgress)
        selectorChoice.diveStepId = choice.diveStepId
        setCurrentStepPendingChoice(selectorChoice, in: &updatedQueue)
        return (.updated(updatedQueue), selectorChoice)
    }

    private func consumeFishFromHandDiveQueueProgressAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution,
        queue: DiveResolutionQueue,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?)? {
        guard choice.kind == .consumeFishFromHand else {
            return nil
        }
        if case .skip = resolution {
            if choice.compoundAbilityProgress != nil {
                return compoundDiveQueueProgressAfterConsumeFishCompletion(choice: choice, queue: queue, in: state)
            }
            return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: true, in: state)
        }
        guard let nextChoice = consumeFishFromHandChoiceAfterResolving(
            choice: choice,
            resolution: resolution
        ) else {
            if choice.compoundAbilityProgress != nil {
                return compoundDiveQueueProgressAfterConsumeFishCompletion(choice: choice, queue: queue, in: state)
            }
            return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: false, in: state)
        }

        var updatedQueue = queue
        var updatedChoice = nextChoice
        updatedChoice.diveStepId = choice.diveStepId
        setCurrentStepPendingChoice(updatedChoice, in: &updatedQueue)
        return (.updated(updatedQueue), updatedChoice)
    }

    private func compoundDiveQueueProgressAfterConsumeFishCompletion(
        choice: PendingChoice,
        queue: DiveResolutionQueue,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?) {
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return advanceDiveQueue(queue)
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        if abilityProgressIsComplete(updatedProgress) {
            return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: false, in: state)
        }

        var updatedQueue = queue
        var selectorChoice = compoundSelectorChoice(from: choice, progress: updatedProgress)
        selectorChoice.diveStepId = choice.diveStepId
        setCurrentStepPendingChoice(selectorChoice, in: &updatedQueue)
        return (.updated(updatedQueue), selectorChoice)
    }

    private func playFishForFreeDiveQueueProgressAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution,
        queue: DiveResolutionQueue,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?)? {
        guard choice.kind == .playFishForFree else {
            return nil
        }
        if case .skip = resolution {
            return advanceDiveQueueOrAllPlayersNext(
                queue,
                afterCompleting: choice,
                didSkip: true,
                in: state
            )
        }
        if let nextChoice = playFishForFreeChoiceAfterResolving(choice: choice, resolution: resolution) {
            var updatedQueue = queue
            var updatedChoice = nextChoice
            updatedChoice.diveStepId = choice.diveStepId
            setCurrentStepPendingChoice(updatedChoice, in: &updatedQueue)
            return (.updated(updatedQueue), updatedChoice)
        }
        if case let .playFishForFree(cardId, targetSlot) = resolution,
           var whenPlayedChoice = whenPlayedPendingChoice(
               for: cardId,
               sourceAddress: targetSlot,
               choiceId: "\(choice.choiceId)-free-when-played",
               playerId: choice.playerId,
               diveQueueId: choice.diveQueueId,
               diveStepId: choice.diveStepId,
               in: state
           ) {
            var updatedQueue = queue
            whenPlayedChoice.diveStepId = choice.diveStepId
            setCurrentStepPendingChoice(whenPlayedChoice, in: &updatedQueue)
            return (.updated(updatedQueue), whenPlayedChoice)
        }
        if choice.compoundAbilityProgress != nil {
            return compoundDiveQueueProgressAfterPlayFishForFreeCompletion(choice: choice, queue: queue, in: state)
        }
        return advanceDiveQueueOrAllPlayersNext(
            queue,
            afterCompleting: choice,
            didSkip: false,
            in: state
        )
    }

    private func compoundDiveQueueProgressAfterPlayFishForFreeCompletion(
        choice: PendingChoice,
        queue: DiveResolutionQueue,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?) {
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return advanceDiveQueue(queue)
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        if abilityProgressIsComplete(updatedProgress) {
            return advanceDiveQueueOrAllPlayersNext(queue, afterCompleting: choice, didSkip: false, in: state)
        }

        var updatedQueue = queue
        var selectorChoice = compoundSelectorChoice(from: choice, progress: updatedProgress)
        selectorChoice.diveStepId = choice.diveStepId
        setCurrentStepPendingChoice(selectorChoice, in: &updatedQueue)
        return (.updated(updatedQueue), selectorChoice)
    }

    private func advanceDiveQueue(
        _ queue: DiveResolutionQueue
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?) {
        var advancedQueue = queue
        advancedQueue.currentStepIndex += 1
        guard let nextChoice = advancedQueue.currentStep?.pendingChoice else {
            return (.completed(queueId: advancedQueue.queueId), nil)
        }
        return (.advanced(advancedQueue), nextChoice)
    }

    private func advanceDiveQueueOrAllPlayersNext(
        _ queue: DiveResolutionQueue,
        afterCompleting choice: PendingChoice,
        didSkip: Bool,
        in state: GameState
    ) -> (update: DiveResolutionQueueUpdate?, nextChoice: PendingChoice?) {
        guard var nextChoice = nextFollowUpChoiceAfterCompletingCurrentSegment(
            choice,
            didSkip: didSkip,
            in: state
        ) else {
            return advanceDiveQueue(queue)
        }
        var updatedQueue = queue
        nextChoice.diveStepId = choice.diveStepId
        setCurrentStepPendingChoice(nextChoice, in: &updatedQueue)
        return (.updated(updatedQueue), nextChoice)
    }

    private func nextFollowUpChoiceAfterCompletingCurrentSegment(
        _ choice: PendingChoice,
        didSkip: Bool,
        in state: GameState
    ) -> PendingChoice? {
        nextConditionalBonusChoiceAfterCompletingCurrentPhase(
            choice,
            didSkip: didSkip,
            in: state
        )
            ?? nextAllPlayersChoiceAfterCompletingCurrentPlayer(
                choice,
                didSkip: didSkip
            )
    }

    private func nextConditionalBonusChoiceAfterCompletingCurrentPhase(
        _ choice: PendingChoice,
        didSkip: Bool,
        in state: GameState
    ) -> PendingChoice? {
        guard var progress = choice.conditionalBonusProgress,
              progress.phase == .base,
              let ability = choice.abilityDefinition,
              let conditionalBonus = ability.conditionalBonus
        else {
            return nil
        }

        progress.baseWasSkipped = didSkip
        guard sourceDiveSiteColoredCoralRequirementIsSatisfied(progress.requirement, for: progress, in: state) else {
            progress.bonusRequirementMet = false
            return nil
        }

        progress.phase = .bonus
        progress.bonusRequirementMet = true
        return conditionalBonusPendingChoice(
            ability,
            progress: progress,
            effects: conditionalBonus.bonusEffects,
            canResolveInAnyOrder: conditionalBonus.bonusCanResolveInAnyOrder,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func sourceDiveSiteColoredCoralRequirementIsSatisfied(
        _ requirement: SourceDiveSiteColoredCoralRequirement,
        for progress: ConditionalBonusAbilityProgress,
        in state: GameState
    ) -> Bool {
        guard progress.sourceAddress.diveSite == requirement.coralColor,
              let playerState = state.playerGameStates[progress.playerId],
              let sourceSlot = playerState.ocean.slots.first(where: { $0.address == progress.sourceAddress }),
              case let .fishCard(visibleCardId) = sourceSlot.content,
              visibleCardId == progress.sourceCardId,
              let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == progress.sourceAddress.diveSite })
        else {
            return false
        }
        return reef.coralCount >= requirement.count
    }

    private func nonQueueCompoundChoiceAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        in state: GameState
    ) -> PendingChoice? {
        guard let choice = state.pendingChoices[payload.choiceId],
              choice.diveQueueId == nil
        else {
            return nil
        }

        if choice.kind == .compoundAbility {
            guard case let .chooseAbilityEffect(effect) = payload.resolution,
                  let progress = choice.compoundAbilityProgress
            else {
                if case .skip = payload.resolution {
                    return nextFollowUpChoiceAfterCompletingCurrentSegment(
                        choice,
                        didSkip: true,
                        in: state
                    )
                }
                return nil
            }
            return compoundTargetChoice(
                from: choice,
                progress: progress,
                effect: normalizedSingleEffect(effect)
            )
        }

        if let scatterChoice = nonQueueScatterSchoolChoiceAfterResolving(payload, choice: choice, in: state) {
            return scatterChoice
        }
        if let consumeChoice = nonQueueConsumeFishFromHandChoiceAfterResolving(payload, choice: choice, in: state) {
            return consumeChoice
        }
        if let freePlayChoice = nonQueuePlayFishForFreeChoiceAfterResolving(payload, choice: choice, in: state) {
            return freePlayChoice
        }
        if let playFishChoice = nonQueuePlayFishFromHandChoiceAfterResolving(payload, choice: choice, in: state) {
            return playFishChoice
        }

        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: payload.resolution == .skip,
                in: state
            )
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        guard !abilityProgressIsComplete(updatedProgress) else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }

        return compoundSelectorChoice(
            from: choice,
            progress: updatedProgress
        )
    }

    private func nonQueueScatterSchoolChoiceAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        choice: PendingChoice,
        in state: GameState
    ) -> PendingChoice? {
        guard choice.kind == .scatterSchool else {
            return nil
        }
        if case .skip = payload.resolution {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: true,
                in: state
            )
        }
        if let nextChoice = scatterSchoolChoiceAfterResolving(
            choice: choice,
            resolution: payload.resolution,
            in: state
        ) {
            return nextChoice
        }
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        guard !abilityProgressIsComplete(updatedProgress) else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }
        return compoundSelectorChoice(from: choice, progress: updatedProgress)
    }

    private func nextCompoundChoiceAfterCompletingCurrentEffect(
        _ choice: PendingChoice,
        in state: GameState
    ) -> PendingChoice? {
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return nil
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        guard !abilityProgressIsComplete(updatedProgress) else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }
        return compoundSelectorChoice(from: choice, progress: updatedProgress)
    }

    private func nonQueueConsumeFishFromHandChoiceAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        choice: PendingChoice,
        in state: GameState
    ) -> PendingChoice? {
        guard choice.kind == .consumeFishFromHand else {
            return nil
        }
        if case .skip = payload.resolution {
            return nextCompoundChoiceAfterCompletingCurrentEffect(choice, in: state)
                ?? nextFollowUpChoiceAfterCompletingCurrentSegment(
                    choice,
                    didSkip: true,
                    in: state
                )
        }
        if let nextChoice = consumeFishFromHandChoiceAfterResolving(
            choice: choice,
            resolution: payload.resolution
        ) {
            return nextChoice
        }
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        guard !abilityProgressIsComplete(updatedProgress) else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }
        return compoundSelectorChoice(from: choice, progress: updatedProgress)
    }

    private func nonQueuePlayFishForFreeChoiceAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        choice: PendingChoice,
        in state: GameState
    ) -> PendingChoice? {
        guard choice.kind == .playFishForFree else {
            return nil
        }
        if case .skip = payload.resolution {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: true,
                in: state
            )
        }
        if let nextChoice = playFishForFreeChoiceAfterResolving(
            choice: choice,
            resolution: payload.resolution
        ) {
            return nextChoice
        }
        if case let .playFishForFree(cardId, targetSlot) = payload.resolution,
           let whenPlayedChoice = whenPlayedPendingChoice(
               for: cardId,
               sourceAddress: targetSlot,
               choiceId: "\(choice.choiceId)-free-when-played",
               playerId: choice.playerId,
               in: state
           ) {
            return whenPlayedChoice
        }
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        guard !abilityProgressIsComplete(updatedProgress) else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }
        return compoundSelectorChoice(from: choice, progress: updatedProgress)
    }

    private func nonQueuePlayFishFromHandChoiceAfterResolving(
        _ payload: ResolvePendingChoiceCommand,
        choice: PendingChoice,
        in state: GameState
    ) -> PendingChoice? {
        guard choice.kind == .playFishFromHand else {
            return nil
        }
        if case .skip = payload.resolution {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: true,
                in: state
            )
        }
        if let nextChoice = playFishFromHandChoiceAfterResolving(
            choice: choice,
            resolution: payload.resolution
        ) {
            return nextChoice
        }
        if case let .playFishFromHand(cardId, targetSlot, _) = payload.resolution,
           let whenPlayedChoice = whenPlayedPendingChoice(
               for: cardId,
               sourceAddress: targetSlot,
               choiceId: "\(choice.choiceId)-paid-when-played",
               playerId: choice.playerId,
               in: state
           ) {
            return whenPlayedChoice
        }
        guard let progress = choice.compoundAbilityProgress,
              let completedEffect = compoundEffectUnit(for: choice)
        else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }

        var updatedProgress = progress
        updatedProgress.remainingEffects = decrement(completedEffect, from: progress.remainingEffects)
        updatedProgress.completedEffects.append(completedEffect)

        guard !abilityProgressIsComplete(updatedProgress) else {
            return nextFollowUpChoiceAfterCompletingCurrentSegment(
                choice,
                didSkip: false,
                in: state
            )
        }
        return compoundSelectorChoice(from: choice, progress: updatedProgress)
    }

    private func scatterSchoolChoiceAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution,
        in state: GameState
    ) -> PendingChoice? {
        guard choice.kind == .scatterSchool,
              let playerState = state.playerGameStates[choice.playerId]
        else {
            return nil
        }

        var progress = scatterSchoolProgress(for: choice, playerState: playerState)
        switch resolution {
        case let .chooseScatterSchoolSource(source):
            progress.sourceSlot = source
            progress.targetSlots = []
            progress.requiredTargetCount = 4
            progress.requiresSchoolSource = true
            return scatterSchoolTargetChoice(from: choice, progress: progress)
        case let .placeScatterSchoolYoung(target):
            progress.targetSlots.append(target)
            guard !progress.isComplete else {
                return nil
            }
            return scatterSchoolTargetChoice(from: choice, progress: progress)
        case .scatterSchool:
            return nil
        default:
            return nil
        }
    }

    private func scatterSchoolTargetChoice(
        from choice: PendingChoice,
        progress: ScatterSchoolProgress
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "\(choice.choiceId)-scatter-young-\(progress.completedTargetCount)",
            playerId: choice.playerId,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            kind: .scatterSchool,
            options: [],
            expectedInput: .scatterSchoolYoungTarget,
            isOptional: false,
            abilityDefinition: choice.abilityDefinition,
            compoundAbilityProgress: choice.compoundAbilityProgress,
            scatterSchoolProgress: progress,
            selectedAbilityEffect: choice.selectedAbilityEffect,
            allPlayersProgress: choice.allPlayersProgress,
            conditionalBonusProgress: choice.conditionalBonusProgress,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func consumeFishFromHandChoiceAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution
    ) -> PendingChoice? {
        guard choice.kind == .consumeFishFromHand else {
            return nil
        }

        switch resolution {
        case let .chooseConsumeFishConsumer(consumerSlot):
            return consumeFishFromHandCardChoice(from: choice, consumerSlot: consumerSlot)
        case .consumeFishFromHand,
             .consumeFishFromHandWithConsumer:
            return nil
        default:
            return nil
        }
    }

    private func consumeFishFromHandCardChoice(
        from choice: PendingChoice,
        consumerSlot: OceanSlotAddress
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "\(choice.choiceId)-consume-hand",
            playerId: choice.playerId,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            kind: .consumeFishFromHand,
            options: [],
            expectedInput: .consumeFishHandCard,
            isOptional: false,
            abilityDefinition: choice.abilityDefinition,
            compoundAbilityProgress: choice.compoundAbilityProgress,
            consumeFishFromHandProgress: ConsumeFishFromHandProgress(consumerSlot: consumerSlot),
            selectedAbilityEffect: choice.selectedAbilityEffect,
            allPlayersProgress: choice.allPlayersProgress,
            conditionalBonusProgress: choice.conditionalBonusProgress,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func playFishForFreeChoiceAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution
    ) -> PendingChoice? {
        guard choice.kind == .playFishForFree else {
            return nil
        }

        switch resolution {
        case let .chooseFreePlayFish(cardId):
            return playFishForFreeTargetChoice(from: choice, cardId: cardId)
        case .playFishForFree:
            return nil
        default:
            return nil
        }
    }

    private func playFishForFreeTargetChoice(
        from choice: PendingChoice,
        cardId: CardID
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "\(choice.choiceId)-free-target",
            playerId: choice.playerId,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            kind: .playFishForFree,
            options: [],
            expectedInput: .freePlayTargetSlot,
            isOptional: false,
            abilityDefinition: choice.abilityDefinition,
            compoundAbilityProgress: choice.compoundAbilityProgress,
            playFishForFreeProgress: PlayFishForFreeProgress(selectedCardId: cardId),
            selectedAbilityEffect: choice.selectedAbilityEffect,
            allPlayersProgress: choice.allPlayersProgress,
            conditionalBonusProgress: choice.conditionalBonusProgress,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func playFishFromHandChoiceAfterResolving(
        choice: PendingChoice,
        resolution: PendingChoiceResolution
    ) -> PendingChoice? {
        guard choice.kind == .playFishFromHand else {
            return nil
        }

        switch resolution {
        case let .choosePlayFishFromHand(cardId):
            return playFishFromHandTargetChoice(from: choice, cardId: cardId)
        case let .choosePlayFishFromHandTarget(targetSlot):
            guard let selectedCardId = choice.playFishFromHandProgress?.selectedCardId else {
                return nil
            }
            return playFishFromHandPaymentChoice(from: choice, cardId: selectedCardId, targetSlot: targetSlot)
        case .playFishFromHand:
            return nil
        default:
            return nil
        }
    }

    private func playFishFromHandTargetChoice(
        from choice: PendingChoice,
        cardId: CardID
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "\(choice.choiceId)-paid-target",
            playerId: choice.playerId,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            kind: .playFishFromHand,
            options: [],
            expectedInput: .playFishFromHandTargetSlot,
            isOptional: false,
            abilityDefinition: choice.abilityDefinition,
            compoundAbilityProgress: choice.compoundAbilityProgress,
            playFishFromHandProgress: PlayFishFromHandProgress(selectedCardId: cardId),
            selectedAbilityEffect: choice.selectedAbilityEffect,
            allPlayersProgress: choice.allPlayersProgress,
            conditionalBonusProgress: choice.conditionalBonusProgress,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func playFishFromHandPaymentChoice(
        from choice: PendingChoice,
        cardId: CardID,
        targetSlot: OceanSlotAddress
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "\(choice.choiceId)-paid-payment",
            playerId: choice.playerId,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            kind: .playFishFromHand,
            options: [],
            expectedInput: .playFishFromHandPayment,
            isOptional: false,
            abilityDefinition: choice.abilityDefinition,
            compoundAbilityProgress: choice.compoundAbilityProgress,
            playFishFromHandProgress: PlayFishFromHandProgress(selectedCardId: cardId, targetSlot: targetSlot),
            selectedAbilityEffect: choice.selectedAbilityEffect,
            allPlayersProgress: choice.allPlayersProgress,
            conditionalBonusProgress: choice.conditionalBonusProgress,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func setCurrentStepPendingChoice(_ choice: PendingChoice, in queue: inout DiveResolutionQueue) {
        guard queue.steps.indices.contains(queue.currentStepIndex) else {
            return
        }
        queue.steps[queue.currentStepIndex].pendingChoice = choice
    }

    private func compoundTargetChoice(
        from choice: PendingChoice,
        progress: CompoundAbilityProgress,
        effect: AbilityEffectUnit
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "\(choice.choiceId)-target-\(abilityEffectKey(effect))-\(progress.completedEffects.count)",
            playerId: choice.playerId,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            kind: pendingChoiceKind(for: effect),
            options: [],
            expectedInput: expectedInput(for: effect),
            isOptional: false,
            abilityDefinition: choice.abilityDefinition,
            compoundAbilityProgress: progress,
            selectedAbilityEffect: effect,
            allPlayersProgress: choice.allPlayersProgress,
            conditionalBonusProgress: choice.conditionalBonusProgress,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func compoundSelectorChoice(
        from choice: PendingChoice,
        progress: CompoundAbilityProgress
    ) -> PendingChoice {
        PendingChoice(
            choiceId: "\(choice.choiceId)-select-\(progress.completedEffects.count)",
            playerId: choice.playerId,
            source: choice.source,
            diveQueueId: choice.diveQueueId,
            diveStepId: choice.diveStepId,
            kind: .compoundAbility,
            options: [],
            expectedInput: .abilityEffectSelection,
            isOptional: progress.isOptional,
            abilityDefinition: choice.abilityDefinition,
            compoundAbilityProgress: progress,
            allPlayersProgress: choice.allPlayersProgress,
            conditionalBonusProgress: choice.conditionalBonusProgress,
            createdAtSequence: choice.createdAtSequence
        )
    }

    private func abilityProgressCanChoose(
        _ effect: AbilityEffectUnit,
        in choice: PendingChoice,
        state: GameState
    ) -> Bool {
        guard let progress = choice.compoundAbilityProgress else {
            return false
        }
        let normalizedEffect = normalizedSingleEffect(effect)
        if !progress.canResolveInAnyOrder {
            guard let nextEffect = nextOrderedEffect(in: progress),
                  abilityEffectKey(nextEffect) == abilityEffectKey(normalizedEffect)
            else {
                return false
            }
            return compoundEffectIsCurrentlySelectable(normalizedEffect, for: choice, state: state)
        }
        guard effectCount(for: normalizedEffect, in: progress.remainingEffects) > 0 else {
            return false
        }
        return compoundEffectIsCurrentlySelectable(normalizedEffect, for: choice, state: state)
    }

    private func nextOrderedEffect(in progress: CompoundAbilityProgress) -> AbilityEffectUnit? {
        progress.remainingEffects.first { effectCount($0) > 0 }
            .map(normalizedSingleEffect)
    }

    private func abilityProgressIsComplete(_ progress: CompoundAbilityProgress) -> Bool {
        progress.remainingEffects.allSatisfy { effectCount($0) <= 0 }
    }

    private func compoundEffectIsCurrentlySelectable(
        _ effect: AbilityEffectUnit,
        for choice: PendingChoice,
        state: GameState
    ) -> Bool {
        guard let playerState = state.playerGameStates[choice.playerId] else {
            return false
        }

        switch effect {
        case .drawFish:
            return !state.deckState.fishDrawPile.isEmpty
        case .recoverFromDiscardOrDraw:
            return !playerState.discardPile.isEmpty || !state.deckState.fishDrawPile.isEmpty
        case .placeEgg:
            return playerState.ocean.slots.contains { $0.content.hasFish && resourceAmount(.egg, in: $0) == 0 }
        case .placeYoung:
            return !playerState.ocean.slots.isEmpty
        case .hatchEgg:
            return playerState.ocean.slots.contains { resourceAmount(.egg, in: $0) > 0 }
        case .moveYoungOrSchool:
            return hasAnyLegalMoveYoungOrSchool(for: choice, playerState: playerState)
        case let .gainCoral(selector, _):
            return hasAnyLegalCoralGain(selector: selector, playerState: playerState)
        case .scatterSchool:
            return !playerState.ocean.slots.isEmpty
        case .consumeFishFromHand:
            return hasAnyLegalConsumeFishFromHand(playerState: playerState)
        case .playFishFromHand:
            return hasAnyLegalPaidPlayFishFromHand(for: choice, playerState: playerState)
        case .placeEggOnMatchingFish:
            return !eggPlacementTargets(for: choice, in: state).isEmpty
        case .gameEndScore:
            return false
        case let .playFishForFree(_, _, _, _):
            return hasAnyLegalPlayFishForFree(for: choice, playerState: playerState)
        case .unsupported:
            return false
        }
    }

    private func decrement(
        _ effect: AbilityEffectUnit,
        from effects: [AbilityEffectUnit]
    ) -> [AbilityEffectUnit] {
        var didDecrement = false
        return effects.compactMap { current in
            guard !didDecrement, abilityEffectKey(current) == abilityEffectKey(effect) else {
                return current
            }
            didDecrement = true
            let remainingCount = max(effectCount(current) - 1, 0)
            return remainingCount > 0 ? effectWithCount(current, count: remainingCount) : nil
        }
    }

    private func normalizedSingleEffect(_ effect: AbilityEffectUnit) -> AbilityEffectUnit {
        effectWithCount(effect, count: 1)
    }

    private func effectCount(for effect: AbilityEffectUnit, in effects: [AbilityEffectUnit]) -> Int {
        effects
            .filter { abilityEffectKey($0) == abilityEffectKey(effect) }
            .map(effectCount)
            .reduce(0, +)
    }

    private func effectCount(_ effect: AbilityEffectUnit) -> Int {
        switch effect {
        case let .drawFish(count),
            let .placeEgg(count),
             let .placeYoung(count),
             let .hatchEgg(count),
             let .moveYoungOrSchool(count),
             let .recoverFromDiscardOrDraw(count),
             let .gainCoral(_, count),
             let .scatterSchool(count),
             let .consumeFishFromHand(count),
             let .playFishForFree(_, _, _, count):
            return count
        case .gameEndScore,
             .placeEggOnMatchingFish,
             .playFishFromHand:
            return 1
        case .unsupported:
            return 0
        }
    }

    private func effectWithCount(_ effect: AbilityEffectUnit, count: Int) -> AbilityEffectUnit {
        switch effect {
        case .drawFish:
            return .drawFish(count: count)
        case .placeEgg:
            return .placeEgg(count: count)
        case .placeYoung:
            return .placeYoung(count: count)
        case .hatchEgg:
            return .hatchEgg(count: count)
        case .moveYoungOrSchool:
            return .moveYoungOrSchool(count: count)
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw(count: count)
        case let .gameEndScore(condition, points):
            return .gameEndScore(condition: condition, points: points)
        case let .placeEggOnMatchingFish(filter, mode):
            return .placeEggOnMatchingFish(filter: filter, mode: mode)
        case let .playFishFromHand(filter, placement, costMode):
            return .playFishFromHand(filter: filter, placement: placement, costMode: costMode)
        case let .gainCoral(selector, _):
            return .gainCoral(selector: selector, count: count)
        case .scatterSchool:
            return .scatterSchool(count: count)
        case .consumeFishFromHand:
            return .consumeFishFromHand(count: count)
        case let .playFishForFree(filter, placement, sourceCondition, _):
            return .playFishForFree(
                filter: filter,
                placement: placement,
                sourceCondition: sourceCondition,
                count: count
            )
        case .unsupported:
            return .unsupported
        }
    }

    private func abilityEffectKey(_ effect: AbilityEffectUnit) -> String {
        switch effect {
        case .drawFish:
            return "drawFish"
        case .placeEgg:
            return "placeEgg"
        case .placeYoung:
            return "placeYoung"
        case .hatchEgg:
            return "hatchEgg"
        case .moveYoungOrSchool:
            return "moveYoungOrSchool"
        case .recoverFromDiscardOrDraw:
            return "recoverFromDiscardOrDraw"
        case let .gameEndScore(condition, points):
            return "gameEndScore-\(gameEndScoreConditionKey(condition))-\(points)"
        case let .placeEggOnMatchingFish(filter, mode):
            return "placeEggOnMatchingFish-\(eggPlacementFilterKey(filter))-\(mode)"
        case let .playFishFromHand(filter, placement, costMode):
            return "playFishFromHand-\(handFishFilterKey(filter))-\(placementConstraintKey(placement))-\(costMode)"
        case let .gainCoral(selector, _):
            return "gainCoral-\(selector.rawValue)"
        case .scatterSchool:
            return "scatterSchool"
        case .consumeFishFromHand:
            return "consumeFishFromHand"
        case let .playFishForFree(filter, placement, sourceCondition, _):
            return "playFishForFree-\(freePlayFilterKey(filter))-\(placementConstraintKey(placement))-\(freePlaySourceConditionKey(sourceCondition))"
        case .unsupported:
            return "unsupported"
        }
    }

    private func freePlayFilterKey(_ filter: FreePlayFishFilter) -> String {
        switch filter {
        case .any:
            return "any"
        case let .tag(kind):
            return "tag-\(kind)"
        case let .lengthBucket(bucket):
            return "length-\(bucket.rawValue)"
        case let .unsupported(value):
            return "unsupported-\(value)"
        }
    }

    private func freePlaySourceConditionKey(_ condition: FreePlaySourceCondition) -> String {
        switch condition {
        case .none:
            return "none"
        case .sourceDiveSiteHasNoCoral:
            return "sourceDiveSiteHasNoCoral"
        }
    }

    private func gameEndScoreConditionKey(_ condition: GameEndScoreCondition) -> String {
        switch condition {
        case .noTokensOnThisFish:
            return "noTokens"
        case let .consumedFishUnderThisFishAtLeast(count):
            return "consumedAtLeast-\(count)"
        case let .youngOnThisFishExactly(count):
            return "youngExactly-\(count)"
        case .bottomRow:
            return "bottomRow"
        case .schoolOnThisFish:
            return "school"
        case .eggYoungAndSchoolOnThisFish:
            return "eggYoungSchool"
        case let .allDiveSitesHaveCoralAtLeast(count):
            return "allCoralAtLeast-\(count)"
        case let .anyDiveSiteHasCoralAtLeast(count):
            return "anyCoralAtLeast-\(count)"
        }
    }

    private func eggPlacementFilterKey(_ filter: EggPlacementFilter) -> String {
        switch filter {
        case let .lengthBucket(bucket):
            return "length-\(bucket.rawValue)"
        case .topRow:
            return "topRow"
        case .bottomRow:
            return "bottomRow"
        case let .diveSite(diveSite):
            return "diveSite-\(diveSite.rawValue)"
        case let .tag(kind):
            return "tag-\(kind)"
        }
    }

    private func handFishFilterKey(_ filter: HandFishFilter) -> String {
        switch filter {
        case .any:
            return "any"
        case let .tag(kind):
            return "tag-\(kind)"
        case let .lengthBucket(bucket):
            return "length-\(bucket.rawValue)"
        case let .unsupported(value):
            return "unsupported-\(value)"
        }
    }

    private func placementConstraintKey(_ placement: FishPlacementConstraint) -> String {
        switch placement {
        case .any:
            return "any"
        case .topRow:
            return "topRow"
        case .bottomRow:
            return "bottomRow"
        case .sunlight:
            return "sunlight"
        case let .diveSite(diveSite):
            return "diveSite-\(diveSite.rawValue)"
        case let .diveSiteWithCoralAtLeast(count):
            return "diveSiteCoralAtLeast-\(count)"
        case .sameDiveSiteAsSource:
            return "sameDiveSiteAsSource"
        }
    }

    private func pendingChoiceKind(for effect: AbilityEffectUnit) -> PendingChoiceKind {
        switch effect {
        case .drawFish:
            return .drawFish
        case .placeEgg:
            return .placeEgg
        case .placeYoung:
            return .placeYoung
        case .hatchEgg:
            return .hatchEgg
        case .moveYoungOrSchool:
            return .moveYoungOrSchool
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw
        case .gameEndScore:
            return .unsupported
        case .placeEggOnMatchingFish:
            return .placeEggOnMatchingFish
        case .playFishFromHand:
            return .playFishFromHand
        case .gainCoral:
            return .gainCoral
        case .scatterSchool:
            return .scatterSchool
        case .consumeFishFromHand:
            return .consumeFishFromHand
        case .playFishForFree:
            return .playFishForFree
        case .unsupported:
            return .unsupported
        }
    }

    private func expectedInput(for effect: AbilityEffectUnit) -> PendingChoiceExpectedInput {
        switch effect {
        case .drawFish:
            return .none
        case .placeEgg,
             .placeYoung,
             .hatchEgg:
            return .targetSlot
        case .moveYoungOrSchool:
            return .sourceAndTargetSlots
        case .recoverFromDiscardOrDraw:
            return .cardSelection
        case .gameEndScore:
            return .none
        case let .placeEggOnMatchingFish(_, mode):
            return mode == .onEachEligibleFish ? .none : .matchingEggTarget
        case .playFishFromHand:
            return .playFishFromHandCard
        case .gainCoral:
            return .coralPlacement
        case .scatterSchool:
            return .scatterSchoolSource
        case .consumeFishFromHand:
            return .consumeFishConsumer
        case .playFishForFree:
            return .freePlayHandCard
        case .unsupported:
            return .none
        }
    }

    private func compoundEffectUnit(for choice: PendingChoice) -> AbilityEffectUnit? {
        choice.selectedAbilityEffect ?? compoundEffectUnit(for: choice.kind)
    }

    private func compoundEffectUnit(for kind: PendingChoiceKind) -> AbilityEffectUnit? {
        switch kind {
        case .drawFish:
            return .drawFish(count: 1)
        case .placeEgg:
            return .placeEgg(count: 1)
        case .placeYoung:
            return .placeYoung(count: 1)
        case .hatchEgg:
            return .hatchEgg(count: 1)
        case .moveYoungOrSchool:
            return .moveYoungOrSchool(count: 1)
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw(count: 1)
        case .placeEggOnMatchingFish:
            return nil
        case .playFishFromHand:
            return nil
        case .gainCoral:
            return nil
        case .scatterSchool:
            return .scatterSchool(count: 1)
        case .consumeFishFromHand:
            return .consumeFishFromHand(count: 1)
        case .playFishForFree:
            return nil
        case .compoundAbility,
             .bottomBonus,
             .placeholder,
             .unsupported:
            return nil
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
            case .coverShorterFish:
                break
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
        if let consumedFish = consumedFish(from: playerState.ocean.slots[slotIndex].content) {
            playerState.ocean.slots[slotIndex].consumedFish.append(consumedFish)
        }
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
        case let .updated(queue):
            state.activeDiveQueue = queue
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
            case let .placeYoung(target, amount):
                applyResourceChange(.young, amount: amount, at: target, to: &state)
            case let .hatchEgg(target, amount):
                applyResourceChange(.egg, amount: -amount, at: target, to: &state)
                applyResourceChange(.young, amount: amount, at: target, to: &state)
            case let .moveResource(source, target, kind, amount):
                applyResourceChange(kind, amount: -amount, at: source, to: &state)
                applyResourceChange(kind, amount: amount, at: target, to: &state)
            case let .gainCoral(playerId, diveSite, payment):
                applyCoralGain(playerId: playerId, diveSite: diveSite, payment: payment, to: &state)
        case let .gainCoralFromAbility(playerId, diveSite, _):
            applyCoralGainFromAbility(playerId: playerId, diveSite: diveSite, to: &state)
        case .skipCoral:
            break
        case let .scatterSchoolSourceRemoved(playerId, source):
            applyScatterSchoolSourceRemoval(playerId: playerId, source: source, to: &state)
        case let .scatterSchoolYoungPlaced(_, target):
            applyResourceChange(.young, amount: 1, at: target, to: &state)
        case let .fishConsumedFromHand(playerId, consumerSlot, consumedCardId):
            applyFishConsumedFromHand(
                playerId: playerId,
                consumerSlot: consumerSlot,
                consumedCardId: consumedCardId,
                to: &state
            )
        case let .fishPlayedForFree(playerId, cardId, targetSlot):
            applyFishPlayedForFree(
                playerId: playerId,
                cardId: cardId,
                targetSlot: targetSlot,
                to: &state
            )
        case let .fishPlayedFromHand(playerId, cardId, targetSlot, payment):
            applyFishPlayedFromHand(
                playerId: playerId,
                cardId: cardId,
                targetSlot: targetSlot,
                payment: payment,
                to: &state
            )
        }
    }
    }

    private func applyFishConsumedFromHand(
        playerId: PlayerID,
        consumerSlot: OceanSlotAddress,
        consumedCardId: CardID,
        to state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[playerId],
              let handIndex = playerState.hand.firstIndex(of: consumedCardId),
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == consumerSlot }),
              case .fishCard = playerState.ocean.slots[slotIndex].content
        else {
            return
        }

        playerState.hand.remove(at: handIndex)
        playerState.ocean.slots[slotIndex].consumedFish.append(
            ConsumedFish(cardId: consumedCardId, lengthCm: card(withId: consumedCardId)?.lengthCm)
        )
        state.playerGameStates[playerId] = playerState
    }

    private func applyFishPlayedForFree(
        playerId: PlayerID,
        cardId: CardID,
        targetSlot: OceanSlotAddress,
        to state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[playerId],
              let handIndex = playerState.hand.firstIndex(of: cardId),
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == targetSlot })
        else {
            return
        }

        playerState.hand.remove(at: handIndex)
        if let consumedFish = consumedFish(from: playerState.ocean.slots[slotIndex].content) {
            playerState.ocean.slots[slotIndex].consumedFish.append(consumedFish)
        }
        playerState.ocean.slots[slotIndex].content = .fishCard(cardId)
        state.playerGameStates[playerId] = playerState
    }

    private func applyFishPlayedFromHand(
        playerId: PlayerID,
        cardId: CardID,
        targetSlot: OceanSlotAddress,
        payment: PlayFishPayment,
        to state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[playerId],
              let slotIndex = playerState.ocean.slots.firstIndex(where: { $0.address == targetSlot })
        else {
            return
        }

        let discardedCardIds = Set(payment.discardedCardIds + [cardId])
        playerState.hand.removeAll { discardedCardIds.contains($0) }
        if let consumedFish = consumedFish(from: playerState.ocean.slots[slotIndex].content) {
            playerState.ocean.slots[slotIndex].consumedFish.append(consumedFish)
        }
        playerState.ocean.slots[slotIndex].content = .fishCard(cardId)
        applyResourcePayment(payment, to: &playerState)
        playerState.discardPile.append(contentsOf: payment.discardedCardIds)
        state.playerGameStates[playerId] = playerState
    }

    private func applyCoralGain(
        playerId: PlayerID,
        diveSite: DiveSite,
        payment: CoralPayment,
        to state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[playerId],
              let reefIndex = playerState.ocean.coralReefs.firstIndex(where: { $0.diveSite == diveSite })
        else {
            return
        }

        switch payment {
        case let .egg(source):
            removeResource(.egg, from: source, in: &playerState)
        case let .young(source):
            removeResource(.young, from: source, in: &playerState)
        case let .discard(cardId):
            guard let handIndex = playerState.hand.firstIndex(of: cardId) else {
                return
            }
            playerState.hand.remove(at: handIndex)
            playerState.discardPile.append(cardId)
        }

        let maxCoral = playerState.ocean.coralReefs[reefIndex].maxCoral
        playerState.ocean.coralReefs[reefIndex].coralCount = min(
            playerState.ocean.coralReefs[reefIndex].coralCount + 1,
            maxCoral
        )
        state.playerGameStates[playerId] = playerState
    }

    private func applyCoralGainFromAbility(
        playerId: PlayerID,
        diveSite: DiveSite,
        to state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[playerId],
              let reefIndex = playerState.ocean.coralReefs.firstIndex(where: { $0.diveSite == diveSite })
        else {
            return
        }

        let maxCoral = playerState.ocean.coralReefs[reefIndex].maxCoral
        playerState.ocean.coralReefs[reefIndex].coralCount = min(
            playerState.ocean.coralReefs[reefIndex].coralCount + 1,
            maxCoral
        )
        state.playerGameStates[playerId] = playerState
    }

    private func applyScatterSchoolSourceRemoval(
        playerId: PlayerID,
        source: OceanSlotAddress,
        to state: inout GameState
    ) {
        guard var playerState = state.playerGameStates[playerId] else {
            return
        }
        removeResource(.school, from: source, in: &playerState)
        state.playerGameStates[playerId] = playerState
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
        // TODO: If moving a school away leaves 3+ young and no school, resolve
        // source-slot school formation here as a rules-layer event effect.

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
        case .coverShorterFish:
            return true
        }
    }

    private func card(withId cardId: CardID) -> Card? {
        cardCatalog.card(forStoredId: cardId)
    }

    private func diveSiteSortIndex(_ diveSite: DiveSite) -> Int {
        switch diveSite {
        case .blue:
            return 0
        case .purple:
            return 1
        case .green:
            return 2
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

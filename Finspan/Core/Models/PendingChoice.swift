import Foundation

struct PendingChoice: Identifiable, Codable, Equatable, Sendable {
    var choiceId: PendingChoiceID
    var playerId: PlayerID
    var source: PendingChoiceSource
    var diveQueueId: DiveResolutionQueueID? = nil
    var diveStepId: DiveResolutionStepID? = nil
    var kind: PendingChoiceKind
    var options: [PendingChoiceOption]
    var expectedInput: PendingChoiceExpectedInput?
    var isOptional: Bool
    var abilityDefinition: AbilityDefinition? = nil
    var compoundAbilityProgress: CompoundAbilityProgress? = nil
    var scatterSchoolProgress: ScatterSchoolProgress? = nil
    var consumeFishFromHandProgress: ConsumeFishFromHandProgress? = nil
    var playFishForFreeProgress: PlayFishForFreeProgress? = nil
    var playFishFromHandProgress: PlayFishFromHandProgress? = nil
    var selectedAbilityEffect: AbilityEffectUnit? = nil
    // Legacy execution progress retained as the compatibility shell for engine
    // resolution. View models should prefer `v2PendingEffectSet` for generic
    // pending action display and fall back to these fields only for target
    // selection flows that still need legacy `PendingChoiceResolution` payloads.
    var allPlayersProgress: AllPlayersAbilityProgress? = nil
    var conditionalBonusProgress: ConditionalBonusAbilityProgress? = nil
    // Ability Engine v2 bridge. When present, this is the canonical pending
    // action description for UI display; when absent, `AbilityEngineV2Adapter`
    // derives the same shape from the legacy fields above.
    var pendingEffectSet: PendingEffectSet? = nil
    var createdAtSequence: EventID

    var id: PendingChoiceID { choiceId }
}

enum PendingChoiceSource: Codable, Equatable, Sendable {
    case diveBonus(DiveActionSite)
    case coralReef(DiveSite)
    case fishAbility(CardID)
    case endGameAbility(String)
    case allPlayers
    case expansion(String)
    case placeholder(String)
}

enum PendingChoiceKind: String, Codable, Equatable, Sendable {
    case drawFish
    case placeEgg
    case hatchEgg
    case placeYoung
    case recoverFromDiscardOrDraw
    case moveYoungOrSchool
    case gainCoral
    case placeEggOnMatchingFish
    case scatterSchool
    case consumeFishFromHand
    case playFishForFree
    case playFishFromHand
    case compoundAbility
    case bottomBonus
    case placeholder
    case unsupported
}

struct PendingChoiceOption: Codable, Equatable, Sendable {
    var optionId: String
    var label: String
}

enum PendingChoiceExpectedInput: Codable, Equatable, Sendable {
    case none
    case targetSlot
    case cardSelection
    case sourceAndTargetSlots
    case coralPayment
    case coralPlacement
    case matchingEggTarget
    case scatterSchoolSource
    case scatterSchoolYoungTarget
    case consumeFishConsumer
    case consumeFishHandCard
    case freePlayHandCard
    case freePlayTargetSlot
    case playFishFromHandCard
    case playFishFromHandTargetSlot
    case playFishFromHandPayment
    case abilityEffectSelection
    case count(Int)
}

enum PendingChoiceResolution: Codable, Equatable, Sendable {
    case skip
    case chooseTarget(OceanSlotAddress)
    case draw(count: Int)
    case recoverCard(CardID)
    case drawFromDeck
    case moveResource(source: OceanSlotAddress, target: OceanSlotAddress, kind: ResourceKind)
    case gainCoralWithEgg(source: OceanSlotAddress)
    case gainCoralWithYoung(source: OceanSlotAddress)
    case gainCoralByDiscard(cardId: CardID)
    case gainCoralFromAbility(diveSite: DiveSite)
    case chooseScatterSchoolSource(OceanSlotAddress)
    case placeScatterSchoolYoung(OceanSlotAddress)
    case scatterSchool(source: OceanSlotAddress, targets: [OceanSlotAddress])
    case chooseConsumeFishConsumer(OceanSlotAddress)
    case consumeFishFromHand(CardID)
    case consumeFishFromHandWithConsumer(consumerSlot: OceanSlotAddress, consumedCardId: CardID)
    case chooseFreePlayFish(CardID)
    case playFishForFree(cardId: CardID, targetSlot: OceanSlotAddress)
    case choosePlayFishFromHand(CardID)
    case choosePlayFishFromHandTarget(OceanSlotAddress)
    case playFishFromHand(cardId: CardID, targetSlot: OceanSlotAddress, payment: PlayFishPayment)
    case chooseOption(String)
    case chooseAbilityEffect(AbilityEffectUnit)
    case finishAbility
}

enum PendingChoiceAppliedEffect: Codable, Equatable, Sendable {
    case none
    case drawFish(playerId: PlayerID, cardIds: [CardID])
    case recoverFromDiscard(playerId: PlayerID, cardId: CardID)
    case placeEgg(target: OceanSlotAddress, amount: Int)
    case hatchEgg(target: OceanSlotAddress, amount: Int)
    case placeYoung(target: OceanSlotAddress, amount: Int)
    case moveResource(source: OceanSlotAddress, target: OceanSlotAddress, kind: ResourceKind, amount: Int)
    case gainCoral(playerId: PlayerID, diveSite: DiveSite, payment: CoralPayment)
    case gainCoralFromAbility(playerId: PlayerID, diveSite: DiveSite, sourceCardId: CardID)
    case skipCoral(playerId: PlayerID, diveSite: DiveSite)
    case scatterSchoolSourceRemoved(playerId: PlayerID, source: OceanSlotAddress)
    case scatterSchoolYoungPlaced(playerId: PlayerID, target: OceanSlotAddress)
    case fishConsumedFromHand(playerId: PlayerID, consumerSlot: OceanSlotAddress, consumedCardId: CardID)
    case fishPlayedForFree(playerId: PlayerID, cardId: CardID, targetSlot: OceanSlotAddress)
    case fishPlayedFromHand(playerId: PlayerID, cardId: CardID, targetSlot: OceanSlotAddress, payment: PlayFishPayment)
    case placeholder(String)
}

enum CoralPayment: Codable, Equatable, Sendable {
    case egg(source: OceanSlotAddress)
    case young(source: OceanSlotAddress)
    case discard(cardId: CardID)
}

struct ScatterSchoolProgress: Codable, Equatable, Sendable {
    var sourceSlot: OceanSlotAddress?
    var targetSlots: [OceanSlotAddress]
    var requiredTargetCount: Int
    var requiresSchoolSource: Bool

    nonisolated init(
        sourceSlot: OceanSlotAddress? = nil,
        targetSlots: [OceanSlotAddress] = [],
        requiredTargetCount: Int,
        requiresSchoolSource: Bool
    ) {
        self.sourceSlot = sourceSlot
        self.targetSlots = targetSlots
        self.requiredTargetCount = requiredTargetCount
        self.requiresSchoolSource = requiresSchoolSource
    }

    var completedTargetCount: Int {
        targetSlots.count
    }

    var isComplete: Bool {
        completedTargetCount >= requiredTargetCount
    }
}

struct ConsumeFishFromHandProgress: Codable, Equatable, Sendable {
    var consumerSlot: OceanSlotAddress?

    nonisolated init(consumerSlot: OceanSlotAddress? = nil) {
        self.consumerSlot = consumerSlot
    }
}

struct PlayFishForFreeProgress: Codable, Equatable, Sendable {
    var selectedCardId: CardID?

    nonisolated init(selectedCardId: CardID? = nil) {
        self.selectedCardId = selectedCardId
    }
}

struct PlayFishFromHandProgress: Codable, Equatable, Sendable {
    var selectedCardId: CardID?
    var targetSlot: OceanSlotAddress?

    nonisolated init(selectedCardId: CardID? = nil, targetSlot: OceanSlotAddress? = nil) {
        self.selectedCardId = selectedCardId
        self.targetSlot = targetSlot
    }
}

struct AllPlayersAbilityProgress: Codable, Equatable, Sendable {
    var abilityId: AbilityID
    var sourcePlayerId: PlayerID
    var sourceCardId: CardID
    var sourceAddress: OceanSlotAddress
    var baseChoiceId: PendingChoiceID
    var currentTargetPlayerId: PlayerID
    var remainingPlayerIds: [PlayerID]
    var resolvedPlayerIds: [PlayerID]
    var skippedPlayerIds: [PlayerID]

    nonisolated init(
        abilityId: AbilityID,
        sourcePlayerId: PlayerID,
        sourceCardId: CardID,
        sourceAddress: OceanSlotAddress,
        baseChoiceId: PendingChoiceID,
        currentTargetPlayerId: PlayerID,
        remainingPlayerIds: [PlayerID],
        resolvedPlayerIds: [PlayerID] = [],
        skippedPlayerIds: [PlayerID] = []
    ) {
        self.abilityId = abilityId
        self.sourcePlayerId = sourcePlayerId
        self.sourceCardId = sourceCardId
        self.sourceAddress = sourceAddress
        self.baseChoiceId = baseChoiceId
        self.currentTargetPlayerId = currentTargetPlayerId
        self.remainingPlayerIds = remainingPlayerIds
        self.resolvedPlayerIds = resolvedPlayerIds
        self.skippedPlayerIds = skippedPlayerIds
    }
}

struct ConditionalBonusAbilityProgress: Codable, Equatable, Sendable {
    var abilityId: AbilityID
    var playerId: PlayerID
    var sourceCardId: CardID
    var sourceAddress: OceanSlotAddress
    var baseChoiceId: PendingChoiceID
    var phase: ConditionalBonusAbilityPhase
    var requirement: SourceDiveSiteColoredCoralRequirement
    var baseWasSkipped: Bool?
    var bonusRequirementMet: Bool?

    nonisolated init(
        abilityId: AbilityID,
        playerId: PlayerID,
        sourceCardId: CardID,
        sourceAddress: OceanSlotAddress,
        baseChoiceId: PendingChoiceID,
        phase: ConditionalBonusAbilityPhase,
        requirement: SourceDiveSiteColoredCoralRequirement,
        baseWasSkipped: Bool? = nil,
        bonusRequirementMet: Bool? = nil
    ) {
        self.abilityId = abilityId
        self.playerId = playerId
        self.sourceCardId = sourceCardId
        self.sourceAddress = sourceAddress
        self.baseChoiceId = baseChoiceId
        self.phase = phase
        self.requirement = requirement
        self.baseWasSkipped = baseWasSkipped
        self.bonusRequirementMet = bonusRequirementMet
    }
}

enum ConditionalBonusAbilityPhase: String, Codable, Equatable, Sendable {
    case base
    case bonus
}

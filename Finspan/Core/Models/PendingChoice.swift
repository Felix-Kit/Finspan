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
    var selectedAbilityEffect: AbilityEffectUnit? = nil
    var createdAtSequence: EventID

    var id: PendingChoiceID { choiceId }
}

enum PendingChoiceSource: Codable, Equatable, Sendable {
    case diveBonus(DiveActionSite)
    case coralReef(DiveSite)
    case fishAbility(CardID)
    case endGameAbility
    case allPlayers
    case expansion(String)
    case placeholder(String)
}

enum PendingChoiceKind: String, Codable, Equatable, Sendable {
    case drawFish
    case placeEgg
    case hatchEgg
    case recoverFromDiscardOrDraw
    case moveYoungOrSchool
    case gainCoral
    case scatterSchool
    case consumeFishFromHand
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
    case scatterSchoolSource
    case scatterSchoolYoungTarget
    case consumeFishConsumer
    case consumeFishHandCard
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
    case chooseConsumeFishConsumer(OceanSlotAddress)
    case consumeFishFromHand(CardID)
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
    case moveResource(source: OceanSlotAddress, target: OceanSlotAddress, kind: ResourceKind, amount: Int)
    case gainCoral(playerId: PlayerID, diveSite: DiveSite, payment: CoralPayment)
    case gainCoralFromAbility(playerId: PlayerID, diveSite: DiveSite, sourceCardId: CardID)
    case skipCoral(playerId: PlayerID, diveSite: DiveSite)
    case scatterSchoolSourceRemoved(playerId: PlayerID, source: OceanSlotAddress)
    case scatterSchoolYoungPlaced(playerId: PlayerID, target: OceanSlotAddress)
    case fishConsumedFromHand(playerId: PlayerID, consumerSlot: OceanSlotAddress, consumedCardId: CardID)
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

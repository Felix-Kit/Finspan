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
    var createdAtSequence: EventID

    var id: PendingChoiceID { choiceId }
}

enum PendingChoiceSource: Codable, Equatable, Sendable {
    case diveBonus(DiveActionSite)
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
    case placeholder(String)
}

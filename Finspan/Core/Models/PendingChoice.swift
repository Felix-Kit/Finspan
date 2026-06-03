import Foundation

struct PendingChoice: Identifiable, Codable, Equatable, Sendable {
    var choiceId: PendingChoiceID
    var playerId: PlayerID
    var source: PendingChoiceSource
    var kind: PendingChoiceKind
    var options: [PendingChoiceOption]
    var expectedInput: PendingChoiceExpectedInput?
    var isOptional: Bool
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
    case count(Int)
}

enum PendingChoiceResolution: Codable, Equatable, Sendable {
    case skip
    case chooseTarget(OceanSlotAddress)
    case draw(count: Int)
    case chooseOption(String)
}

enum PendingChoiceAppliedEffect: Codable, Equatable, Sendable {
    case none
    case drawFish(playerId: PlayerID, cardIds: [CardID])
    case placeEgg(target: OceanSlotAddress, amount: Int)
    case hatchEgg(target: OceanSlotAddress, amount: Int)
    case placeholder(String)
}

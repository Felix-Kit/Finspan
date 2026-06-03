import Foundation

struct Card: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var costs: [Cost]
    var requirements: [Requirement]
    var abilities: [AbilityDefinition]
    var allowedZones: [OceanZone]
    var requiredDiveSiteColor: DiveSiteColor?

    init(
        id: String,
        name: String,
        costs: [Cost] = [],
        requirements: [Requirement] = [],
        abilities: [AbilityDefinition] = [],
        allowedZones: [OceanZone] = OceanZone.allCases,
        requiredDiveSiteColor: DiveSiteColor? = nil
    ) {
        self.id = id
        self.name = name
        self.costs = costs
        self.requirements = requirements
        self.abilities = abilities
        self.allowedZones = allowedZones
        self.requiredDiveSiteColor = requiredDiveSiteColor
    }
}

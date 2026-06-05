import Foundation

struct Card: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var costs: [Cost]
    var requirements: [Requirement]
    var abilityIds: [AbilityID]
    /// Compatibility fallback for legacy fixtures. New card data should prefer `abilityIds`.
    var abilities: [AbilityDefinition]
    var allowedZones: [OceanZone]
    var requiredDiveSiteColor: DiveSiteColor?
    var printedPoints: Int
    var lengthCm: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case costs
        case requirements
        case abilityIds
        case abilities
        case allowedZones
        case requiredDiveSiteColor
        case printedPoints
        case lengthCm
    }

    init(
        id: String,
        name: String,
        costs: [Cost] = [],
        requirements: [Requirement] = [],
        abilityIds: [AbilityID] = [],
        abilities: [AbilityDefinition] = [],
        allowedZones: [OceanZone] = OceanZone.allCases,
        requiredDiveSiteColor: DiveSiteColor? = nil,
        printedPoints: Int = 0,
        lengthCm: Int = 0
    ) {
        self.id = id
        self.name = name
        self.costs = costs
        self.requirements = requirements
        self.abilityIds = abilityIds
        self.abilities = abilities
        self.allowedZones = allowedZones
        self.requiredDiveSiteColor = requiredDiveSiteColor
        self.printedPoints = printedPoints
        self.lengthCm = lengthCm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        costs = try container.decodeIfPresent([Cost].self, forKey: .costs) ?? []
        requirements = try container.decodeIfPresent([Requirement].self, forKey: .requirements) ?? []
        abilityIds = try container.decodeIfPresent([AbilityID].self, forKey: .abilityIds) ?? []
        abilities = try container.decodeIfPresent([AbilityDefinition].self, forKey: .abilities) ?? []
        allowedZones = try container.decodeIfPresent([OceanZone].self, forKey: .allowedZones) ?? OceanZone.allCases
        requiredDiveSiteColor = try container.decodeIfPresent(DiveSiteColor.self, forKey: .requiredDiveSiteColor)
        printedPoints = try container.decodeIfPresent(Int.self, forKey: .printedPoints) ?? 0
        lengthCm = try container.decodeIfPresent(Int.self, forKey: .lengthCm) ?? 0
    }
}

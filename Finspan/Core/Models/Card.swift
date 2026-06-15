import Foundation

struct CardTag: Codable, Equatable, Sendable {
    var kind: String
    var count: Int
}

struct Card: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var scientificName: String?
    var costs: [Cost]
    var requirements: [Requirement]
    var abilityIds: [AbilityID]
    /// Compatibility fallback for legacy fixtures. New card data should prefer `abilityIds`.
    var abilities: [AbilityDefinition]
    var abilityText: String?
    var cardFaceName: String?
    var cardFaceAbilityText: String?
    var tags: [CardTag]
    var visualAssetName: String?
    var allowedZones: [OceanZone]
    var requiredDiveSiteColor: DiveSiteColor?
    var printedPoints: Int
    var lengthCm: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case scientificName
        case costs
        case requirements
        case abilityIds
        case abilities
        case abilityText
        case cardFaceName
        case cardFaceAbilityText
        case tags
        case visualAssetName
        case allowedZones
        case requiredDiveSiteColor
        case printedPoints
        case lengthCm
    }

    init(
        id: String,
        name: String,
        scientificName: String? = nil,
        costs: [Cost] = [],
        requirements: [Requirement] = [],
        abilityIds: [AbilityID] = [],
        abilities: [AbilityDefinition] = [],
        abilityText: String? = nil,
        cardFaceName: String? = nil,
        cardFaceAbilityText: String? = nil,
        tags: [CardTag] = [],
        visualAssetName: String? = nil,
        allowedZones: [OceanZone] = OceanZone.allCases,
        requiredDiveSiteColor: DiveSiteColor? = nil,
        printedPoints: Int = 0,
        lengthCm: Int = 0
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.costs = costs
        self.requirements = requirements
        self.abilityIds = abilityIds
        self.abilities = abilities
        self.abilityText = abilityText
        self.cardFaceName = cardFaceName
        self.cardFaceAbilityText = cardFaceAbilityText
        self.tags = tags
        self.visualAssetName = visualAssetName
        self.allowedZones = allowedZones
        self.requiredDiveSiteColor = requiredDiveSiteColor
        self.printedPoints = printedPoints
        self.lengthCm = lengthCm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        scientificName = try container.decodeIfPresent(String.self, forKey: .scientificName)
        costs = try container.decodeIfPresent([Cost].self, forKey: .costs) ?? []
        requirements = try container.decodeIfPresent([Requirement].self, forKey: .requirements) ?? []
        abilityIds = try container.decodeIfPresent([AbilityID].self, forKey: .abilityIds) ?? []
        abilities = try container.decodeIfPresent([AbilityDefinition].self, forKey: .abilities) ?? []
        abilityText = try container.decodeIfPresent(String.self, forKey: .abilityText)
        cardFaceName = try container.decodeIfPresent(String.self, forKey: .cardFaceName)
        cardFaceAbilityText = try container.decodeIfPresent(String.self, forKey: .cardFaceAbilityText)
        tags = try container.decodeIfPresent([CardTag].self, forKey: .tags) ?? []
        visualAssetName = try container.decodeIfPresent(String.self, forKey: .visualAssetName)
        allowedZones = try container.decodeIfPresent([OceanZone].self, forKey: .allowedZones) ?? OceanZone.allCases
        requiredDiveSiteColor = try container.decodeIfPresent(DiveSiteColor.self, forKey: .requiredDiveSiteColor)
        printedPoints = try container.decodeIfPresent(Int.self, forKey: .printedPoints) ?? 0
        lengthCm = try container.decodeIfPresent(Int.self, forKey: .lengthCm) ?? 0
    }
}

extension Card {
    var cardFaceDisplayName: String {
        guard let cardFaceName,
              !cardFaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return name
        }
        return cardFaceName
    }

    var cardFaceRawAbilityText: String? {
        guard let cardFaceAbilityText,
              !cardFaceAbilityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return abilityText
        }
        return cardFaceAbilityText
    }

    var requiresCoveringShorterFish: Bool {
        costs.contains { cost in
            if case .coverShorterFish = cost {
                return true
            }
            return false
        }
    }
}

import Foundation

/// Runtime catalog for Sharks & Reefs fish cards.
///
/// This loader intentionally only imports card data. Sharks & Reefs rules such
/// as coral costs, shark abilities, achievements, and scoring remain unsupported
/// until their rule modules are implemented.
struct SharksAndReefsCardCatalog: CardCatalog {
    let starterFishCards: [Card]
    let fishCards: [Card]

    init(bundle: Bundle = Bundle(for: SharksAndReefsCardCatalogBundleToken.self)) throws {
        self = try SharksAndReefsCardCatalog(
            dataSource: BundleSharksAndReefsCardDataSource(bundle: bundle)
        )
    }

    init(dataSource: any CardDataSource) throws {
        let data = try dataSource.loadCatalogData()
        starterFishCards = data.starterFishCards
        fishCards = data.fishCards
    }
}

private final class SharksAndReefsCardCatalogBundleToken: NSObject {}

enum SharksAndReefsCardCatalogError: Error, Equatable {
    case missingResource(String)
    case unsupportedZone(String)
    case unsupportedCostKind(String)
}

struct BundleSharksAndReefsCardDataSource: CardDataSource {
    let bundle: Bundle

    func loadCatalogData() throws -> CardCatalogData {
        let fishCards = try loadCards(named: "sharks_reefs_main_fish_cards")
        let starterFishCards = try loadCards(named: "sharks_reefs_starter_fish_cards")
        return CardCatalogData(
            starterFishCards: starterFishCards,
            fishCards: fishCards
        )
    }

    private func loadCards(named resourceName: String) throws -> [Card] {
        guard let url = bundle.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "Resources/Cards"
        ) ?? bundle.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "Cards"
        ) ?? bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SharksAndReefsCardCatalogError.missingResource(resourceName)
        }

        let data = try Data(contentsOf: url)
        let decodedCards = try JSONDecoder().decode([SharksAndReefsRuntimeCardDTO].self, from: data)
        return try decodedCards.map(Card.init(sharksAndReefsRuntimeDTO:))
    }
}

private struct SharksAndReefsRuntimeCardDTO: Decodable {
    var id: String
    var sourceId: Int
    var name: LocalizedCardTextDTO
    var scientificName: String?
    var printedPoints: Int
    var lengthCm: Int
    var allowedZones: [String]
    var requiredDiveSiteColor: DiveSiteColor?
    var costs: [SharksAndReefsRuntimeCostDTO]
    var requirements: [Requirement]
    var tags: [CardTag]
    var abilityText: LocalizedCardTextDTO?
    var abilityIds: [AbilityID]
    var visual: SharksAndReefsVisualDTO?
}

private struct LocalizedCardTextDTO: Decodable {
    var en: String?
    var zh: String?
    var raw: String?

    var displayText: String {
        if let zh, !zh.isEmpty {
            return zh
        }
        if let raw, !raw.isEmpty {
            return raw
        }
        return en ?? ""
    }

    var cardFaceText: String {
        if let raw, !raw.isEmpty {
            return raw
        }
        if let en, !en.isEmpty {
            return en
        }
        return displayText
    }
}

private struct SharksAndReefsVisualDTO: Decodable {
    var fishImageAsset: String?
}

private struct SharksAndReefsRuntimeCostDTO: Decodable {
    var kind: String
    var resource: String?
    var count: FlexibleRuntimeCount
}

private enum FlexibleRuntimeCount: Decodable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        self = .string(try container.decode(String.self))
    }

    var numericValue: Int {
        switch self {
        case let .int(value):
            return value
        case let .string(value):
            let digits = value.split { !$0.isNumber }.compactMap { Int($0) }
            return digits.last ?? 1
        }
    }

    var stringValue: String {
        switch self {
        case let .int(value):
            return "any:\(value)"
        case let .string(value):
            return value
        }
    }
}

private extension Card {
    nonisolated init(sharksAndReefsRuntimeDTO dto: SharksAndReefsRuntimeCardDTO) throws {
        self.init(
            id: dto.id,
            name: dto.name.displayText,
            scientificName: dto.scientificName,
            costs: try dto.costs.compactMap(Cost.init(sharksAndReefsRuntimeDTO:)),
            requirements: dto.requirements + dto.costs.compactMap(Requirement.init(sharksAndReefsRuntimeDTO:)),
            abilityIds: dto.abilityIds,
            abilityText: dto.abilityText?.displayText,
            cardFaceName: dto.name.cardFaceText,
            cardFaceAbilityText: dto.abilityText?.cardFaceText,
            tags: dto.tags,
            visualAssetName: dto.visual?.fishImageAsset?.removingPathExtension ?? "\(dto.sourceId)",
            allowedZones: try dto.allowedZones.map(OceanZone.init(sharksAndReefsRuntimeValue:)),
            requiredDiveSiteColor: dto.requiredDiveSiteColor,
            printedPoints: dto.printedPoints,
            lengthCm: dto.lengthCm
        )
    }
}

private extension Cost {
    nonisolated init?(sharksAndReefsRuntimeDTO dto: SharksAndReefsRuntimeCostDTO) throws {
        switch dto.kind {
        case "discardCards":
            self = .discardCards(count: dto.count.numericValue)
        case "resource":
            let resource = dto.resource ?? ""
            self = .resource(kind: ResourceKind(rawValue: resource), count: dto.count.numericValue)
        case "coverShorterFish":
            self = .coverShorterFish(count: dto.count.numericValue)
        case "coralRequirementOrCost":
            return nil
        default:
            throw SharksAndReefsCardCatalogError.unsupportedCostKind(dto.kind)
        }
    }
}

private extension Requirement {
    nonisolated init?(sharksAndReefsRuntimeDTO dto: SharksAndReefsRuntimeCostDTO) {
        guard dto.kind == "coralRequirementOrCost",
              let coralRequirement = CoralRequirement(sharksAndReefsRuntimeValue: dto.count.stringValue)
        else {
            return nil
        }
        self.init(coralRequirement: coralRequirement)
    }
}

private extension CoralRequirement {
    nonisolated init?(sharksAndReefsRuntimeValue value: String) {
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let diveSite = CoralRequirementDiveSite(rawValue: parts[0]),
              let count = Int(parts[1])
        else {
            return nil
        }
        self.init(diveSite: diveSite, count: count)
    }
}

private extension OceanZone {
    nonisolated init(sharksAndReefsRuntimeValue: String) throws {
        switch sharksAndReefsRuntimeValue {
        case "sunlight", "sunlit":
            self = .sunlit
        case "twilight":
            self = .twilight
        case "midnight":
            self = .midnight
        default:
            throw SharksAndReefsCardCatalogError.unsupportedZone(sharksAndReefsRuntimeValue)
        }
    }
}

private extension String {
    var removingPathExtension: String {
        (self as NSString).deletingPathExtension
    }
}

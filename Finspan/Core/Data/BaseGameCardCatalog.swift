import Foundation

/// Entry point for the reviewed local base game card dataset.
///
/// This catalog reads local JSON bundled with the app. It deliberately does not
/// include Sharks & Reefs cards or remote asset URLs; future image imports should
/// resolve to local assets before runtime data depends on them.
struct BaseGameCardCatalog: CardCatalog {
    let starterFishCards: [Card]
    let fishCards: [Card]

    init(bundle: Bundle = Bundle(for: BaseGameCardCatalogBundleToken.self)) throws {
        self = try BaseGameCardCatalog(
            dataSource: BundleBaseGameCardDataSource(bundle: bundle)
        )
    }

    init(dataSource: any CardDataSource) throws {
        let data = try dataSource.loadCatalogData()
        starterFishCards = data.starterFishCards
        fishCards = data.fishCards
    }
}

private final class BaseGameCardCatalogBundleToken: NSObject {}

enum BaseGameCardCatalogError: Error, Equatable {
    case missingResource(String)
    case unsupportedZone(String)
    case unsupportedCostKind(String)
}

struct BundleBaseGameCardDataSource: CardDataSource {
    let bundle: Bundle

    func loadCatalogData() throws -> CardCatalogData {
        let fishCards = try loadCards(named: "base_main_fish_cards")
        let starterFishCards = try loadCards(named: "base_starter_fish_cards")
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
            throw BaseGameCardCatalogError.missingResource(resourceName)
        }

        let data = try Data(contentsOf: url)
        let decodedCards = try JSONDecoder().decode([RuntimeCardDTO].self, from: data)
        return try decodedCards.map(Card.init(runtimeDTO:))
    }
}

private struct RuntimeCardDTO: Decodable {
    var id: String
    var name: String
    var scientificName: String?
    var printedPoints: Int
    var lengthCm: Int
    var allowedZones: [String]
    var requiredDiveSiteColor: DiveSiteColor?
    var costs: [RuntimeCostDTO]
    var requirements: [Requirement]
    var tags: [CardTag]
    var abilityText: String?
    var abilityIds: [AbilityID]
    var visualAssetName: String?
}

private struct RuntimeCostDTO: Decodable {
    var kind: String
    var resource: String?
    var count: Int
}

private extension Card {
    nonisolated init(runtimeDTO dto: RuntimeCardDTO) throws {
        self.init(
            id: dto.id,
            name: dto.name,
            scientificName: dto.scientificName,
            costs: try dto.costs.map(Cost.init(runtimeDTO:)),
            requirements: dto.requirements,
            abilityIds: dto.abilityIds,
            abilityText: dto.abilityText,
            tags: dto.tags,
            visualAssetName: dto.visualAssetName,
            allowedZones: try dto.allowedZones.map(OceanZone.init(runtimeValue:)),
            requiredDiveSiteColor: dto.requiredDiveSiteColor,
            printedPoints: dto.printedPoints,
            lengthCm: dto.lengthCm
        )
    }
}

private extension Cost {
    nonisolated init(runtimeDTO dto: RuntimeCostDTO) throws {
        switch dto.kind {
        case "discardCards":
            self = .discardCards(count: dto.count)
        case "resource":
            let resource = dto.resource ?? ""
            self = .resource(kind: ResourceKind(rawValue: resource), count: dto.count)
        case "coverShorterFish":
            self = .coverShorterFish(count: dto.count)
        default:
            throw BaseGameCardCatalogError.unsupportedCostKind(dto.kind)
        }
    }
}

private extension OceanZone {
    nonisolated init(runtimeValue: String) throws {
        switch runtimeValue {
        case "sunlight", "sunlit":
            self = .sunlit
        case "twilight":
            self = .twilight
        case "midnight":
            self = .midnight
        default:
            throw BaseGameCardCatalogError.unsupportedZone(runtimeValue)
        }
    }
}

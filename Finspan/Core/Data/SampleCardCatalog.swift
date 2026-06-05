import Foundation

/// Playable development-only card data.
///
/// This catalog intentionally does not represent the complete Finspan base game.
struct SampleCardCatalog: CardCatalog {
    let starterFishCards: [Card]
    let fishCards: [Card]

    init() {
        let data = SampleCardFixtures.catalogData
        starterFishCards = data.starterFishCards
        fishCards = data.fishCards
    }
}

private enum SampleCardFixtures {
    static let catalogData = CardCatalogData(
        starterFishCards: (1...16).map { index in
            Card(
                id: "starter-fish-\(index)",
                name: "Starter Fish \(index)",
                printedPoints: 1,
                lengthCm: 2
            )
        },
        fishCards: (1...32).map { index in
            switch index {
            case 1:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.discardCards(count: 1)],
                    allowedZones: [.sunlit],
                    printedPoints: 2,
                    lengthCm: 6
                )
            case 2:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.resource(kind: .egg, count: 1)],
                    allowedZones: [.sunlit],
                    printedPoints: 3,
                    lengthCm: 4
                )
            case 3:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.resource(kind: .young, count: 1)],
                    allowedZones: [.sunlit],
                    printedPoints: 4,
                    lengthCm: 5
                )
            case 4:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    allowedZones: [.twilight],
                    requiredDiveSiteColor: .green,
                    printedPoints: 5,
                    lengthCm: 10
                )
            case 5:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    requirements: [Requirement(kind: "unsupported-sample", value: "true")],
                    printedPoints: 1,
                    lengthCm: 3
                )
            case 30:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish A",
                    abilityIds: [SampleAbilityIDs.fishAIfActivatedDrawFishOne],
                    printedPoints: 2,
                    lengthCm: 30
                )
            case 31:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish B",
                    abilityIds: [SampleAbilityIDs.fishBIfActivatedPlaceTwoEggsHatchOne],
                    printedPoints: 3,
                    lengthCm: 31
                )
            case 32:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish C",
                    abilityIds: [SampleAbilityIDs.fishCWhenPlayedDrawFishOne],
                    printedPoints: 4,
                    lengthCm: 32
                )
            default:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    printedPoints: (index % 5) + 1,
                    lengthCm: index + 2
                )
            }
        }
    )
}

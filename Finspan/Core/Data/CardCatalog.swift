import Foundation

protocol CardCatalog {
    var starterFishCards: [Card] { get }
    var fishCards: [Card] { get }
}

struct SampleCardCatalog: CardCatalog {
    let starterFishCards: [Card]
    let fishCards: [Card]

    init() {
        starterFishCards = (1...16).map { index in
            Card(id: "starter-fish-\(index)", name: "Starter Fish \(index)")
        }
        fishCards = (1...32).map { index in
            switch index {
            case 1:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.discardCards(count: 1)],
                    allowedZones: [.sunlit]
                )
            case 2:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.resource(kind: .egg, count: 1)],
                    allowedZones: [.sunlit]
                )
            case 3:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.resource(kind: .young, count: 1)],
                    allowedZones: [.sunlit]
                )
            case 4:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    allowedZones: [.twilight],
                    requiredDiveSiteColor: .green
                )
            case 5:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    requirements: [Requirement(kind: "unsupported-sample", value: "true")]
                )
            default:
                return Card(id: "fish-\(index)", name: "Fish \(index)")
            }
        }
    }
}

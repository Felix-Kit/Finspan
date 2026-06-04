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
            Card(
                id: "starter-fish-\(index)",
                name: "Starter Fish \(index)",
                printedPoints: 1
            )
        }
        fishCards = (1...32).map { index in
            switch index {
            case 1:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.discardCards(count: 1)],
                    allowedZones: [.sunlit],
                    printedPoints: 2
                )
            case 2:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.resource(kind: .egg, count: 1)],
                    allowedZones: [.sunlit],
                    printedPoints: 3
                )
            case 3:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    costs: [.resource(kind: .young, count: 1)],
                    allowedZones: [.sunlit],
                    printedPoints: 4
                )
            case 4:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    allowedZones: [.twilight],
                    requiredDiveSiteColor: .green,
                    printedPoints: 5
                )
            case 5:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    requirements: [Requirement(kind: "unsupported-sample", value: "true")],
                    printedPoints: 1
                )
            default:
                return Card(
                    id: "fish-\(index)",
                    name: "Fish \(index)",
                    printedPoints: (index % 5) + 1
                )
            }
        }
    }
}

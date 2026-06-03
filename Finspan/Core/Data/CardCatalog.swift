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
            Card(id: "fish-\(index)", name: "Fish \(index)")
        }
    }
}

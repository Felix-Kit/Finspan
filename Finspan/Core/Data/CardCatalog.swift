import Foundation

protocol CardCatalog {
    var starterFishCards: [Card] { get }
    var fishCards: [Card] { get }
}

struct CardCatalogData: Codable, Equatable, Sendable {
    var starterFishCards: [Card]
    var fishCards: [Card]
}

protocol CardDataSource: Sendable {
    func loadCatalogData() throws -> CardCatalogData
}

struct JSONCardDataSource: CardDataSource {
    let data: Data

    func loadCatalogData() throws -> CardCatalogData {
        try JSONDecoder().decode(CardCatalogData.self, from: data)
    }
}

struct SwiftFixtureCardDataSource: CardDataSource {
    let catalogData: CardCatalogData

    func loadCatalogData() throws -> CardCatalogData {
        catalogData
    }
}

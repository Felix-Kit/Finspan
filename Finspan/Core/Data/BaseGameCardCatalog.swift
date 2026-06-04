import Foundation

/// Future entry point for the complete authoritative base game card dataset.
///
/// Production card data should be supplied through a `CardDataSource`, such as
/// decoded JSON or a reviewed Swift fixture. The current playable loop continues
/// to use `SampleCardCatalog` until that dataset is available.
struct BaseGameCardCatalog: CardCatalog {
    let starterFishCards: [Card]
    let fishCards: [Card]

    init(dataSource: any CardDataSource) throws {
        let data = try dataSource.loadCatalogData()
        starterFishCards = data.starterFishCards
        fishCards = data.fishCards
    }
}

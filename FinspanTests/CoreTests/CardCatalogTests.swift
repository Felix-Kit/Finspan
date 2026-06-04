import XCTest
@testable import Finspan

final class CardCatalogTests: XCTestCase {

    func testSampleCardCatalogLoadsPlayableFixture() {
        let catalog = SampleCardCatalog()

        XCTAssertEqual(catalog.starterFishCards.count, 16)
        XCTAssertEqual(catalog.fishCards.count, 32)
        XCTAssertEqual(catalog.starterFishCards.first?.id, "starter-fish-1")
        XCTAssertEqual(catalog.fishCards.first?.id, "fish-1")
    }

    func testBaseGameCardCatalogLoadsSwiftFixtureDataSource() throws {
        let data = makeCatalogData()

        let catalog = try BaseGameCardCatalog(
            dataSource: SwiftFixtureCardDataSource(catalogData: data)
        )

        XCTAssertEqual(catalog.starterFishCards, data.starterFishCards)
        XCTAssertEqual(catalog.fishCards, data.fishCards)
    }

    func testJSONCardDataSourceDecodesCatalogData() throws {
        let expected = makeCatalogData()
        let encoded = try JSONEncoder().encode(expected)

        let decoded = try JSONCardDataSource(data: encoded).loadCatalogData()

        XCTAssertEqual(decoded, expected)
    }

    private func makeCatalogData() -> CardCatalogData {
        CardCatalogData(
            starterFishCards: [
                Card(id: "starter-base-game-1", name: "Starter Base Game 1", printedPoints: 1)
            ],
            fishCards: [
                Card(id: "base-game-1", name: "Base Game 1", printedPoints: 2)
            ]
        )
    }
}

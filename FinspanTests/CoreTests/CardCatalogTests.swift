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

    func testBaseGameCardCatalogLoadsBundledMainAndStarterCards() throws {
        let catalog = try BaseGameCardCatalog()

        XCTAssertEqual(catalog.fishCards.count, 125)
        XCTAssertEqual(catalog.starterFishCards.count, 10)
        XCTAssertEqual(catalog.fishCards.count + catalog.starterFishCards.count, 135)
    }

    func testSharksAndReefsCardCatalogLoadsBundledMainAndStarterCards() throws {
        let catalog = try SharksAndReefsCardCatalog()

        XCTAssertEqual(catalog.fishCards.count, 75)
        XCTAssertEqual(catalog.starterFishCards.count, 5)
        XCTAssertEqual(catalog.fishCards.count + catalog.starterFishCards.count, 80)
        XCTAssertTrue(catalog.fishCards.allSatisfy { $0.id.hasPrefix("sr.main.") })
        XCTAssertTrue(catalog.starterFishCards.allSatisfy { $0.id.hasPrefix("sr.starter.") })
    }

    func testCardCatalogFactoryKeepsBaseGameCountsWithoutSharksAndReefs() throws {
        let catalog = try CardCatalogFactory().makeCatalog(for: .baseGame, enabledExpansions: [])

        XCTAssertEqual(catalog.fishCards.count, 125)
        XCTAssertEqual(catalog.starterFishCards.count, 10)
    }

    func testCardCatalogFactoryMergesSharksAndReefsWithBaseGame() throws {
        let catalog = try CardCatalogFactory().makeCatalog(
            for: .baseGame,
            enabledExpansions: [.sharksAndReefs]
        )

        XCTAssertEqual(catalog.fishCards.count, 200)
        XCTAssertEqual(catalog.starterFishCards.count, 15)
        XCTAssertTrue(catalog.fishCards.contains { $0.id == "sr.main.136" })
        XCTAssertTrue(catalog.starterFishCards.contains { $0.id == "sr.starter.211" })
    }

    func testSampleCatalogIgnoresSelectedSharksAndReefsExpansion() throws {
        let catalog = try CardCatalogFactory().makeCatalog(
            for: .sample,
            enabledExpansions: [.sharksAndReefs]
        )

        XCTAssertEqual(catalog.fishCards.count, 32)
        XCTAssertEqual(catalog.starterFishCards.count, 16)
        XCTAssertTrue(catalog.fishCards.allSatisfy { $0.id.hasPrefix("fish-") })
    }

    func testMergedBaseGameAndSharksAndReefsSourceIdsAreUnique() throws {
        let resourceNames = [
            "base_main_fish_cards",
            "base_starter_fish_cards",
            "sharks_reefs_main_fish_cards",
            "sharks_reefs_starter_fish_cards"
        ]
        let allSourceIds = try resourceNames.flatMap { resourceName in
            try sourceIds(in: resourceName)
        }

        XCTAssertEqual(allSourceIds.count, 215)
        XCTAssertEqual(Set(allSourceIds).count, allSourceIds.count)
    }

    func testBaseGameCardCatalogDoesNotLoadSharksAndReefsCards() throws {
        let catalog = try BaseGameCardCatalog()
        let allCards = catalog.fishCards + catalog.starterFishCards

        XCTAssertFalse(allCards.contains { $0.id.hasPrefix("sr.") })
        XCTAssertFalse(allCards.contains { $0.id.contains("sharks_reefs") })
    }

    func testBaseGameCardCatalogLoadsGreatWhiteSharkFields() throws {
        let catalog = try BaseGameCardCatalog()
        let greatWhiteShark = try XCTUnwrap(
            catalog.fishCards.first { $0.name == "Great White Shark" }
        )

        XCTAssertEqual(greatWhiteShark.name, "Great White Shark")
        XCTAssertEqual(greatWhiteShark.scientificName, "Carcharodon carcharias")
        XCTAssertEqual(greatWhiteShark.lengthCm, 600)
        XCTAssertEqual(greatWhiteShark.printedPoints, 10)
        XCTAssertTrue(greatWhiteShark.costs.contains(.resource(kind: .young, count: 2)))
        XCTAssertTrue(greatWhiteShark.costs.contains(.coverShorterFish(count: 1)))
        XCTAssertEqual(
            greatWhiteShark.tags
                .filter { $0.kind == "predator" }
                .reduce(0) { $0 + $1.count },
            2
        )
        XCTAssertFalse(greatWhiteShark.abilityIds.isEmpty)
        XCTAssertTrue(greatWhiteShark.abilityIds.allSatisfy { $0.hasPrefix("unsupported.") })
    }

    func testBaseGameCardCatalogLoadsStarterFishFields() throws {
        let catalog = try BaseGameCardCatalog()
        let mandarinfish = try XCTUnwrap(
            catalog.starterFishCards.first { $0.name == "Mandarinfish" }
        )

        XCTAssertEqual(mandarinfish.id, "base.starter.131")
        XCTAssertEqual(mandarinfish.scientificName, "Synchiropus splendidus")
        XCTAssertEqual(mandarinfish.lengthCm, 7)
        XCTAssertEqual(mandarinfish.printedPoints, 1)
        XCTAssertEqual(mandarinfish.allowedZones, [.sunlit])
        XCTAssertTrue(mandarinfish.costs.contains(.discardCards(count: 1)))
        XCTAssertTrue(mandarinfish.abilityIds.allSatisfy { $0.hasPrefix("unsupported.") })
    }

    func testBaseGameRuntimeCardJSONDoesNotContainRemoteURLs() throws {
        let resourceTexts = try [
            "base_main_fish_cards",
            "base_starter_fish_cards"
        ].map { resourceName in
            try String(contentsOf: try bundledCardResourceURL(named: resourceName), encoding: .utf8)
        }
        let combined = resourceTexts.joined(separator: "\n")

        XCTAssertFalse(combined.contains("http://"))
        XCTAssertFalse(combined.contains("https://"))
        XCTAssertFalse(combined.contains("navarog.github.io"))
        XCTAssertFalse(combined.contains("finsearch"))
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

    private func bundledCardResourceURL(named resourceName: String) throws -> URL {
        let bundle = Bundle(for: Self.self)
        let candidates = [
            Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources/Cards"),
            Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Cards"),
            Bundle.main.url(forResource: resourceName, withExtension: "json"),
            bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources/Cards"),
            bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Cards"),
            bundle.url(forResource: resourceName, withExtension: "json")
        ]
        return try XCTUnwrap(candidates.compactMap { $0 }.first)
    }

    private func sourceIds(in resourceName: String) throws -> [Int] {
        struct SourceIdDTO: Decodable {
            var sourceId: Int
        }

        let data = try Data(contentsOf: try bundledCardResourceURL(named: resourceName))
        return try JSONDecoder().decode([SourceIdDTO].self, from: data).map(\.sourceId)
    }
}

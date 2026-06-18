import XCTest
@testable import Finspan

final class SampleCatalogRemovalTests: XCTestCase {
    func testNormalRoomSetupOnlyOffersReviewedBaseGameCatalog() {
        XCTAssertEqual(GameDataMode.runtimeCases, [.baseGame])
        XCTAssertEqual(GameDataController().mode, .baseGame)
    }

    func testSampleCatalogRemainsAvailableAsExplicitFixture() throws {
        let catalog = try CardCatalogFactory().makeCatalog(for: .sample)

        XCTAssertFalse(catalog.fishCards.isEmpty)
    }
}

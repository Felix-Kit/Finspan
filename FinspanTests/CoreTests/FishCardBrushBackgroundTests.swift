import XCTest
@testable import Finspan

final class FishCardBrushBackgroundTests: XCTestCase {
    func testIfActivatedBrushUsesLiveCoverTopLeadingMode() throws {
        let banggai = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "base.main.014"))
        let brush = CardAbilityBrushMetrics.live

        XCTAssertEqual(banggai.brushAssetNames, ["IfActivated"])
        XCTAssertEqual(banggai.brushBackgroundSize, "cover")
        XCTAssertEqual(brush.assetContentMode, "coverTopLeading")
        XCTAssertEqual(brush.backgroundPosition, banggai.brushBackgroundPosition)
        XCTAssertEqual(brush.backgroundRepeat, banggai.brushBackgroundRepeat)
    }

    func testAlsoIfBrushUsesSameOrientationAndGap() throws {
        let atlanticBarracudina = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "sr.starter.212"))

        XCTAssertEqual(atlanticBarracudina.brushAssetNames, ["IfActivated"])
        XCTAssertEqual(try XCTUnwrap(atlanticBarracudina.alsoIfGapCqw), CardAbilityPanelMetrics.live.blockGapCqw, accuracy: 0.001)
        XCTAssertEqual(CardAbilityBrushMetrics.live.orientation, .horizontalRightToLeft)
        XCTAssertFalse(CardAbilityBrushMetrics.live.usesRotation)
        XCTAssertFalse(CardAbilityBrushMetrics.live.usesPureColorFallback)
    }
}

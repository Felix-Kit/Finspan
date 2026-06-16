import XCTest
@testable import Finspan

final class FishCardLiveMeasurementTests: XCTestCase {
    func testLiveMeasurementJsonContainsRepresentativeCards() throws {
        let report = try liveMeasurementReport()
        let cards = try XCTUnwrap(report["cards"] as? [[String: Any]])
        let cardIds = Set(cards.compactMap { $0["cardId"] as? String })

        XCTAssertTrue(cardIds.contains("base.main.014"))
        XCTAssertTrue(cardIds.contains("base.main.057"))
        XCTAssertTrue(cardIds.contains("base.main.016"))
        XCTAssertTrue(cardIds.contains("sr.starter.212"))
        XCTAssertTrue(cardIds.contains("sr.main.161"))
    }

    func testBanggaiCardinalfishLivePanelFrameIsMeasuredFromDom() throws {
        let summary = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "base.main.014"))

        XCTAssertEqual(summary.liveAbilityFrame.left, 71.883, accuracy: 0.001)
        XCTAssertEqual(summary.liveAbilityFrame.top, 0.266, accuracy: 0.001)
        XCTAssertEqual(summary.liveAbilityFrame.width, 27.851, accuracy: 0.001)
        XCTAssertEqual(summary.liveAbilityFrame.height, 65.218, accuracy: 0.001)
        XCTAssertEqual(summary.liveAbilityFrame.rightGap, 0.266, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.swiftBeforeAbilityFrame).left, 72, accuracy: 0.001)
        XCTAssertEqual(summary.swiftAbilityFrame.left, CardAbilityPanelMetrics.live.leftCqw, accuracy: 0.001)
    }

    func testBrushBackgroundModeUsesLiveDomComputedStyle() throws {
        let summary = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "base.main.014"))
        let brush = CardAbilityBrushMetrics.live

        XCTAssertEqual(summary.brushAssetNames, ["IfActivated"])
        XCTAssertEqual(summary.brushBackgroundSize, "cover")
        XCTAssertEqual(summary.brushBackgroundPosition, "0% 0%")
        XCTAssertEqual(summary.brushBackgroundRepeat, "repeat")
        XCTAssertEqual(brush.assetContentMode, "coverTopLeading")
        XCTAssertEqual(brush.backgroundPosition, summary.brushBackgroundPosition)
        XCTAssertEqual(brush.backgroundRepeat, summary.brushBackgroundRepeat)
        XCTAssertFalse(brush.usesRotation)
        XCTAssertFalse(brush.usesPureColorFallback)
    }

    func testAtlanticBarracudinaAlsoIfGapUsesLiveMeasurement() throws {
        let summary = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "sr.starter.212"))

        XCTAssertEqual(try XCTUnwrap(summary.alsoIfGapCqw), CardAbilityPanelMetrics.live.blockGapCqw, accuracy: 0.001)
    }

    func testArrowFlowOverlapUsesLiveMeasurement() throws {
        let greatWhite = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "base.main.057"))
        let beardedSeadevil = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "base.main.016"))

        XCTAssertEqual(try XCTUnwrap(greatWhite.arrowTopOverlapCqw), 3.98, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(greatWhite.arrowBottomOverlapCqw), 3.98, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(beardedSeadevil.arrowTopOverlapCqw), 3.98, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(beardedSeadevil.arrowBottomOverlapCqw), 3.98, accuracy: 0.001)
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.arrowNegativeMarginCqw, -5)
    }

    private func liveMeasurementReport() throws -> [String: Any] {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        url.appendPathComponent("tools/generated/card_rendering/live_measurements.json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

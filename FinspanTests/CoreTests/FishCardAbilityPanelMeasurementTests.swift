import XCTest
@testable import Finspan

final class FishCardAbilityPanelMeasurementTests: XCTestCase {
    func testSwiftPanelMetricsMatchLiveMeasuredBanggaiCardinalfishFrame() throws {
        let summary = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "base.main.014"))
        let metrics = CardAbilityPanelMetrics.live

        XCTAssertEqual(metrics.leftCqw, summary.liveAbilityFrame.left, accuracy: 0.001)
        XCTAssertEqual(metrics.topPaddingCqw, summary.liveAbilityFrame.top, accuracy: 0.001)
        XCTAssertEqual(metrics.widthCqw, summary.liveAbilityFrame.width, accuracy: 0.001)
        XCTAssertEqual(metrics.heightCqw, summary.liveAbilityFrame.height, accuracy: 0.001)
        XCTAssertEqual(metrics.trailingPaddingCqw, summary.liveAbilityFrame.rightGap, accuracy: 0.001)
    }

    func testSwiftMetricsRecordPreviousFrameDelta() throws {
        let summary = try XCTUnwrap(CardLiveMeasurementCatalog.summary(for: "base.main.014"))
        let before = try XCTUnwrap(summary.swiftBeforeAbilityFrame)

        XCTAssertGreaterThan(before.top - summary.liveAbilityFrame.top, 0.7)
        XCTAssertEqual(before.width, 28, accuracy: 0.001)
        XCTAssertEqual(summary.deltaFrame.width, 0, accuracy: 0.001)
        XCTAssertEqual(summary.deltaFrame.left, 0, accuracy: 0.001)
    }
}

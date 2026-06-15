import XCTest
@testable import Finspan

final class StarterCardCornerTests: XCTestCase {
    @MainActor
    func testBaseStarterCardHasCornerDecorations() throws {
        let cardFace = try cardFace(for: "base.starter.126")

        XCTAssertTrue(cardFace.hasStarterCornerDecorations)
        XCTAssertNil(cardFace.expansionBadgeIcon)
    }

    @MainActor
    func testMainCardDoesNotHaveStarterCornerDecorations() throws {
        let cardFace = try cardFace(for: "base.main.057")

        XCTAssertFalse(cardFace.hasStarterCornerDecorations)
    }

    @MainActor
    func testSharksAndReefsStarterCardHasCornersAndExpansionBadge() throws {
        let cardFace = try cardFace(for: "sr.starter.212")

        XCTAssertTrue(cardFace.hasStarterCornerDecorations)
        XCTAssertEqual(cardFace.expansionBadgeIcon?.assetName, "SRLogo")
    }

    @MainActor
    func testDebugSummaryReportsStarterCornerState() throws {
        let starter = try cardFace(for: "base.starter.126")
        let main = try cardFace(for: "base.main.057")

        XCTAssertTrue(CardIconRenderabilityAnalyzer.debugSummary(for: starter).hasStarterCorner)
        XCTAssertFalse(CardIconRenderabilityAnalyzer.debugSummary(for: main).hasStarterCorner)
    }

    func testLiveStarterIconAssetRemainsRenderableForSearchMarker() {
        let icon = CardSymbolAssetResolver.shared.icon(
            named: "StarterIcon",
            fallbackText: "起始",
            accessibilityText: "起始牌"
        )

        XCTAssertNotNil(icon.asset)
        XCTAssertTrue(CardIconRenderabilityAnalyzer.analyze(icon).isRenderable)
    }

    @MainActor
    private func cardFace(for cardId: CardID) throws -> FishCardFaceViewState {
        let viewModel = CardLibraryViewModel()
        viewModel.displayMode = .all
        return try XCTUnwrap(
            viewModel.viewState.cards.map(\.cardFace).first { $0.cardId == cardId },
            "Expected \(cardId) in card QA library."
        )
    }
}

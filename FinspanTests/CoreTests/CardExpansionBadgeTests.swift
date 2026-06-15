import XCTest
@testable import Finspan

final class CardExpansionBadgeTests: XCTestCase {
    @MainActor
    func testSharksAndReefsCardHasSRLogoBadge() throws {
        let cardFace = try cardFace(for: "sr.main.161")
        let badge = try XCTUnwrap(cardFace.expansionBadgeIcon)

        XCTAssertEqual(badge.assetName, "SRLogo")
        XCTAssertNotNil(badge.asset)
        XCTAssertNil(badge.missingAsset)
        XCTAssertEqual(CardIconRenderabilityAnalyzer.analyze(badge).isRenderable, true)
    }

    @MainActor
    func testBaseCardDoesNotHaveSRLogoBadge() throws {
        let cardFace = try cardFace(for: "base.main.057")

        XCTAssertNil(cardFace.expansionBadgeIcon)
    }

    @MainActor
    func testDebugSummaryReportsExpansionLogoState() throws {
        let srCard = try cardFace(for: "sr.main.161")
        let baseCard = try cardFace(for: "base.main.057")

        XCTAssertTrue(CardIconRenderabilityAnalyzer.debugSummary(for: srCard).hasExpansionLogo)
        XCTAssertFalse(CardIconRenderabilityAnalyzer.debugSummary(for: baseCard).hasExpansionLogo)
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

import XCTest
@testable import Finspan

final class FishCardAbilityPixelAlignmentTests: XCTestCase {
    @MainActor
    func testLiveAbilityPanelMetricsMapToFinsearchCss() throws {
        let metrics = CardAbilityPanelMetrics.live

        XCTAssertEqual(metrics.widthCqw, 27.851, accuracy: 0.001)
        XCTAssertEqual(metrics.rightGapCqw, 0.266, accuracy: 0.001)
        XCTAssertEqual(metrics.leftCqw, 71.883, accuracy: 0.001)
        XCTAssertEqual(metrics.trailingPaddingCqw, 0.266, accuracy: 0.001)
        XCTAssertEqual(metrics.topPaddingCqw, 0.266, accuracy: 0.001)
        XCTAssertEqual(metrics.blockGapCqw, 1.986, accuracy: 0.001)
        XCTAssertEqual(metrics.heightCqw, 65.218, accuracy: 0.001)
    }

    @MainActor
    func testBrushMetricsPreserveLiveHorizontalStripOrientation() throws {
        let brush = CardAbilityBrushMetrics.live

        XCTAssertEqual(brush.orientation, .horizontalRightToLeft)
        XCTAssertEqual(brush.assetContentMode, "coverTopLeading")
        XCTAssertEqual(brush.backgroundPosition, "0% 0%")
        XCTAssertEqual(brush.backgroundRepeat, "repeat")
        XCTAssertFalse(brush.usesRotation)
        XCTAssertFalse(brush.usesPureColorFallback)
        XCTAssertEqual(brush.capInsetCqw, 0)
        XCTAssertEqual(brush.cornerRadiusCqw, 0)
    }

    @MainActor
    func testAbilityBlockHeightsUseLiveMeasuredDomValues() throws {
        let standard = CardAbilityBlockMetrics.live(for: .standard, panelStyle: .tanBrush)
        let squished = CardAbilityBlockMetrics.live(for: .squished, panelStyle: .tanBrush)
        let alsoIf = CardAbilityBlockMetrics.live(for: .alsoIf, panelStyle: .tanBrush)

        XCTAssertEqual(standard.minTotalHeightCqw, 27.842, accuracy: 0.001)
        XCTAssertEqual(squished.minTotalHeightCqw, 17.993, accuracy: 0.001)
        XCTAssertEqual(alsoIf.minTotalHeightCqw, 35.286, accuracy: 0.001)
    }

    @MainActor
    func testBanggaiCardinalfishIfActivatedUsesLivePanelAndBrushMetrics() throws {
        let cardFace = try cardFace(for: "base.main.014")
        let block = try XCTUnwrap(cardFace.abilityPresentation.blocks.first)

        XCTAssertEqual(cardFace.abilityTriggerText, CardFaceTriggerCopy.ifActivated)
        XCTAssertEqual(block.backgroundAssetPrefix, "IfActivated")
        XCTAssertNotNil(block.backgroundAsset)
        XCTAssertEqual(CardAbilityPanelMetrics.live.leftCqw, 71.883, accuracy: 0.001)
        XCTAssertEqual(CardAbilityPanelMetrics.live.widthCqw, 27.851, accuracy: 0.001)
        XCTAssertEqual(CardAbilityBrushMetrics.live.orientation, .horizontalRightToLeft)
    }

    @MainActor
    func testGreatWhiteSharkArrowFlowUsesLiveOverlapMetrics() throws {
        let cardFace = try cardFace(for: "base.main.057")
        let arrowFlowGroup = try XCTUnwrap(cardFace.abilityPresentation.firstIconGroup(layout: .arrowFlow))

        XCTAssertEqual(arrowFlowGroup.icons.map(\.icon.assetName), ["FishEgg", "ArrowDown", "Predator"])
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.defaultIconHeightCqw, 9)
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.arrowHeightCqw, 15)
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.iconGroupGapCqw, 1)
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.arrowNegativeMarginCqw, -5)
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.effectiveStackSpacingCqw, -4)
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.arrowVerticalOffsetCqw, 0)
    }

    @MainActor
    func testAllPlayersOverlayUsesAbilityContainerBottomEdge() {
        let overlay = CardAbilityContainerOverlayMetrics.live

        XCTAssertEqual(overlay.allPlayersHeightCqw, 9)
        XCTAssertEqual(overlay.allPlayersBottomCqw, 4)
        XCTAssertEqual(
            overlay.allPlayersTopCqw(),
            CardAbilityPanelMetrics.live.heightCqw - overlay.allPlayersBottomCqw - overlay.allPlayersHeightCqw,
            accuracy: 0.001
        )
    }

    @MainActor
    func testAbilityIconMetricsMatchLiveCssOverrides() {
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "DrawCard").heightCqw, 8)
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "Discard").heightCqw, 8)
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "ConsumeFish1").heightCqw, 8)
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "SchoolFeederMove").heightCqw, 12.5)
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "UnSchoolFish").heightCqw, 16)
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "AnyCoral").heightCqw, 12)
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "YoungFish").heightCqw, 6.5)
        XCTAssertEqual(CardAbilityIconLayoutMetrics.live(for: "AllPlayers").heightCqw, 9)
    }

    @MainActor
    func testHorizontalAbilityRowsUseLiveHeightAndWidthCaps() {
        let draw = CardAbilityIconLayoutMetrics.live(for: "DrawCard", isHorizontalRow: true)
        let school = CardAbilityIconLayoutMetrics.live(for: "SchoolFish", isHorizontalRow: true)

        XCTAssertEqual(draw.heightCqw, 7)
        XCTAssertEqual(draw.maxWidthCqw, 8)
        XCTAssertEqual(school.heightCqw, 9)
        XCTAssertNil(school.maxWidthCqw)
    }

    @MainActor
    func testBeardedSeadevilUsesSameArrowFlowMetrics() throws {
        let cardFace = try cardFace(for: "base.main.016")
        let arrowFlowGroup = try XCTUnwrap(cardFace.abilityPresentation.firstIconGroup(layout: .arrowFlow))

        XCTAssertEqual(arrowFlowGroup.icons.map(\.icon.assetName), ["FishEgg", "ArrowDown", "FishLengthSmall"])
        XCTAssertTrue(arrowFlowGroup.icons.allSatisfy { $0.placement == .arrowFlow })
        XCTAssertEqual(CardAbilityArrowFlowMetrics.live.effectiveStackSpacingCqw, -4)
    }

    @MainActor
    func testAtlanticBarracudinaAlsoIfGapAndBrushDirectionArePreserved() throws {
        let cardFace = try cardFace(for: "sr.starter.212")
        let presentation = cardFace.abilityPresentation

        XCTAssertEqual(presentation.blocks.map(\.layout), [.squished, .alsoIf])
        XCTAssertEqual(presentation.blockGapCqw, CardAbilityPanelMetrics.live.blockGapCqw)
        XCTAssertTrue(presentation.blocks.allSatisfy(\.hasBrushBackground))
        XCTAssertEqual(CardAbilityBrushMetrics.live.orientation, .horizontalRightToLeft)

        let alsoIfBlock = try XCTUnwrap(presentation.blocks.first { $0.kind == .alsoIf })
        let coralGroup = try XCTUnwrap(alsoIfBlock.elements.firstIconGroup(layout: .coralHorizontal))
        XCTAssertEqual(coralGroup.icons.map(\.icon.assetName), ["GreenCoral", "GreenCoral", "GreenCoral"])
    }

    @MainActor
    func testBadgeStarterAndAllPlayersStylesArePreserved() throws {
        let greatBarracuda = try cardFace(for: "sr.main.161")
        let atlanticBarracudina = try cardFace(for: "sr.starter.212")
        let greatWhiteShark = try cardFace(for: "base.main.057")

        XCTAssertEqual(greatBarracuda.expansionBadgeIcon?.assetName, "SRLogo")
        XCTAssertTrue(atlanticBarracudina.hasStarterCornerDecorations)
        XCTAssertTrue(greatWhiteShark.abilityPresentation.hasAllPlayersShadow)
    }

    @MainActor
    func testDebugSummaryIncludesPixelAlignmentMetrics() throws {
        let cardFace = try cardFace(for: "base.main.057")
        let summary = CardIconRenderabilityAnalyzer.debugSummary(for: cardFace)

        XCTAssertEqual(summary.brushOrientation, CardAbilityBrushOrientation.horizontalRightToLeft.rawValue)
        XCTAssertEqual(summary.brushContentMode, "coverTopLeading")
        XCTAssertEqual(summary.brushBackgroundPosition, "0% 0%")
        XCTAssertEqual(summary.brushBackgroundRepeat, "repeat")
        XCTAssertEqual(summary.abilityPanelFrame, CardAbilityPanelMetrics.live.frameSummary)
        XCTAssertEqual(summary.arrowFlowMetrics, CardAbilityArrowFlowMetrics.live.summary)
        XCTAssertEqual(summary.alsoIfGapCqw, CardAbilityPanelMetrics.live.blockGapCqw)
    }

    @MainActor
    func testDebugSummaryIncludesLiveMeasurementDeltaWhenJsonExists() throws {
        let cardFace = try cardFace(for: "base.main.014")
        let summary = CardIconRenderabilityAnalyzer.debugSummary(for: cardFace)

        XCTAssertEqual(summary.liveMeasuredAbilityFrame, "x:71.883 y:0.266 w:27.851 h:65.218 r:0.266")
        XCTAssertEqual(summary.swiftAbilityFrameDelta, "x:0.0 y:0.0 w:0.0 h:0.0 r:0.0")
        XCTAssertEqual(summary.swiftBeforeAbilityFrame, "x:72.0 y:1.0 w:28.0 h:64.574 r:0.0")
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

private extension CardAbilityPresentation {
    func firstIconGroup(layout: CardAbilityIconGroupLayout) -> CardAbilityIconGroup? {
        blocks.flatMap(\.elements).firstIconGroup(layout: layout)
    }
}

private extension Array where Element == CardAbilityElement {
    func firstIconGroup(layout: CardAbilityIconGroupLayout) -> CardAbilityIconGroup? {
        for element in self {
            switch element {
            case let .iconGroup(group) where group.layout == layout:
                return group
            case let .horizontalRow(elements):
                if let group = elements.firstIconGroup(layout: layout) {
                    return group
                }
            case .text, .icon, .points, .iconGroup:
                continue
            }
        }
        return nil
    }
}

import XCTest
@testable import Finspan

final class FishCardAbilityPixelAlignmentTests: XCTestCase {
    @MainActor
    func testLiveAbilityPanelMetricsMapToFinsearchCss() throws {
        let metrics = CardAbilityPanelMetrics.live

        XCTAssertEqual(metrics.widthCqw, 28)
        XCTAssertEqual(metrics.liveRightOffsetCqw, 28)
        XCTAssertEqual(metrics.leftCqw, 72)
        XCTAssertEqual(metrics.trailingPaddingCqw, 0)
        XCTAssertEqual(metrics.topPaddingCqw, 1)
        XCTAssertEqual(metrics.blockGapCqw, 2)
        XCTAssertEqual(metrics.heightReductionCqw, 1)
    }

    @MainActor
    func testBrushMetricsPreserveLiveHorizontalStripOrientation() throws {
        let brush = CardAbilityBrushMetrics.live

        XCTAssertEqual(brush.orientation, .horizontalRightToLeft)
        XCTAssertEqual(brush.assetContentMode, "stretch")
        XCTAssertFalse(brush.usesRotation)
        XCTAssertFalse(brush.usesPureColorFallback)
        XCTAssertEqual(brush.capInsetCqw, 2)
    }

    @MainActor
    func testBanggaiCardinalfishIfActivatedUsesLivePanelAndBrushMetrics() throws {
        let cardFace = try cardFace(for: "base.main.014")
        let block = try XCTUnwrap(cardFace.abilityPresentation.blocks.first)

        XCTAssertEqual(cardFace.abilityTriggerText, CardFaceTriggerCopy.ifActivated)
        XCTAssertEqual(block.backgroundAssetPrefix, "IfActivated")
        XCTAssertNotNil(block.backgroundAsset)
        XCTAssertEqual(CardAbilityPanelMetrics.live.leftCqw, 72)
        XCTAssertEqual(CardAbilityPanelMetrics.live.widthCqw, 28)
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
        XCTAssertEqual(summary.brushContentMode, "stretch")
        XCTAssertEqual(summary.abilityPanelFrame, CardAbilityPanelMetrics.live.frameSummary)
        XCTAssertEqual(summary.arrowFlowMetrics, CardAbilityArrowFlowMetrics.live.summary)
        XCTAssertEqual(summary.alsoIfGapCqw, CardAbilityPanelMetrics.live.blockGapCqw)
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

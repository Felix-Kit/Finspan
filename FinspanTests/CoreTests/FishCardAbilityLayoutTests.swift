import XCTest
@testable import Finspan

final class FishCardAbilityLayoutTests: XCTestCase {
    @MainActor
    func testGreatWhiteSharkAbilityPresentationUsesArrowFlowInsteadOfFlatRow() throws {
        let cardFace = try cardFace(for: "base.main.057")
        let presentation = cardFace.abilityPresentation

        XCTAssertFalse(presentation.isFlatFallback)
        XCTAssertEqual(presentation.blocks.count, 1)
        XCTAssertTrue(presentation.hasAllPlayersShadow)

        let arrowFlowGroup = try XCTUnwrap(presentation.firstIconGroup(layout: .arrowFlow))
        XCTAssertEqual(arrowFlowGroup.icons.map(\.icon.assetName), ["FishEgg", "ArrowDown", "Predator"])
        XCTAssertTrue(arrowFlowGroup.icons.allSatisfy { $0.placement == .arrowFlow })
        XCTAssertNotNil(presentation.firstIcon(named: "AllPlayers", placement: .allPlayersBottom))
        XCTAssertEqual(presentation.firstIcon(named: "AllPlayers", placement: .allPlayersBottom)?.style, .allPlayersShadow)
    }

    @MainActor
    func testParaliparisAllPlayersIconIsAContainerOverlayNotBrushContent() throws {
        let cardFace = try cardFace(for: "base.main.087")
        let presentation = cardFace.abilityPresentation
        let overlay = try XCTUnwrap(presentation.bottomOverlayIcons.first)

        XCTAssertEqual(cardFace.displayName, "Paraliparis")
        XCTAssertEqual(cardFace.abilityTriggerText, CardFaceTriggerCopy.ifActivated)
        XCTAssertEqual(presentation.bottomOverlayIcons.count, 1)
        XCTAssertEqual(overlay.icon.assetName, "AllPlayers")
        XCTAssertEqual(overlay.placement, .allPlayersBottom)
        XCTAssertEqual(overlay.style, .allPlayersShadow)
        XCTAssertTrue(presentation.blocks.allSatisfy { $0.brushContentElements.allPlayersBottomIcons.isEmpty })
    }

    @MainActor
    func testAllAllPlayersCardsUseContainerBottomOverlay() {
        let cards = allCardFaces()
        let allPlayersCards = cards.filter { $0.abilityText.contains("[AllPlayers]") }

        XCTAssertEqual(cards.count, 215)
        XCTAssertEqual(allPlayersCards.count, 34)
        for cardFace in allPlayersCards {
            XCTAssertFalse(
                cardFace.abilityPresentation.bottomOverlayIcons.isEmpty,
                "Expected container overlay for \(cardFace.cardId ?? "unknown")."
            )
            XCTAssertTrue(
                cardFace.abilityPresentation.blocks.allSatisfy { $0.brushContentElements.allPlayersBottomIcons.isEmpty },
                "AllPlayers must not expand the brush for \(cardFace.cardId ?? "unknown")."
            )
        }
    }

    @MainActor
    func testAllCardAbilityPresentationsResolveWithoutFlatFallbacksOrMissingBrushes() {
        let cards = allCardFaces()
        var failures: [String] = []

        for cardFace in cards {
            let presentation = cardFace.abilityPresentation
            if presentation.isFlatFallback || presentation.blocks.isEmpty {
                failures.append("\(cardFace.cardId ?? "unknown"):missing structured presentation")
            }
            if cardFace.abilityPanelStyle != .none,
               presentation.blocks.contains(where: { !$0.hasBrushBackground }) {
                failures.append("\(cardFace.cardId ?? "unknown"):missing trigger brush")
            }
        }

        XCTAssertEqual(cards.count, 215)
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: ", "))
    }

    @MainActor
    func testGreatWhiteSharkLayoutIsGeneratedFromRawAbilityTextNotCardId() throws {
        let cardFace = try cardFace(for: "base.main.057")
        let builder = CardAbilityPresentationBuilder()
        let rebuilt = builder.build(
            rawAbilityText: "(all players) [FishEgg][ArrowDown][Predator] on each [AllPlayers]",
            triggerTitle: CardFaceTriggerCopy.whenPlayed,
            triggerStyle: CardTriggerStyleResolver.shared.style(for: CardFaceTriggerCopy.whenPlayed)
        )

        XCTAssertEqual(cardFace.abilityPresentation.tokenPlacementSummary, rebuilt.tokenPlacementSummary)
    }

    @MainActor
    func testGreatNorthernTilefishIfActivatedBlockUsesBrushAsset() throws {
        let cardFace = try cardFace(for: "base.main.056")
        let block = try XCTUnwrap(cardFace.abilityPresentation.blocks.first)

        XCTAssertEqual(cardFace.abilityTriggerText, CardFaceTriggerCopy.ifActivated)
        XCTAssertEqual(block.kind, .main)
        XCTAssertEqual(block.backgroundAssetPrefix, "IfActivated")
        XCTAssertNotNil(block.backgroundAsset)
        XCTAssertTrue(block.hasBrushBackground)
    }

    @MainActor
    func testAtlanticBarracudinaAlsoIfUsesSeparateBrushBlockAndCoralGroup() throws {
        let cardFace = try cardFace(for: "sr.starter.212")
        let presentation = cardFace.abilityPresentation

        XCTAssertEqual(presentation.blocks.count, 2)
        XCTAssertEqual(presentation.alsoIfBlockCount, 1)
        XCTAssertEqual(presentation.blockGapCqw, CardAbilityPanelMetrics.live.blockGapCqw, accuracy: 0.001)
        XCTAssertEqual(presentation.blocks.map(\.layout), [.squished, .alsoIf])
        XCTAssertTrue(presentation.blocks.allSatisfy(\.hasBrushBackground))

        let alsoIfBlock = try XCTUnwrap(presentation.blocks.first { $0.kind == .alsoIf })
        let coralGroup = try XCTUnwrap(alsoIfBlock.elements.firstIconGroup(layout: .coralHorizontal))
        XCTAssertEqual(coralGroup.icons.map(\.icon.assetName), ["GreenCoral", "GreenCoral", "GreenCoral"])
        XCTAssertEqual(coralGroup.cssClassSummary, "GreenCoral-3")
    }

    @MainActor
    func testTriggerBrushBackgroundsUseAssetsNotPureColorFallbacks() throws {
        let ifActivated = try cardFace(for: "base.main.056")
        let gameEnd = try cardFace(for: "base.main.001")

        XCTAssertEqual(ifActivated.abilityPresentation.blocks.first?.backgroundAssetPrefix, "IfActivated")
        XCTAssertNotNil(ifActivated.abilityPresentation.blocks.first?.backgroundAsset)
        XCTAssertEqual(gameEnd.abilityPresentation.blocks.first?.backgroundAssetPrefix, "GameEnd")
        XCTAssertNotNil(gameEnd.abilityPresentation.blocks.first?.backgroundAsset)
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

    @MainActor
    private func allCardFaces() -> [FishCardFaceViewState] {
        let viewModel = CardLibraryViewModel()
        viewModel.displayMode = .all
        return viewModel.viewState.cards.map(\.cardFace)
    }
}

private extension CardAbilityPresentation {
    func firstIconGroup(layout: CardAbilityIconGroupLayout) -> CardAbilityIconGroup? {
        blocks.flatMap(\.elements).firstIconGroup(layout: layout)
    }

    func firstIcon(named assetName: String, placement: CardAbilityIconPlacement) -> CardAbilityIcon? {
        blocks.flatMap(\.elements).firstIcon(named: assetName, placement: placement)
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

    func firstIcon(named assetName: String, placement: CardAbilityIconPlacement) -> CardAbilityIcon? {
        for element in self {
            switch element {
            case let .icon(icon) where icon.icon.assetName == assetName && icon.placement == placement:
                return icon
            case let .iconGroup(group):
                if let icon = group.icons.first(where: { $0.icon.assetName == assetName && $0.placement == placement }) {
                    return icon
                }
            case let .horizontalRow(elements):
                if let icon = elements.firstIcon(named: assetName, placement: placement) {
                    return icon
                }
            case .text, .icon, .points:
                continue
            }
        }
        return nil
    }
}

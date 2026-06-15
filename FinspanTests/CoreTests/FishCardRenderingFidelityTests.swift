import XCTest
@testable import Finspan

final class FishCardRenderingFidelityTests: XCTestCase {
    func testGreatWhiteSharkExistsInBaseGameJSON() throws {
        let card = try greatWhiteShark()

        XCTAssertEqual(card.id, "base.main.057")
        XCTAssertEqual(card.name, "Great White Shark")
        XCTAssertEqual(card.scientificName, "Carcharodon carcharias")
        XCTAssertEqual(card.lengthCm, 600)
        XCTAssertEqual(card.printedPoints, 10)
        XCTAssertNil(card.visualAssetName)
        XCTAssertEqual(FishImageAssetResolver.shared.sourceId(fromCardId: card.id), 57)
    }

    func testGreatWhiteSharkFishImageResolvesToWebP() throws {
        let card = try greatWhiteShark()
        let lookup = FishImageAssetResolver.shared.image(
            forCardId: card.id,
            visualAssetName: card.visualAssetName
        )

        XCTAssertTrue(lookup.isResolved)
        XCTAssertEqual(lookup.asset?.fileExtension.lowercased(), "webp")
        XCTAssertTrue(lookup.asset?.fileName.hasPrefix("57.") == true)
    }

    func testGreatWhiteSharkAbilityTokensResolveToAssets() throws {
        let card = try greatWhiteShark()
        let segments = FishCardAbilityTokenParser.parse(card.cardFaceRawAbilityText ?? "")
        let icons = segments.compactMap { segment -> FishCardFaceIconViewState? in
            if case let .icon(icon) = segment {
                return icon
            }
            return nil
        }

        for assetName in ["ArrowDown", "FishEgg", "Predator", "AllPlayers"] {
            let icon = try XCTUnwrap(icons.first { $0.assetName == assetName })
            XCTAssertNotNil(icon.asset, "Expected \(assetName) to resolve to a card icon asset.")
            XCTAssertNil(icon.missingAsset)
        }
    }

    @MainActor
    func testGreatWhiteSharkCardFaceUsesEnglishSourceAndResolvedTokens() throws {
        let cardFace = try cardFace(for: "base.main.057")

        XCTAssertEqual(cardFace.displayName.uppercased(), "GREAT WHITE SHARK")
        XCTAssertEqual(cardFace.scientificName, "Carcharodon carcharias")
        XCTAssertEqual(cardFace.abilityTriggerText, CardFaceTriggerCopy.whenPlayed)
        XCTAssertEqual(cardFace.abilityText, "(all players) [FishEgg][ArrowDown][Predator] on each [AllPlayers]")
        XCTAssertFalse(cardFace.abilityText.contains("所有"))

        for assetName in ["FishEgg", "ArrowDown", "Predator", "AllPlayers"] {
            let icon = try XCTUnwrap(cardFace.abilitySegments.icon(named: assetName))
            XCTAssertNotNil(icon.asset)
            XCTAssertNil(icon.missingAsset)
        }
    }

    func testFishLengthIconsResolveToAssets() {
        for assetName in ["FishLengthLarge", "FishLengthMedium", "FishLengthSmall"] {
            let lookup = CardSymbolAssetResolver.shared.lookup(named: assetName)

            XCTAssertTrue(lookup.isResolved, "Expected \(assetName) to resolve.")
            XCTAssertEqual(lookup.asset?.fileExtension.lowercased(), "svg")
        }
    }

    func testLightZoneIconsResolveToAssets() {
        for assetName in ["Sun", "Dusk", "Night", "PlayFishBottomRow"] {
            let lookup = CardSymbolAssetResolver.shared.lookup(named: assetName)

            XCTAssertTrue(lookup.isResolved, "Expected \(assetName) to resolve.")
            XCTAssertEqual(lookup.asset?.fileExtension.lowercased(), "svg")
        }
    }

    func testWaveIconResolvesToLiveAsset() {
        let lookup = CardSymbolAssetResolver.shared.lookup(named: "Wave")

        XCTAssertTrue(lookup.isResolved)
        XCTAssertEqual(lookup.asset?.fileExtension.lowercased(), "svg")
        XCTAssertTrue(lookup.asset?.fileName.hasPrefix("Wave.") == true)
    }

    func testIfActivatedTriggerStyleResolvesStripAssetOrStyle() {
        let style = CardTriggerStyleResolver.shared.style(
            for: CardFaceTriggerCopy.ifActivated
        )

        XCTAssertEqual(style.abilityPanelStyle, .tanBrush)
        XCTAssertEqual(style.stripAssetPrefix, "IfActivated")
        XCTAssertNotNil(style.stripAsset)
    }

    func testGameEndTriggerStyleResolvesStripAssetOrStyle() {
        let style = CardTriggerStyleResolver.shared.style(
            for: CardFaceTriggerCopy.gameEnd
        )

        XCTAssertEqual(style.abilityPanelStyle, .yellowBrush)
        XCTAssertEqual(style.stripAssetPrefix, "GameEnd")
        XCTAssertNotNil(style.stripAsset)
    }

    func testTriggerStripLayoutUsesAbilityPanelWidthNotFullCardWidth() {
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.abilityPanelWidth, CardRenderMetrics.CardFaceLayout.abilityWidth)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.triggerStripWidth, CardRenderMetrics.CardFaceLayout.abilityPanelWidth)
        XCTAssertLessThan(CardRenderMetrics.CardFaceLayout.triggerStripWidth, CardRenderMetrics.CardFaceLayout.fullCardWidth)
    }

    @MainActor
    func testCostAndRequirementIconsArePopulatedForRepresentativeRealCards() throws {
        let cardIds = [
            "base.main.001",
            "base.main.004",
            "base.main.007",
            "base.main.057",
            "base.main.119",
            "sr.main.142",
            "sr.main.144",
            "sr.main.153",
            "sr.main.159",
            "sr.main.204"
        ]

        for cardId in cardIds {
            let cardFace = try cardFace(for: cardId)
            XCTAssertFalse(cardFace.costIcons.isEmpty, "Expected cost/requirement icons for \(cardId).")
        }

        let greatWhiteShark = try cardFace(for: "base.main.057")
        XCTAssertEqual(greatWhiteShark.costIcons.map(\.assetName), ["YoungFish", "YoungFish", "ConsumeFish"])

        let coralRequirementCard = try cardFace(for: "sr.main.142")
        XCTAssertTrue(coralRequirementCard.costIcons.contains { $0.assetName == "AnyCoral" })
        XCTAssertTrue(coralRequirementCard.costIcons.allSatisfy { $0.asset != nil })
    }

    @MainActor
    func testPlayableZoneIconsIncludeLiveBottomRowMapping() throws {
        XCTAssertEqual(try cardFace(for: "base.main.001").zoneIcons.map(\.assetName), ["Sun"])
        XCTAssertEqual(try cardFace(for: "base.main.002").zoneIcons.map(\.assetName), ["Night"])
        XCTAssertEqual(try cardFace(for: "base.main.025").zoneIcons.map(\.assetName), ["Sun", "Dusk", "Night"])
        XCTAssertEqual(try cardFace(for: "base.main.044").zoneIcons.map(\.assetName), ["PlayFishBottomRow"])
        XCTAssertEqual(try cardFace(for: "sr.main.186").zoneIcons.map(\.assetName), ["PlayFishBottomRow"])
    }

    @MainActor
    func testPointsAndLengthIconsUseResolvedAssets() throws {
        let large = try cardFace(for: "base.main.057")
        XCTAssertEqual(large.sizeClassIcon.assetName, "FishLengthLarge")
        XCTAssertNotNil(large.sizeClassIcon.asset)
        XCTAssertEqual(large.pointsIcon.assetName, "Wave")
        XCTAssertNotNil(large.pointsIcon.asset)

        let small = try cardFace(for: "base.main.001")
        XCTAssertEqual(small.sizeClassIcon.assetName, "FishLengthSmall")
        XCTAssertNotNil(small.sizeClassIcon.asset)

        let medium = try cardFace(for: "base.main.002")
        XCTAssertEqual(medium.sizeClassIcon.assetName, "FishLengthMedium")
        XCTAssertNotNil(medium.sizeClassIcon.asset)
    }

    @MainActor
    func testDebugCardLibrarySearchFindsRepresentativeCards() throws {
        let viewModel = CardLibraryViewModel()
        viewModel.displayMode = .all

        viewModel.qaSearchText = "Great White Shark"
        XCTAssertEqual(viewModel.viewState.cards.map(\.cardId), ["base.main.057"])

        viewModel.qaSearchText = "base.main.057"
        XCTAssertEqual(viewModel.viewState.cards.map(\.cardId), ["base.main.057"])

        viewModel.qaSearchText = "57"
        XCTAssertTrue(viewModel.viewState.cards.contains { $0.cardId == "base.main.057" })

        viewModel.qaSearchText = "Game End"
        XCTAssertTrue(viewModel.viewState.cards.contains { $0.cardFace.abilityTriggerText == CardFaceTriggerCopy.gameEnd })

        viewModel.qaSearchText = "AnyCoral"
        XCTAssertTrue(viewModel.viewState.cards.contains { $0.cardFace.abilitySegments.icon(named: "AnyCoral") != nil })
    }

    @MainActor
    func testAllRealCardsReportNoSilentMissingAssetsForKnownWiring() throws {
        let cards = allCardFaces()
        XCTAssertEqual(cards.count, 215)

        let missingAssets = cards.flatMap(\.missingAssets)
        let missingSummary = Dictionary(grouping: missingAssets) { missing in
            "\(missing.kind.rawValue):\(missing.logicalName)->\(missing.canonicalName)"
        }
        let missingKeys = missingSummary.keys.sorted()

        XCTAssertTrue(
            missingKeys.isEmpty,
            "Missing/fallback card assets: \(missingKeys.joined(separator: ", "))"
        )
    }

    func testMissingAssetFallbackDoesNotCrashAndIsListed() {
        let icon = CardSymbolAssetResolver.shared.icon(
            named: "PlayFishTopRow",
            fallbackText: "顶行出鱼",
            accessibilityText: "顶行出鱼"
        )
        let segments = FishCardAbilityTokenParser.parse("[PlayFishTopRow]")

        XCTAssertEqual(icon.assetName, "PlayFishTopRow")
        XCTAssertNil(icon.asset)
        XCTAssertNotNil(icon.missingAsset)
        XCTAssertTrue(segments.contains { segment in
            if case let .icon(parsedIcon) = segment {
                return parsedIcon.assetName == "PlayFishTopRow"
                    && (parsedIcon.asset.map { _ in false } ?? true)
                    && parsedIcon.missingAsset != nil
            }
            return false
        })
    }

    func testUnknownAbilityTokenFallbackIsListedAsMissingAsset() {
        let segments = FishCardAbilityTokenParser.parse("[Mystery]")
        guard case let .icon(icon)? = segments.first else {
            return XCTFail("Expected unknown token to produce a fallback icon.")
        }

        XCTAssertEqual(icon.assetName, "Mystery")
        XCTAssertNil(icon.asset)
        XCTAssertNotNil(icon.missingAsset)
        XCTAssertEqual(icon.missingAsset?.logicalName, "Mystery")
    }

    private func greatWhiteShark() throws -> Card {
        let catalog = try BaseGameCardCatalog()
        return try XCTUnwrap(
            catalog.fishCards.first { $0.id == "base.main.057" },
            "Expected Great White Shark to remain present in the reviewed base game JSON."
        )
    }

    @MainActor
    private func cardFace(for cardId: CardID) throws -> FishCardFaceViewState {
        try XCTUnwrap(allCardFaces().first { $0.cardId == cardId }, "Expected \(cardId) in card QA library.")
    }

    @MainActor
    private func allCardFaces() -> [FishCardFaceViewState] {
        let viewModel = CardLibraryViewModel()
        viewModel.displayMode = .all
        return viewModel.viewState.cards.map(\.cardFace)
    }
}

private extension Array where Element == FishCardAbilitySegment {
    func icon(named assetName: String) -> FishCardFaceIconViewState? {
        compactMap { segment -> FishCardFaceIconViewState? in
            if case let .icon(icon) = segment,
               icon.assetName == assetName {
                return icon
            }
            return nil
        }
        .first
    }
}

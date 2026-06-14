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
        let segments = FishCardAbilityTokenParser.parse(card.abilityText ?? "")
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

    func testFishLengthIconsResolveToAssets() {
        for assetName in ["FishLengthLarge", "FishLengthMedium", "FishLengthSmall"] {
            let lookup = CardSymbolAssetResolver.shared.lookup(named: assetName)

            XCTAssertTrue(lookup.isResolved, "Expected \(assetName) to resolve.")
            XCTAssertEqual(lookup.asset?.fileExtension.lowercased(), "svg")
        }
    }

    func testLightZoneIconsResolveToAssets() {
        for assetName in ["Sun", "Dusk", "Night"] {
            let lookup = CardSymbolAssetResolver.shared.lookup(named: assetName)

            XCTAssertTrue(lookup.isResolved, "Expected \(assetName) to resolve.")
            XCTAssertEqual(lookup.asset?.fileExtension.lowercased(), "svg")
        }
    }

    func testIfActivatedTriggerStyleResolvesStripAssetOrStyle() {
        let style = CardTriggerStyleResolver.shared.style(
            for: AppStrings.GameBoard.abilityTriggerIfActivated
        )

        XCTAssertEqual(style.abilityPanelStyle, .tanBrush)
        XCTAssertEqual(style.stripAssetPrefix, "IfActivated")
        XCTAssertNotNil(style.stripAsset)
    }

    func testGameEndTriggerStyleResolvesStripAssetOrStyle() {
        let style = CardTriggerStyleResolver.shared.style(
            for: AppStrings.GameBoard.abilityTriggerGameEnd
        )

        XCTAssertEqual(style.abilityPanelStyle, .yellowBrush)
        XCTAssertEqual(style.stripAssetPrefix, "GameEnd")
        XCTAssertNotNil(style.stripAsset)
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

    private func greatWhiteShark() throws -> Card {
        let catalog = try BaseGameCardCatalog()
        return try XCTUnwrap(
            catalog.fishCards.first { $0.id == "base.main.057" },
            "Expected Great White Shark to remain present in the reviewed base game JSON."
        )
    }
}

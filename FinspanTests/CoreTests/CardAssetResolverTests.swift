import XCTest
@testable import Finspan

final class CardAssetResolverTests: XCTestCase {
    func testCardSymbolResolverPrefersRenderablePngOverLooseSvgSource() throws {
        for iconName in [
            "ArrowDown",
            "FishEgg",
            "YoungFish",
            "Predator",
            "AllPlayers",
            "Wave",
            "FishLengthSmall",
            "FishLengthMedium",
            "FishLengthLarge",
            "Sun",
            "Dusk",
            "Night",
            "BlueCoral",
            "PurpleCoral",
            "GreenCoral",
            "AnyCoral",
            "PlayFishBottomRow"
        ] {
            let lookup = CardSymbolAssetResolver.shared.lookup(named: iconName)
            let asset = try XCTUnwrap(lookup.asset, "Expected \(iconName) to resolve.")

            XCTAssertNil(lookup.missingAsset)
            XCTAssertEqual(asset.kind, .icon)
            XCTAssertEqual(asset.fileExtension.lowercased(), "png")
            XCTAssertTrue(asset.fileName.hasSuffix(".svg.png"))
            XCTAssertTrue(asset.url.path.contains(".app/") || asset.url.path.contains("/Finspan/Resources/CardAssets/icons/"))
        }
    }

    func testAbilityTokenResolverReturnsRenderablePngForKnownTokens() throws {
        for tokenName in ["FishEgg", "ArrowDown", "Predator", "AllPlayers", "FishHatch", "BlueCoral"] {
            let lookup = AbilityTokenAssetResolver.shared.lookup(for: tokenName)
            let asset = try XCTUnwrap(lookup.asset, "Expected \(tokenName) to resolve.")
            let renderability = CardIconRenderabilityAnalyzer.analyze(asset: asset, assetName: tokenName)

            XCTAssertEqual(asset.fileExtension.lowercased(), "png")
            XCTAssertTrue(renderability.isRenderable, "\(tokenName): \(renderability.failureReasons)")
        }
    }

    func testZoneAliasesResolveToLiveRenderableIconAssets() throws {
        let aliases = [
            "Sunlit": "Sun",
            "Twilight": "Dusk",
            "Midnight": "Night",
            "School": "SchoolFish",
            "Card": "FishFromHand"
        ]

        for (alias, canonical) in aliases {
            let icon = CardSymbolAssetResolver.shared.icon(
                named: alias,
                fallbackText: alias,
                accessibilityText: alias
            )

            XCTAssertEqual(icon.assetName, canonical)
            let asset = try XCTUnwrap(icon.asset, "Expected \(alias) to resolve.")
            XCTAssertEqual(asset.fileExtension.lowercased(), "png")
            XCTAssertTrue(CardIconRenderabilityAnalyzer.analyze(icon).isRenderable)
        }
    }
}

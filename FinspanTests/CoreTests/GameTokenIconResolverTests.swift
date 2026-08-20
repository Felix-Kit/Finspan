import XCTest
@testable import Finspan

final class GameTokenIconResolverTests: XCTestCase {
    func testBoardAndCardTokenIconsResolveToLiveAssets() throws {
        let resolver = GameTokenIconResolver.shared
        let requiredIcons: [GameTokenIconKind] = [
            .fish,
            .egg,
            .young,
            .school,
            .coral(.blue),
            .coral(.purple),
            .coral(.green),
            .anyCoral,
            .draw,
            .discard,
            .consume,
            .hatch,
            .move,
            .arrow,
            .zone(.blue),
            .zone(.purple),
            .zone(.green)
        ]

        for iconKind in requiredIcons {
            let icon = resolver.icon(for: iconKind)
            let asset = try XCTUnwrap(icon.asset, "Expected \(iconKind) to resolve.")

            XCTAssertTrue(icon.isResolved)
            XCTAssertEqual(asset.kind, .icon)
            XCTAssertEqual(asset.fileExtension.lowercased(), "png")
            XCTAssertFalse(icon.icon.fallbackText.isEmpty)
            XCTAssertFalse(icon.icon.accessibilityText.isEmpty)
        }
    }

    func testResourceTokenIconsAreNotTextOnlyFallbacks() {
        for iconKind in [GameTokenIconKind.egg, .young, .school, .coral(.blue), .fish] {
            let icon = GameTokenIconResolver.shared.icon(for: iconKind)

            XCTAssertTrue(icon.isResolved)
            XCTAssertNotNil(icon.asset)
            XCTAssertNil(icon.icon.missingAsset)
        }
    }

    func testEggAndYoungUsePhysicalBoardPieceArtworkWithoutBadgeContainers() {
        let egg = GameTokenIconResolver.shared.icon(for: .egg)
        let young = GameTokenIconResolver.shared.icon(for: .young)
        let school = GameTokenIconResolver.shared.icon(for: .school)

        XCTAssertEqual(egg.boardAssetName, "board_token_egg_orange")
        XCTAssertEqual(young.boardAssetName, "board_token_young_yellow")
        XCTAssertNil(school.boardAssetName)
        XCTAssertTrue(egg.isResolved)
        XCTAssertTrue(young.isResolved)
    }
}

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
}

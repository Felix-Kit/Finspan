import XCTest
import UIKit
@testable import Finspan

final class FishCardIconRenderabilityTests: XCTestCase {
    private let keyIconNames = [
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
    ]

    func testAllLiveSvgIconSourcesStillHaveRenderablePngAssets() throws {
        let fileManager = FileManager.default
        let iconDirectory = repoRoot()
            .appendingPathComponent("Finspan/Resources/CardAssets/icons", isDirectory: true)
        let files = try fileManager.contentsOfDirectory(
            at: iconDirectory,
            includingPropertiesForKeys: nil
        )
        let sourceSvgs = files
            .filter { $0.pathExtension == "svg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(sourceSvgs.isEmpty)

        for sourceSvg in sourceSvgs {
            let renderAsset = sourceSvg.appendingPathExtension("png")
            XCTAssertTrue(
                fileManager.fileExists(atPath: renderAsset.path),
                "Expected generated PNG render asset for \(sourceSvg.lastPathComponent)."
            )
            let result = CardIconRenderabilityAnalyzer.analyze(
                asset: cardAssetReference(
                    url: renderAsset,
                    logicalName: logicalName(from: sourceSvg)
                )
            )
            XCTAssertTrue(
                result.isRenderable,
                "\(sourceSvg.lastPathComponent) renderability failures: \(result.failureReasons)"
            )
            XCTAssertGreaterThanOrEqual(max(result.pixelWidth, result.pixelHeight), 512)
            XCTAssertFalse(result.isAllWhite)
            XCTAssertFalse(result.isAllTransparent)
            XCTAssertFalse(result.hasWhiteBackground)
        }
    }

    func testKeyIconsResolveToRenderableBundleAssets() throws {
        for iconName in keyIconNames {
            let lookup = CardSymbolAssetResolver.shared.lookup(named: iconName)
            let asset = try XCTUnwrap(lookup.asset, "Expected \(iconName) to resolve.")
            XCTAssertEqual(asset.fileExtension.lowercased(), "png")

            let image = UIImage(contentsOfFile: asset.url.path)
            XCTAssertNotNil(image, "Expected runtime bundle to decode \(iconName) at \(asset.url.path).")

            let result = CardIconRenderabilityAnalyzer.analyze(asset: asset, assetName: iconName)
            XCTAssertTrue(
                result.isRenderable,
                "\(iconName) renderability failures: \(result.failureReasons)"
            )
            XCTAssertGreaterThan(result.pixelWidth, 0)
            XCTAssertGreaterThan(result.pixelHeight, 0)
            XCTAssertGreaterThan(result.nonTransparentPixelCount, 0)
            XCTAssertGreaterThan(result.nonWhitePixelRatio, 0.002)
            XCTAssertFalse(result.isAllWhite)
            XCTAssertFalse(result.isAllTransparent)
            XCTAssertFalse(result.hasWhiteBackground)
        }
    }

    @MainActor
    func testRepresentativeCardIconRuntimeSummariesAreRenderable() throws {
        let cards = Dictionary(
            uniqueKeysWithValues: allCardFaces().compactMap { cardFace in
                cardFace.cardId.map { ($0, cardFace) }
            }
        )

        let greatWhiteShark = try XCTUnwrap(cards["base.main.057"])
        assertRenderableSummary(greatWhiteShark, expectedCardId: "base.main.057")
        assertRenderableIcons(
            ["FishEgg", "ArrowDown", "Predator", "AllPlayers"],
            in: greatWhiteShark
        )

        let greatNorthernTilefish = try XCTUnwrap(cards["base.main.056"])
        assertRenderableSummary(greatNorthernTilefish, expectedCardId: "base.main.056")
        assertRenderableIcons(["FishHatch"], in: greatNorthernTilefish)

        let greatBarracuda = try XCTUnwrap(cards["sr.main.161"])
        assertRenderableSummary(greatBarracuda, expectedCardId: "sr.main.161")
        assertRenderableIcons(["BlueCoral", "AllPlayers"], in: greatBarracuda)
        XCTAssertTrue(
            greatBarracuda.costIcons.contains { icon in
                ["AnyCoral", "BlueCoral"].contains(icon.assetName)
            },
            "Expected Great Barracuda to expose coral requirement/cost icons."
        )
    }

    @MainActor
    func testAllCurrentRealCardsHaveNoKnownIconRenderabilityFailures() {
        let cards = allCardFaces()
        XCTAssertEqual(cards.count, 215)

        var failures: [String] = []
        for card in cards {
            for icon in card.cardFaceIconsForRenderability {
                let result = CardIconRenderabilityAnalyzer.analyze(icon)
                if !result.isRenderable {
                    failures.append("\(card.cardId ?? "unknown"):\(icon.assetName):\(result.failureReasons.joined(separator: "|"))")
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Icon renderability failures: \(failures.prefix(30).joined(separator: ", "))"
        )
    }

    func testIconDisplayFramesComeFromCardMetricsNotBitmapIntrinsicSize() throws {
        let waveAsset = try XCTUnwrap(CardSymbolAssetResolver.shared.lookup(named: "Wave").asset)
        let waveResult = CardIconRenderabilityAnalyzer.analyze(asset: waveAsset, assetName: "Wave")

        XCTAssertGreaterThanOrEqual(max(waveResult.pixelWidth, waveResult.pixelHeight), 512)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.costIconHeight, 4.4)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.zoneIconHeight, 5.6)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.lengthIconHeight, 11)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.abilityIconHeight, 9)
        XCTAssertEqual(CardRenderMetrics.CardFaceLayout.abilityArrowHeight, 15)
        XCTAssertLessThan(CardRenderMetrics.CardFaceLayout.abilityIconHeight, Double(waveResult.pixelWidth))
    }

    func testMissingAssetFallbackIsNotReportedAsRenderable() {
        let icon = CardSymbolAssetResolver.shared.icon(
            named: "DefinitelyNotALiveIcon",
            fallbackText: "?",
            accessibilityText: "missing"
        )
        let result = CardIconRenderabilityAnalyzer.analyze(icon)

        XCTAssertFalse(result.isRenderable)
        XCTAssertEqual(result.failureReasons, ["missing asset"])
    }

    private func assertRenderableSummary(
        _ cardFace: FishCardFaceViewState,
        expectedCardId: CardID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let summary = CardIconRenderabilityAnalyzer.debugSummary(for: cardFace)

        XCTAssertEqual(summary.cardId, expectedCardId, file: file, line: line)
        XCTAssertGreaterThan(summary.iconCount, 0, file: file, line: line)
        XCTAssertEqual(summary.failedIconCount, 0, file: file, line: line)
        XCTAssertTrue(summary.failedIconNames.isEmpty, file: file, line: line)
        XCTAssertEqual(summary.missingAssetCount, 0, file: file, line: line)
        XCTAssertTrue(summary.fishImageFound, file: file, line: line)
        XCTAssertTrue(summary.flavorTextFound, file: file, line: line)
        XCTAssertEqual(summary.renderAssetTypes, ["PNG"], file: file, line: line)
    }

    private func assertRenderableIcons(
        _ assetNames: [String],
        in cardFace: FishCardFaceViewState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for assetName in assetNames {
            let icon = cardFace.cardFaceIconsForRenderability.first { $0.assetName == assetName }
            let unwrappedIcon = try? XCTUnwrap(icon, "Expected \(assetName) on \(cardFace.cardId ?? "unknown").")
            guard let unwrappedIcon else {
                XCTFail("Expected \(assetName) on \(cardFace.cardId ?? "unknown").", file: file, line: line)
                continue
            }
            let result = CardIconRenderabilityAnalyzer.analyze(unwrappedIcon)
            XCTAssertTrue(
                result.isRenderable,
                "\(assetName) renderability failures: \(result.failureReasons)",
                file: file,
                line: line
            )
        }
    }

    @MainActor
    private func allCardFaces() -> [FishCardFaceViewState] {
        let viewModel = CardLibraryViewModel()
        viewModel.displayMode = .all
        return viewModel.viewState.cards.map(\.cardFace)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func logicalName(from sourceSvg: URL) -> String {
        sourceSvg.lastPathComponent.split(separator: ".").first.map(String.init) ?? sourceSvg.deletingPathExtension().lastPathComponent
    }

    private func cardAssetReference(url: URL, logicalName: String) -> CardAssetReference {
        CardAssetReference(
            kind: .icon,
            logicalName: logicalName,
            resourceName: url.deletingPathExtension().lastPathComponent,
            fileExtension: url.pathExtension,
            fileName: url.lastPathComponent,
            subdirectory: "CardAssets/icons",
            url: url
        )
    }
}

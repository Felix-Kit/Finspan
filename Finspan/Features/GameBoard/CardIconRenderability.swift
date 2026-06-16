import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct CardIconRenderabilityResult: Equatable {
    let assetName: String
    let fileName: String?
    let fileExtension: String?
    let pixelWidth: Int
    let pixelHeight: Int
    let alphaNonZeroRatio: Double
    let nonWhitePixelRatio: Double
    let nonTransparentPixelCount: Int
    let dominantColor: String?
    let hasWhiteBackground: Bool
    let isAllWhite: Bool
    let isAllTransparent: Bool
    let aspectRatio: Double?
    let sourceViewBoxAspectRatio: Double?
    let renderAssetType: String
    let failureReasons: [String]

    var isRenderable: Bool {
        failureReasons.isEmpty
    }
}

struct FishCardIconRenderDebugSummary: Equatable {
    let cardId: String
    let sourceId: String
    let iconCount: Int
    let failedIconCount: Int
    let failedIconNames: [String]
    let missingAssetCount: Int
    let fishImageFound: Bool
    let flavorTextFound: Bool
    let renderAssetTypes: [String]
    let abilityBlockCount: Int
    let abilityBlockTypes: [String]
    let abilityBlockBackgrounds: [String]
    let tokenPlacements: [String]
    let hasExpansionLogo: Bool
    let hasStarterCorner: Bool
    let hasAllPlayersShadow: Bool
    let triggerBrushMode: String
    let alsoIfBlockCount: Int
    let brushOrientation: String
    let brushContentMode: String
    let brushBackgroundPosition: String
    let brushBackgroundRepeat: String
    let abilityPanelFrame: String
    let liveMeasuredAbilityFrame: String?
    let swiftAbilityFrameDelta: String?
    let swiftBeforeAbilityFrame: String?
    let arrowFlowMetrics: String
    let alsoIfGapCqw: Double
}

enum CardIconRenderabilityAnalyzer {
    private static let whiteThreshold: UInt8 = 238
    private static let lowAlphaThreshold: UInt8 = 8
    private static let sampleMaxDimension = 256
    private static let minRenderableDimension = 128

    private static let lock = NSLock()
    private static var cachedResults: [String: CardIconRenderabilityResult] = [:]

    static func analyze(_ icon: FishCardFaceIconViewState) -> CardIconRenderabilityResult {
        guard let asset = icon.asset else {
            return missingResult(assetName: icon.assetName, reason: "missing asset")
        }
        return analyze(asset: asset, assetName: icon.assetName)
    }

    static func analyze(asset: CardAssetReference, assetName: String? = nil) -> CardIconRenderabilityResult {
        let resolvedAssetName = assetName ?? asset.logicalName
        let cacheKey = "\(resolvedAssetName)|\(asset.url.path)"

        lock.lock()
        if let cached = cachedResults[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = makeResult(asset: asset, assetName: resolvedAssetName)

        lock.lock()
        cachedResults[cacheKey] = result
        lock.unlock()
        return result
    }

    static func debugSummary(for viewState: FishCardFaceViewState) -> FishCardIconRenderDebugSummary {
        let icons = viewState.cardFaceIconsForRenderability
        let results = icons.map(analyze)
        let failedNames = zip(icons, results)
            .filter { !$0.1.isRenderable }
            .map { icon, _ in icon.assetName }
        let renderAssetTypes = Array(
            Set(
                icons.compactMap { icon in
                    icon.asset?.fileExtension.uppercased()
                }
            )
        )
        .sorted()
        let liveMeasurement = CardLiveMeasurementCatalog.summary(for: viewState.cardId)

        return FishCardIconRenderDebugSummary(
            cardId: viewState.cardId ?? "none",
            sourceId: viewState.localFishImagePrefix ?? "none",
            iconCount: icons.count,
            failedIconCount: failedNames.count,
            failedIconNames: failedNames,
            missingAssetCount: viewState.missingAssets.count,
            fishImageFound: viewState.localFishImageAsset != nil,
            flavorTextFound: viewState.flavorText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            renderAssetTypes: renderAssetTypes,
            abilityBlockCount: viewState.abilityPresentation.blocks.count,
            abilityBlockTypes: viewState.abilityPresentation.blocks.map { "\($0.kind.rawValue):\($0.layout.rawValue)" },
            abilityBlockBackgrounds: viewState.abilityPresentation.blocks.map { $0.backgroundAssetPrefix ?? "none" },
            tokenPlacements: viewState.abilityPresentation.tokenPlacementSummary,
            hasExpansionLogo: viewState.expansionBadgeIcon != nil,
            hasStarterCorner: viewState.hasStarterCornerDecorations,
            hasAllPlayersShadow: viewState.abilityPresentation.hasAllPlayersShadow,
            triggerBrushMode: viewState.abilityPanelStyle.rawValue,
            alsoIfBlockCount: viewState.abilityPresentation.alsoIfBlockCount,
            brushOrientation: CardAbilityBrushMetrics.live.orientation.rawValue,
            brushContentMode: CardAbilityBrushMetrics.live.assetContentMode,
            brushBackgroundPosition: CardAbilityBrushMetrics.live.backgroundPosition,
            brushBackgroundRepeat: CardAbilityBrushMetrics.live.backgroundRepeat,
            abilityPanelFrame: CardAbilityPanelMetrics.live.frameSummary,
            liveMeasuredAbilityFrame: liveMeasurement?.liveAbilityFrame.summary,
            swiftAbilityFrameDelta: liveMeasurement?.deltaFrame.summary,
            swiftBeforeAbilityFrame: liveMeasurement?.swiftBeforeAbilityFrame?.summary,
            arrowFlowMetrics: CardAbilityArrowFlowMetrics.live.summary,
            alsoIfGapCqw: CardAbilityPanelMetrics.live.blockGapCqw
        )
    }

    private static func makeResult(asset: CardAssetReference, assetName: String) -> CardIconRenderabilityResult {
        let renderAssetType = asset.fileExtension.uppercased()
        guard asset.fileExtension.lowercased() != "svg" else {
            return failedResult(
                assetName: assetName,
                asset: asset,
                renderAssetType: renderAssetType,
                sourceViewBoxAspectRatio: sourceViewBoxAspectRatio(for: asset),
                reason: "loose SVG is source, not iOS render asset"
            )
        }

#if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: asset.url.path),
              let cgImage = image.cgImage
        else {
            return failedResult(
                assetName: assetName,
                asset: asset,
                renderAssetType: renderAssetType,
                sourceViewBoxAspectRatio: sourceViewBoxAspectRatio(for: asset),
                reason: "image decode failed"
            )
        }

        return scan(
            cgImage: cgImage,
            assetName: assetName,
            asset: asset,
            renderAssetType: renderAssetType,
            sourceViewBoxAspectRatio: sourceViewBoxAspectRatio(for: asset)
        )
#else
        return failedResult(
            assetName: assetName,
            asset: asset,
            renderAssetType: renderAssetType,
            sourceViewBoxAspectRatio: sourceViewBoxAspectRatio(for: asset),
            reason: "UIKit image decode unavailable"
        )
#endif
    }

#if canImport(UIKit)
    private static func scan(
        cgImage: CGImage,
        assetName: String,
        asset: CardAssetReference,
        renderAssetType: String,
        sourceViewBoxAspectRatio: Double?
    ) -> CardIconRenderabilityResult {
        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        let aspectRatio = pixelHeight > 0 ? Double(pixelWidth) / Double(pixelHeight) : nil
        let maxDimension = max(pixelWidth, pixelHeight, 1)
        let scale = min(1, Double(sampleMaxDimension) / Double(maxDimension))
        let sampleWidth = max(1, Int((Double(pixelWidth) * scale).rounded()))
        let sampleHeight = max(1, Int((Double(pixelHeight) * scale).rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return failedResult(
                assetName: assetName,
                asset: asset,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                renderAssetType: renderAssetType,
                sourceViewBoxAspectRatio: sourceViewBoxAspectRatio,
                reason: "bitmap context failed"
            )
        }

        context.clear(CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var visibleCount = 0
        var nonWhiteCount = 0
        var whiteCount = 0
        var buckets: [String: Int] = [:]
        let pixelCount = max(sampleWidth * sampleHeight, 1)

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let alpha = pixels[index + 3]
            guard alpha > lowAlphaThreshold else {
                continue
            }

            visibleCount += 1
            let isWhite = red >= whiteThreshold && green >= whiteThreshold && blue >= whiteThreshold
            if isWhite {
                whiteCount += 1
            } else {
                nonWhiteCount += 1
            }
            let bucket = "rgba(\((Int(red) / 16) * 16),\((Int(green) / 16) * 16),\((Int(blue) / 16) * 16),\((Int(alpha) / 16) * 16))"
            buckets[bucket, default: 0] += 1
        }

        let alphaRatio = Double(visibleCount) / Double(pixelCount)
        let nonWhiteRatio = Double(nonWhiteCount) / Double(pixelCount)
        let whiteRatio = Double(whiteCount) / Double(pixelCount)
        let hasWhiteBackground = alphaRatio > 0.97 && whiteRatio > 0.75
        let isAllWhite = alphaRatio > 0.97 && nonWhiteRatio < 0.01
        let isAllTransparent = visibleCount == 0
        var failures: [String] = []

        if min(pixelWidth, pixelHeight) < minRenderableDimension {
            failures.append("render asset too small")
        }
        if isAllTransparent {
            failures.append("all transparent")
        }
        if isAllWhite {
            failures.append("all or nearly all white")
        }
        if hasWhiteBackground {
            failures.append("opaque white background")
        }
        if nonWhiteRatio <= 0.002 {
            failures.append("too few visible non-white pixels")
        }
        if let aspectRatio,
           let sourceViewBoxAspectRatio,
           !aspectRatio.isApproximatelyEqual(to: sourceViewBoxAspectRatio, tolerance: 0.08) {
            failures.append("aspect ratio does not match source viewBox")
        }

        let dominantColor = buckets.max { $0.value < $1.value }?.key
        return CardIconRenderabilityResult(
            assetName: assetName,
            fileName: asset.fileName,
            fileExtension: asset.fileExtension,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            alphaNonZeroRatio: alphaRatio,
            nonWhitePixelRatio: nonWhiteRatio,
            nonTransparentPixelCount: visibleCount,
            dominantColor: dominantColor,
            hasWhiteBackground: hasWhiteBackground,
            isAllWhite: isAllWhite,
            isAllTransparent: isAllTransparent,
            aspectRatio: aspectRatio,
            sourceViewBoxAspectRatio: sourceViewBoxAspectRatio,
            renderAssetType: renderAssetType,
            failureReasons: failures
        )
    }
#endif

    private static func missingResult(assetName: String, reason: String) -> CardIconRenderabilityResult {
        CardIconRenderabilityResult(
            assetName: assetName,
            fileName: nil,
            fileExtension: nil,
            pixelWidth: 0,
            pixelHeight: 0,
            alphaNonZeroRatio: 0,
            nonWhitePixelRatio: 0,
            nonTransparentPixelCount: 0,
            dominantColor: nil,
            hasWhiteBackground: false,
            isAllWhite: false,
            isAllTransparent: false,
            aspectRatio: nil,
            sourceViewBoxAspectRatio: nil,
            renderAssetType: "missing",
            failureReasons: [reason]
        )
    }

    private static func failedResult(
        assetName: String,
        asset: CardAssetReference,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        renderAssetType: String,
        sourceViewBoxAspectRatio: Double?,
        reason: String
    ) -> CardIconRenderabilityResult {
        CardIconRenderabilityResult(
            assetName: assetName,
            fileName: asset.fileName,
            fileExtension: asset.fileExtension,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            alphaNonZeroRatio: 0,
            nonWhitePixelRatio: 0,
            nonTransparentPixelCount: 0,
            dominantColor: nil,
            hasWhiteBackground: false,
            isAllWhite: false,
            isAllTransparent: false,
            aspectRatio: pixelHeight > 0 ? Double(pixelWidth) / Double(pixelHeight) : nil,
            sourceViewBoxAspectRatio: sourceViewBoxAspectRatio,
            renderAssetType: renderAssetType,
            failureReasons: [reason]
        )
    }

    private static func sourceViewBoxAspectRatio(for asset: CardAssetReference) -> Double? {
        let sourceURL: URL?
        if asset.fileName.hasSuffix(".svg.png") {
            sourceURL = asset.url.deletingLastPathComponent()
                .appendingPathComponent(String(asset.fileName.dropLast(4)))
        } else if asset.fileExtension.lowercased() == "svg" {
            sourceURL = asset.url
        } else {
            sourceURL = nil
        }

        guard let sourceURL,
              let text = try? String(contentsOf: sourceURL, encoding: .utf8)
        else {
            return nil
        }

        if let viewBox = text.firstMatch(
            pattern: #"viewBox=["']\s*([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s*["']"#
        ) {
            let width = Double(viewBox[3]) ?? 0
            let height = Double(viewBox[4]) ?? 0
            return height > 0 ? width / height : nil
        }

        guard let widthMatch = text.firstMatch(pattern: #"\bwidth=["']([0-9.]+)"#),
              let heightMatch = text.firstMatch(pattern: #"\bheight=["']([0-9.]+)"#)
        else {
            return nil
        }
        let width = Double(widthMatch[1]) ?? 0
        let height = Double(heightMatch[1]) ?? 0
        return height > 0 ? width / height : nil
    }
}

extension FishCardFaceViewState {
    var cardFaceIconsForRenderability: [FishCardFaceIconViewState] {
        let abilityIcons = abilitySegments.compactMap { segment -> FishCardFaceIconViewState? in
            if case let .icon(icon) = segment {
                return icon
            }
            return nil
        }
        let presentationIcons = abilityPresentation.blocks.flatMap { block in
            block.elements.cardFaceIconsForRenderability
        }
        return costIcons
            + zoneIcons
            + tagIcons
            + [pointsIcon, sizeClassIcon]
            + abilityIcons
            + presentationIcons
            + [expansionBadgeIcon].compactMap { $0 }
    }
}

private extension Array where Element == CardAbilityElement {
    var cardFaceIconsForRenderability: [FishCardFaceIconViewState] {
        flatMap { element -> [FishCardFaceIconViewState] in
            switch element {
            case let .icon(icon):
                return [icon.icon]
            case let .iconGroup(group):
                return group.icons.map(\.icon)
            case let .points(points):
                return [points.waveIcon]
            case let .horizontalRow(elements):
                return elements.cardFaceIconsForRenderability
            case .text:
                return []
            }
        }
    }
}

private extension String {
    func firstMatch(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range) else {
            return nil
        }
        return (0..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: self) else {
                return nil
            }
            return String(self[range])
        }
    }
}

private extension Double {
    func isApproximatelyEqual(to other: Double, tolerance: Double) -> Bool {
        abs(self - other) <= tolerance || abs(self - other) <= max(abs(self), abs(other)) * tolerance
    }
}

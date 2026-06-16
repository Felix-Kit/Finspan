import Foundation

struct CardMeasuredCqwFrame: Equatable {
    let left: Double
    let top: Double
    let width: Double
    let height: Double
    let rightGap: Double
    let bottomGap: Double

    var summary: String {
        "x:\(left.rounded(toPlaces: 3)) y:\(top.rounded(toPlaces: 3)) w:\(width.rounded(toPlaces: 3)) h:\(height.rounded(toPlaces: 3)) r:\(rightGap.rounded(toPlaces: 3))"
    }
}

struct CardLiveMeasurementSummary: Equatable {
    let cardId: String
    let liveAbilityFrame: CardMeasuredCqwFrame
    let swiftAbilityFrame: CardMeasuredCqwFrame
    let swiftBeforeAbilityFrame: CardMeasuredCqwFrame?
    let brushAssetNames: [String]
    let brushBackgroundSize: String
    let brushBackgroundPosition: String
    let brushBackgroundRepeat: String
    let alsoIfGapCqw: Double?
    let arrowTopOverlapCqw: Double?
    let arrowBottomOverlapCqw: Double?

    var deltaFrame: CardMeasuredCqwFrame {
        CardMeasuredCqwFrame(
            left: swiftAbilityFrame.left - liveAbilityFrame.left,
            top: swiftAbilityFrame.top - liveAbilityFrame.top,
            width: swiftAbilityFrame.width - liveAbilityFrame.width,
            height: swiftAbilityFrame.height - liveAbilityFrame.height,
            rightGap: swiftAbilityFrame.rightGap - liveAbilityFrame.rightGap,
            bottomGap: swiftAbilityFrame.bottomGap - liveAbilityFrame.bottomGap
        )
    }
}

enum CardLiveMeasurementCatalog {
    private static var cachedSummaries: [String: CardLiveMeasurementSummary]?

    static func summary(for cardId: String?) -> CardLiveMeasurementSummary? {
        guard let cardId else {
            return nil
        }
        if cachedSummaries == nil {
            cachedSummaries = loadSummaries()
        }
        return cachedSummaries?[cardId]
    }

    static var currentSwiftAbilityFrame: CardMeasuredCqwFrame {
        let metrics = CardAbilityPanelMetrics.live
        return CardMeasuredCqwFrame(
            left: metrics.leftCqw,
            top: metrics.topPaddingCqw,
            width: metrics.widthCqw,
            height: metrics.heightCqw,
            rightGap: metrics.trailingPaddingCqw,
            bottomGap: 0
        )
    }

    private static func loadSummaries() -> [String: CardLiveMeasurementSummary] {
        guard let url = generatedMeasurementsURL(),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cards = json["cards"] as? [[String: Any]]
        else {
            return [:]
        }

        var summaries: [String: CardLiveMeasurementSummary] = [:]
        for card in cards {
            guard let cardId = card["cardId"] as? String,
                  let abilityContainer = card["abilityContainer"] as? [String: Any],
                  let liveCqw = abilityContainer["cqw"] as? [String: Any],
                  let liveFrame = measuredFrame(from: liveCqw)
            else {
                continue
            }

            let swiftBeforeFrame: CardMeasuredCqwFrame?
            if let swiftBefore = card["swiftBefore"] as? [String: Any],
               let abilityPanelFrame = swiftBefore["abilityPanelFrame"] as? [String: Any],
               let cqw = abilityPanelFrame["cqw"] as? [String: Any] {
                swiftBeforeFrame = measuredFrame(from: cqw)
            } else {
                swiftBeforeFrame = nil
            }

            let blocks = card["abilityBlocks"] as? [[String: Any]] ?? []
            let backgrounds = blocks.compactMap { block -> [String: Any]? in
                block["background"] as? [String: Any]
            }
            let brushAssets = Array(Set(backgrounds.compactMap { $0["assetName"] as? String })).sorted()
            let firstBackground = backgrounds.first
            let alsoIfGap = (card["alsoIfGap"] as? [String: Any])?["cqw"] as? Double
            let arrowDown = card["arrowDown"] as? [String: Any]

            summaries[cardId] = CardLiveMeasurementSummary(
                cardId: cardId,
                liveAbilityFrame: liveFrame,
                swiftAbilityFrame: currentSwiftAbilityFrame,
                swiftBeforeAbilityFrame: swiftBeforeFrame,
                brushAssetNames: brushAssets,
                brushBackgroundSize: firstBackground?["size"] as? String ?? "none",
                brushBackgroundPosition: firstBackground?["position"] as? String ?? "none",
                brushBackgroundRepeat: firstBackground?["repeat"] as? String ?? "none",
                alsoIfGapCqw: alsoIfGap,
                arrowTopOverlapCqw: arrowDown?["topOverlapCqw"] as? Double,
                arrowBottomOverlapCqw: arrowDown?["bottomOverlapCqw"] as? Double
            )
        }
        return summaries
    }

    private static func generatedMeasurementsURL() -> URL? {
        if let bundleURL = Bundle.main.url(forResource: "live_measurements", withExtension: "json") {
            return bundleURL
        }

        var sourceURL = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            sourceURL.deleteLastPathComponent()
        }

        let generatedURL = sourceURL
            .appendingPathComponent("tools")
            .appendingPathComponent("generated")
            .appendingPathComponent("card_rendering")
            .appendingPathComponent("live_measurements.json")
        return FileManager.default.fileExists(atPath: generatedURL.path) ? generatedURL : nil
    }

    private static func measuredFrame(from dictionary: [String: Any]) -> CardMeasuredCqwFrame? {
        guard let left = dictionary["left"] as? Double,
              let top = dictionary["top"] as? Double,
              let width = dictionary["width"] as? Double,
              let height = dictionary["height"] as? Double,
              let rightGap = dictionary["rightGap"] as? Double
        else {
            return nil
        }
        return CardMeasuredCqwFrame(
            left: left,
            top: top,
            width: width,
            height: height,
            rightGap: rightGap,
            bottomGap: dictionary["bottomGap"] as? Double ?? 0
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

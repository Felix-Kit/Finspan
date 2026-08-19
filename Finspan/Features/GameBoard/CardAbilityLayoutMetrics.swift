import Foundation

/// Live finsearch CSS uses container-query width units (`cqw`) on the card.
/// These values are measured from a rendered Chromium DOM snapshot in
/// `tools/generated/card_rendering/live_measurements.json`; the slight offsets
/// come from the live card border and CSS content-box sizing.
struct CardAbilityPanelMetrics: Equatable {
    let widthCqw: Double
    let rightGapCqw: Double
    let topPaddingCqw: Double
    let heightCqw: Double
    let blockGapCqw: Double

    static let live = CardAbilityPanelMetrics(
        widthCqw: 27.851,
        rightGapCqw: 0.266,
        topPaddingCqw: 0.266,
        heightCqw: 65.218,
        blockGapCqw: 1.986
    )

    var leftCqw: Double {
        CardRenderMetrics.CardFaceLayout.fullCardWidth - rightGapCqw - widthCqw
    }

    var trailingPaddingCqw: Double {
        rightGapCqw
    }

    var frameSummary: String {
        "x:\(leftCqw) y:\(topPaddingCqw) w:\(widthCqw) h:\(heightCqw.rounded(toPlaces: 2))"
    }
}

enum CardAbilityBrushOrientation: String, Equatable {
    case horizontalRightToLeft
}

/// Live CSS keeps the strip asset unrotated with `background-size: cover` and
/// default top-left background positioning.
struct CardAbilityBrushMetrics: Equatable {
    let orientation: CardAbilityBrushOrientation
    let capInsetCqw: Double
    let cornerRadiusCqw: Double
    let usesRotation: Bool
    let usesPureColorFallback: Bool
    let assetContentMode: String
    let backgroundPosition: String
    let backgroundRepeat: String

    static let live = CardAbilityBrushMetrics(
        orientation: .horizontalRightToLeft,
        capInsetCqw: 0,
        cornerRadiusCqw: 0,
        usesRotation: false,
        usesPureColorFallback: false,
        assetContentMode: "coverTopLeading",
        backgroundPosition: "0% 0%",
        backgroundRepeat: "repeat"
    )
}

struct CardAbilityBlockMetrics: Equatable {
    let horizontalPaddingCqw: Double
    let topPaddingCqw: Double
    let bottomPaddingCqw: Double
    let contentGapCqw: Double
    let minTotalHeightCqw: Double
    let textFontSizeCqw: Double

    static func live(for layout: CardAbilityBlockLayout, panelStyle: FishCardAbilityPanelStyle) -> CardAbilityBlockMetrics {
        switch layout {
        case .standard:
            return CardAbilityBlockMetrics(
                horizontalPaddingCqw: 0,
                topPaddingCqw: 3,
                bottomPaddingCqw: 5,
                contentGapCqw: 1,
                minTotalHeightCqw: 27.842,
                textFontSizeCqw: panelStyle == .none ? 3.45 : 4.1
            )
        case .squished:
            return CardAbilityBlockMetrics(
                horizontalPaddingCqw: 0,
                topPaddingCqw: 2,
                bottomPaddingCqw: 2,
                contentGapCqw: 0.55,
                minTotalHeightCqw: 17.993,
                textFontSizeCqw: 3.55
            )
        case .alsoIf:
            return CardAbilityBlockMetrics(
                horizontalPaddingCqw: 1,
                topPaddingCqw: 3,
                bottomPaddingCqw: 3,
                contentGapCqw: 0.7,
                minTotalHeightCqw: 35.286,
                textFontSizeCqw: 3.45
            )
        }
    }
}

/// Derived from `.icon-group { gap: 1cqw }` plus
/// `.ability .ArrowDown { height: 15cqw; margin: -5cqw 0; }`.
struct CardAbilityArrowFlowMetrics: Equatable {
    let defaultIconHeightCqw: Double
    let arrowHeightCqw: Double
    let iconGroupGapCqw: Double
    let arrowNegativeMarginCqw: Double
    let arrowVerticalOffsetCqw: Double
    let allPlayersHeightCqw: Double
    let allPlayersBottomCqw: Double

    static let live = CardAbilityArrowFlowMetrics(
        defaultIconHeightCqw: 9,
        arrowHeightCqw: 15,
        iconGroupGapCqw: 1,
        arrowNegativeMarginCqw: -5,
        arrowVerticalOffsetCqw: 0,
        allPlayersHeightCqw: 9,
        allPlayersBottomCqw: 4
    )

    var effectiveStackSpacingCqw: Double {
        iconGroupGapCqw + arrowNegativeMarginCqw
    }

    var summary: String {
        "icon:\(defaultIconHeightCqw) arrow:\(arrowHeightCqw) spacing:\(effectiveStackSpacingCqw) offset:\(arrowVerticalOffsetCqw) allPlayersBottom:\(allPlayersBottomCqw)"
    }
}

/// Absolute overlay placement measured from the live `.ability-container`.
/// In particular, `AllPlayers` sits below the brush-backed ability content.
struct CardAbilityContainerOverlayMetrics: Equatable {
    let allPlayersHeightCqw: Double
    let allPlayersBottomCqw: Double

    static let live = CardAbilityContainerOverlayMetrics(
        allPlayersHeightCqw: 9,
        allPlayersBottomCqw: 4
    )

    func allPlayersTopCqw(in panel: CardAbilityPanelMetrics = .live) -> Double {
        panel.heightCqw - allPlayersBottomCqw - allPlayersHeightCqw
    }
}

/// Mirrors the live finsearch ability-icon CSS. Values are heights in card
/// container-query width units; horizontal ability rows additionally cap
/// their icon width so mixed icon runs stay inside the right panel.
struct CardAbilityIconLayoutMetrics: Equatable {
    let heightCqw: Double
    let maxWidthCqw: Double?

    static func live(for assetName: String, isHorizontalRow: Bool = false) -> CardAbilityIconLayoutMetrics {
        let height: Double
        switch assetName {
        case "ArrowDown":
            height = 15
        case "SchoolFeederMove":
            height = 12.5
        case "FishLengthSmall", "FishLengthMedium", "FishLengthLarge":
            height = 12
        case "UnSchoolFish":
            height = 16
        case "AnyCoral":
            height = 12
        case "YoungFish":
            height = 6.5
        case "ConsumeFish", "ConsumeFish1", "ConsumeFish2", "ConsumeFish3", "Discard", "DrawCard", "FishFromHand":
            height = 8
        default:
            height = 9
        }

        guard isHorizontalRow, assetName != "SchoolFish" else {
            return CardAbilityIconLayoutMetrics(heightCqw: height, maxWidthCqw: nil)
        }
        return CardAbilityIconLayoutMetrics(heightCqw: min(height, 7), maxWidthCqw: 8)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

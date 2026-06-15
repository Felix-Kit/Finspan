import Foundation

/// Live finsearch CSS uses container-query width units (`cqw`) on the card:
/// `.ability-container { min-width: 28cqw; right: 28cqw; height: calc(100% - 1cqw); padding-top: 1cqw; }`.
struct CardAbilityPanelMetrics: Equatable {
    let widthCqw: Double
    let liveRightOffsetCqw: Double
    let topPaddingCqw: Double
    let heightReductionCqw: Double
    let blockGapCqw: Double

    static let live = CardAbilityPanelMetrics(
        widthCqw: 28,
        liveRightOffsetCqw: 28,
        topPaddingCqw: 1,
        heightReductionCqw: 1,
        blockGapCqw: 2
    )

    var leftCqw: Double {
        CardRenderMetrics.CardFaceLayout.fullCardWidth - liveRightOffsetCqw
    }

    var trailingPaddingCqw: Double {
        CardRenderMetrics.CardFaceLayout.fullCardWidth - leftCqw - widthCqw
    }

    var heightCqw: Double {
        (CardRenderMetrics.CardFaceLayout.fullCardWidth / CardRenderMetrics.cardAspectRatio) - heightReductionCqw
    }

    var frameSummary: String {
        "x:\(leftCqw) y:\(topPaddingCqw) w:\(widthCqw) h:\(heightCqw.rounded(toPlaces: 2))"
    }
}

enum CardAbilityBrushOrientation: String, Equatable {
    case horizontalRightToLeft
}

/// Live CSS keeps the strip asset unrotated with `background-size: cover`.
/// SwiftUI uses stretch resizing so the strip keeps its horizontal brush direction
/// instead of being aspect-filled and clipped into a vertical-looking brush.
struct CardAbilityBrushMetrics: Equatable {
    let orientation: CardAbilityBrushOrientation
    let capInsetCqw: Double
    let cornerRadiusCqw: Double
    let usesRotation: Bool
    let usesPureColorFallback: Bool
    let assetContentMode: String

    static let live = CardAbilityBrushMetrics(
        orientation: .horizontalRightToLeft,
        capInsetCqw: 2,
        cornerRadiusCqw: 1.3,
        usesRotation: false,
        usesPureColorFallback: false,
        assetContentMode: "stretch"
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
                minTotalHeightCqw: 28,
                textFontSizeCqw: panelStyle == .none ? 3.45 : 4.1
            )
        case .squished:
            return CardAbilityBlockMetrics(
                horizontalPaddingCqw: 0,
                topPaddingCqw: 2,
                bottomPaddingCqw: 2,
                contentGapCqw: 0.55,
                minTotalHeightCqw: 15,
                textFontSizeCqw: 3.55
            )
        case .alsoIf:
            return CardAbilityBlockMetrics(
                horizontalPaddingCqw: 1,
                topPaddingCqw: 3,
                bottomPaddingCqw: 3,
                contentGapCqw: 0.7,
                minTotalHeightCqw: 18,
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

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

import Foundation

enum CardRenderMetrics {
    /// Source asset dimensions remain useful for import validation.
    static let sourceBackgroundWidth: Double = 4_394
    static let sourceBackgroundHeight: Double = 2_976
    static let sourceBackgroundAspectRatio = sourceBackgroundWidth / sourceBackgroundHeight

    /// Derived from finsearch CSS: `.card { aspect-ratio: 61 / 40 }`.
    /// See `docs/FINSEARCH_RENDERER_REVERSE_ENGINEERING.md`.
    static let cardAspectRatio = 61.0 / 40.0

    static let cornerRadiusRatio: Double = 0.04
    static let contentPaddingRatio: Double = 0.035
    static let handCardWidth: Double = 218
    static let handCardHeight: Double = handCardWidth / cardAspectRatio

    /// Normalized cqw-style positions derived from the saved finsearch CSS.
    enum CardFaceLayout {
        static let costTop: Double = 3
        static let costIconHeight: Double = 4.4
        static let zonesTop: Double = 11.5
        static let zonesHeight: Double = 22.5
        static let zoneIconHeight: Double = 5.6
        static let nameTop: Double = 3.5
        static let titleFontSize: Double = 5.8
        static let latinFontSize: Double = 5.0
        static let silhouetteLeft: Double = 22
        static let silhouetteTop: Double = 19
        static let silhouetteMaxWidth: Double = 48
        static let silhouetteMaxHeight: Double = 34
        static let descriptionLeft: Double = 22
        static let descriptionTop: Double = 50
        static let descriptionWidth: Double = 50
        static let descriptionFontSize: Double = 2.5
        static let pointsLeft: Double = 3
        static let pointsTop: Double = 37
        static let pointsFontSize: Double = 7
        static let lengthLeft: Double = 4
        static let lengthTop: Double = 48
        static let lengthWidth: Double = 7.95
        static let lengthFontSize: Double = 5
        static let lengthIconHeight: Double = 11
        static let abilityWidth: Double = 30
        static let abilityPanelWidth: Double = abilityWidth
        static let triggerStripWidth: Double = abilityPanelWidth
        static let fullCardWidth: Double = 100
        static let abilityTop: Double = 16
        static let abilityMinHeight: Double = 20
        static let abilityFontSize: Double = 4.1
        static let abilityIconHeight: Double = 9
        static let abilityArrowHeight: Double = 15
    }

    struct NormalizedRect: Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var maxX: Double { x + width }
        var maxY: Double { y + height }

        func contains(_ other: NormalizedRect) -> Bool {
            other.x >= x
                && other.y >= y
                && other.maxX <= maxX
                && other.maxY <= maxY
        }

        func intersects(_ other: NormalizedRect) -> Bool {
            x < other.maxX
                && maxX > other.x
                && y < other.maxY
                && maxY > other.y
        }
    }

    /// Board-only resource pieces occupy the fish artwork, never card chrome or copy.
    /// Values use the same width-based cqw coordinate system as `CardFaceLayout`.
    enum BoardResourceTokenLayout {
        static let maxVisibleTokens = 5
        static let visualSize: Double = 9
        static let hitTargetSize: Double = 11
        static let cardBounds = NormalizedRect(
            x: 0,
            y: 0,
            width: CardFaceLayout.fullCardWidth,
            height: CardFaceLayout.fullCardWidth / cardAspectRatio
        )
        static let artworkRegion = NormalizedRect(
            x: CardFaceLayout.silhouetteLeft,
            y: CardFaceLayout.silhouetteTop,
            width: CardFaceLayout.silhouetteMaxWidth,
            height: CardFaceLayout.silhouetteMaxHeight
        )
        static let abilityRegion = NormalizedRect(
            x: CardFaceLayout.fullCardWidth - CardFaceLayout.abilityPanelWidth,
            y: 0,
            width: CardFaceLayout.abilityPanelWidth,
            height: cardBounds.height
        )
        static let pointsAndLengthRegion = NormalizedRect(x: 0, y: 34, width: 18, height: 31)
        static let tagRegion = NormalizedRect(x: 54, y: 0, width: 30, height: 12)
        static let nameRegion = NormalizedRect(x: 22, y: 0, width: 50, height: 17)
        static let flavorRegion = NormalizedRect(
            x: CardFaceLayout.descriptionLeft,
            y: CardFaceLayout.descriptionTop,
            width: CardFaceLayout.descriptionWidth,
            height: cardBounds.height - CardFaceLayout.descriptionTop
        )

        private static let visualOrigins: [(x: Double, y: Double)] = [
            (30, 25),
            (39, 28),
            (48, 25),
            (34.5, 35),
            (43.5, 35)
        ]

        static func visualFrame(at index: Int) -> NormalizedRect {
            let origin = visualOrigins[min(max(index, 0), visualOrigins.count - 1)]
            return NormalizedRect(x: origin.x, y: origin.y, width: visualSize, height: visualSize)
        }

        static func hitTargetFrame(at index: Int) -> NormalizedRect {
            let visualFrame = visualFrame(at: index)
            let inset = (hitTargetSize - visualSize) / 2
            return NormalizedRect(
                x: visualFrame.x - inset,
                y: visualFrame.y - inset,
                width: hitTargetSize,
                height: hitTargetSize
            )
        }
    }
}

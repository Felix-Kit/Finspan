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
        static let pointsLeft: Double = 3
        static let pointsTop: Double = 37
        static let pointsFontSize: Double = 7
        static let lengthLeft: Double = 4
        static let lengthTop: Double = 48
        static let lengthWidth: Double = 7.95
        static let lengthFontSize: Double = 5
        static let lengthIconHeight: Double = 11
        static let abilityWidth: Double = 30
        static let abilityTop: Double = 16
        static let abilityMinHeight: Double = 20
        static let abilityFontSize: Double = 4.1
        static let abilityIconHeight: Double = 9
        static let abilityArrowHeight: Double = 15
    }
}

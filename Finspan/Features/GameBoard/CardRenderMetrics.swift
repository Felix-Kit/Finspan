import Foundation

enum CardRenderMetrics {
    /// Derived from local finsearch full-card background assets: 4394 x 2976.
    /// See `docs/CARD_RENDERING_MODEL.md` for the current import notes.
    static let sourceBackgroundWidth: Double = 4_394
    static let sourceBackgroundHeight: Double = 2_976
    static let cardAspectRatio = sourceBackgroundWidth / sourceBackgroundHeight

    static let cornerRadiusRatio: Double = 0.04
    static let contentPaddingRatio: Double = 0.035
    static let handCardWidth: Double = 218
    static let handCardHeight: Double = handCardWidth / cardAspectRatio
}

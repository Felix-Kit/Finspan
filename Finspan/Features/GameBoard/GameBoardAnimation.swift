import SwiftUI

enum GameBoardAnimation {
    enum Duration {
        static let quick = 0.16
        static let standard = 0.24
        static let slow = 0.34
    }

    static let quick = Animation.snappy(duration: Duration.quick)
    static let standard = Animation.snappy(duration: Duration.standard)
    static let slow = Animation.easeInOut(duration: Duration.slow)

    static let handSelection = Animation.spring(response: 0.26, dampingFraction: 0.84)
    static let handReturn = Animation.spring(response: 0.30, dampingFraction: 0.88)
    static let dock = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let token = Animation.spring(response: 0.22, dampingFraction: 0.82)
    static let overlay = Animation.easeInOut(duration: Duration.standard)
    static let boardPerspective = Animation.easeInOut(duration: Duration.slow)

    static let selectedHandCardScale: CGFloat = 1.035
    static let draggingHandCardScale: CGFloat = 1.06
    static let dockSelectedTokenScale: CGFloat = 1.045
    static let invalidCardNudge: CGFloat = 8

    static var dockTransition: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    static var overlayDimTransition: AnyTransition {
        .opacity
    }

    static var overlayPanelTransition: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    static var tokenTransition: AnyTransition {
        .scale(scale: 0.92).combined(with: .opacity)
    }

    static var boardPerspectiveTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

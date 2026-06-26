import SwiftUI

enum BottomRewardDockDisplayMode: String, Equatable {
    case hidden
    case handleOnly
    case compact
    case expanded
}

enum BottomRewardDockAction: Equatable {
    case selectRewardToken(String)
    case primary
    case back
    case activateGameEndAbility(GameEndAbilitySource)
    case finishGameEndAbilities
    case openFallbackOverlay
    case viewSourcePlayer(PlayerID)
}

struct BottomRewardDockControl: Equatable {
    let title: String
    let action: BottomRewardDockAction
    let isEnabled: Bool
    let accessibilityLabel: String
}

struct BottomRewardDockToken: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: GameTokenIconAsset
    let countText: String?
    let isSelectable: Bool
    let isSelected: Bool
    let isCompleted: Bool
    let isUnsupported: Bool
    let fallbackReason: String?
    let continuationSurfaces: [ContinuationSurface]
    let action: BottomRewardDockAction
}

struct BottomRewardDockState: Equatable {
    let displayMode: BottomRewardDockDisplayMode
    let title: String
    let sourceText: String?
    var sourcePlayerId: PlayerID? = nil
    let instructionText: String
    let summaryLines: [String]
    let tokens: [BottomRewardDockToken]
    let warningText: String?
    let fallbackReason: String?
    let forwardControl: BottomRewardDockControl?
    let backControl: BottomRewardDockControl?

    var usesMainBoardRightPanel: Bool { false }
    var hasInformationalContent: Bool {
        !tokens.isEmpty
            || !summaryLines.isEmpty
            || sourceText != nil
            || warningText != nil
            || fallbackReason != nil
    }
    var hasPrimaryContent: Bool { hasInformationalContent }
}

enum BottomDockOverlayRoute: String, Equatable {
    case discardPileSelection
    case handCardPicker
    case playFishStaging
    case reefTargetPicker
    case debugFallback
    case gameEndCandidate
}

struct BottomDockOverlayState: Equatable {
    let route: BottomDockOverlayRoute
    let title: String
    let instructionText: String
    let handCards: [HandCardViewState]
    let debugText: String?

    var usesMainBoardRightPanel: Bool { false }
}

struct BottomRewardDockView: View {
    let state: BottomRewardDockState
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onAction: (BottomRewardDockAction) -> Void

    private var mode: BottomRewardDockDisplayMode {
        guard state.displayMode != .hidden else {
            return .hidden
        }
        if isExpanded, state.hasPrimaryContent {
            return .expanded
        }
        return state.displayMode
    }

    var body: some View {
        Group {
            switch mode {
            case .hidden:
                EmptyView()
            case .handleOnly:
                handleOnly
            case .compact:
                dockContent(isExpanded: false)
            case .expanded:
                dockContent(isExpanded: true)
            }
        }
        .transition(GameBoardAnimation.dockTransition)
        .animation(GameBoardAnimation.dock, value: mode)
        .animation(GameBoardAnimation.dock, value: isExpanded)
        .animation(GameBoardAnimation.token, value: state.tokens.map(\.id))
        .animation(GameBoardAnimation.token, value: state.tokens.map(\.isSelected))
        .animation(GameBoardAnimation.quick, value: state.forwardControl?.isEnabled)
    }

    private var handleOnly: some View {
        Button {
            withAnimation(GameBoardAnimation.dock) {
                onToggleExpanded()
            }
        } label: {
            Capsule()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 64, height: 6)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.title)
    }

    private func dockContent(isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 8) {
            Button {
                withAnimation(GameBoardAnimation.dock) {
                    onToggleExpanded()
                }
            } label: {
                HStack(spacing: 10) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.45))
                        .frame(width: 54, height: 5)
                    Text(state.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let forwardControl = state.forwardControl {
                        Text(forwardControl.title)
                            .font(.headline.weight(.black))
                            .foregroundStyle(forwardControl.isEnabled ? Color.accentColor : Color.secondary)
                            .scaleEffect(forwardControl.isEnabled ? 1.06 : 1)
                            .animation(GameBoardAnimation.quick, value: forwardControl.isEnabled)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let sourceText = state.sourceText {
                sourceSummary(sourceText)
            }

            if !state.tokens.isEmpty {
                tokenStrip(isExpanded: isExpanded)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.instructionText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    ForEach(state.summaryLines, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let warningText = state.warningText {
                        Text(warningText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    if let fallbackReason = state.fallbackReason {
                        Text(fallbackReason)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if state.forwardControl != nil || state.backControl != nil {
                controlRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: min(isExpanded ? 760 : 620, 760), alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .transition(GameBoardAnimation.dockTransition)
    }

    @ViewBuilder
    private func sourceSummary(_ sourceText: String) -> some View {
        if let sourcePlayerId = state.sourcePlayerId {
            Button {
                onAction(.viewSourcePlayer(sourcePlayerId))
            } label: {
                HStack(spacing: 6) {
                    Text(sourceText)
                        .lineLimit(2)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.bold))
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(sourceText)，\(AppStrings.GameBoard.viewSourceBoard)")
        } else {
            Text(sourceText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func tokenStrip(isExpanded: Bool) -> some View {
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(state.tokens) { token in
                    Button {
                        withAnimation(GameBoardAnimation.token) {
                            onAction(token.action)
                        }
                    } label: {
                        tokenCard(token, isExpanded: isExpanded)
                    }
                    .buttonStyle(.plain)
                    .disabled(!token.isSelectable)
                    .id(token.id)
                    .transition(GameBoardAnimation.tokenTransition)
                }
            }
            .padding(.vertical, 1)
        }
        .frame(height: isExpanded ? 108 : 72)
    }

    private func tokenCard(_ token: BottomRewardDockToken, isExpanded: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(tokenIconBackground(token))
                    .frame(width: isExpanded ? 32 : 28, height: isExpanded ? 32 : 28)
                GameTokenIconView(icon: token.icon, size: isExpanded ? 23 : 20)
                if let countText = token.countText {
                    Text(countText)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(x: 10, y: -8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(token.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(isExpanded ? 2 : 1)
                Text(token.fallbackReason ?? token.subtitle)
                    .font(.caption2)
                    .foregroundStyle(token.isUnsupported ? .red : .secondary)
                    .lineLimit(isExpanded ? 2 : 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: isExpanded ? 162 : 132, height: isExpanded ? 94 : 62, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tokenBackground(token))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tokenBorder(token), lineWidth: token.isSelected ? 2 : 1)
        )
        .scaleEffect(token.isSelected ? GameBoardAnimation.dockSelectedTokenScale : 1)
        .opacity(token.isSelectable ? 1 : 0.65)
        .animation(GameBoardAnimation.token, value: token.isSelected)
        .animation(GameBoardAnimation.quick, value: token.isSelectable)
    }

    private var controlRow: some View {
        HStack(spacing: 10) {
            if let backControl = state.backControl {
                Button {
                    withAnimation(GameBoardAnimation.standard) {
                        onAction(backControl.action)
                    }
                } label: {
                    Text(backControl.title)
                        .font(.headline.weight(.black))
                        .frame(width: 54)
                }
                .buttonStyle(BottomDockControlButtonStyle(isProminent: false))
                .disabled(!backControl.isEnabled)
                .accessibilityLabel(backControl.accessibilityLabel)
            }

            Spacer(minLength: 0)

            if let forwardControl = state.forwardControl {
                Button {
                    withAnimation(GameBoardAnimation.standard) {
                        onAction(forwardControl.action)
                    }
                } label: {
                    Text(forwardControl.title)
                        .font(.headline.weight(.black))
                        .frame(minWidth: 86)
                }
                .buttonStyle(BottomDockControlButtonStyle(isProminent: true))
                .disabled(!forwardControl.isEnabled)
                .accessibilityLabel(forwardControl.accessibilityLabel)
            }
        }
    }

    private func tokenBackground(_ token: BottomRewardDockToken) -> Color {
        if token.isSelected {
            return Color.accentColor.opacity(0.2)
        }
        if token.isUnsupported {
            return Color.red.opacity(0.08)
        }
        return Color(.tertiarySystemBackground).opacity(0.92)
    }

    private func tokenBorder(_ token: BottomRewardDockToken) -> Color {
        if token.isSelected {
            return .accentColor
        }
        if token.isUnsupported {
            return .red.opacity(0.45)
        }
        return .secondary.opacity(0.22)
    }

    private func tokenIconBackground(_ token: BottomRewardDockToken) -> Color {
        token.isUnsupported ? .red.opacity(0.12) : .accentColor.opacity(0.14)
    }
}

private struct BottomDockControlButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, isProminent ? 14 : 8)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .shadow(
                color: isEnabled && isProminent ? Color.accentColor.opacity(configuration.isPressed ? 0.10 : 0.24) : .clear,
                radius: configuration.isPressed ? 2 : 6,
                y: configuration.isPressed ? 1 : 3
            )
            .opacity(isEnabled ? 1 : 0.48)
            .animation(GameBoardAnimation.quick, value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return Color(.systemBackground).opacity(0.55)
        }
        return isProminent ? Color.accentColor.opacity(0.92) : Color(.systemBackground).opacity(0.72)
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return .secondary
        }
        return isProminent ? .white : Color.accentColor
    }

    private var borderColor: Color {
        guard isEnabled else {
            return Color.secondary.opacity(0.18)
        }
        return Color.accentColor.opacity(isProminent ? 0 : 0.28)
    }
}

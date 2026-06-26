import SwiftUI

enum FloatingActionPairPlacement: String, Equatable {
    case boardLowerTrailing
}

enum FloatingActionContext: String, Equatable {
    case playFish
    case pendingChoice
    case rewardSelection
    case gameEnd
}

struct FloatingActionButtonState: Identifiable, Equatable {
    let id: String
    let title: String
    let action: BottomRewardDockAction
    let isEnabled: Bool
    let accessibilityLabel: String
}

struct FloatingActionPairState: Equatable {
    let leading: FloatingActionButtonState?
    let trailing: FloatingActionButtonState?
    let placement: FloatingActionPairPlacement
    let context: FloatingActionContext
    let buttonSize: CGFloat
    let spacing: CGFloat
    let minimumBottomClearance: CGFloat
    let minimumTrailingInset: CGFloat

    var usesMainBoardRightPanel: Bool { false }
    var avoidsHomeIndicator: Bool { minimumBottomClearance >= 160 }
    var avoidsHandArea: Bool { minimumBottomClearance >= 240 }
    var hasVisibleButton: Bool { leading != nil || trailing != nil }

    init(
        leading: FloatingActionButtonState?,
        trailing: FloatingActionButtonState?,
        placement: FloatingActionPairPlacement = .boardLowerTrailing,
        context: FloatingActionContext,
        buttonSize: CGFloat = 52,
        spacing: CGFloat = 14,
        minimumBottomClearance: CGFloat = 276,
        minimumTrailingInset: CGFloat = 36
    ) {
        self.leading = leading
        self.trailing = trailing
        self.placement = placement
        self.context = context
        self.buttonSize = buttonSize
        self.spacing = spacing
        self.minimumBottomClearance = minimumBottomClearance
        self.minimumTrailingInset = minimumTrailingInset
    }
}

struct FloatingActionPairView: View {
    let state: FloatingActionPairState
    let onAction: (BottomRewardDockAction) -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)
                HStack(spacing: state.spacing) {
                    Spacer(minLength: 0)
                    if let leading = state.leading {
                        floatingButton(leading, isProminent: false)
                    }
                    if let trailing = state.trailing {
                        floatingButton(trailing, isProminent: true)
                    }
                }
                .padding(.trailing, max(state.minimumTrailingInset, proxy.safeAreaInsets.trailing + 28))
                .padding(.bottom, max(state.minimumBottomClearance, proxy.safeAreaInsets.bottom + 244))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(state.hasVisibleButton)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .animation(GameBoardAnimation.standard, value: state)
    }

    private func floatingButton(
        _ button: FloatingActionButtonState,
        isProminent: Bool
    ) -> some View {
        Button {
            withAnimation(GameBoardAnimation.standard) {
                onAction(button.action)
            }
        } label: {
            Text(button.title)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .frame(width: state.buttonSize, height: state.buttonSize)
        }
        .buttonStyle(FloatingActionButtonStyle(isProminent: isProminent))
        .disabled(!button.isEnabled)
        .accessibilityLabel(button.accessibilityLabel)
    }
}

private struct FloatingActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.2)
            )
            .shadow(
                color: shadowColor(configuration: configuration),
                radius: configuration.isPressed ? 3 : 10,
                x: 0,
                y: configuration.isPressed ? 1 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(GameBoardAnimation.quick, value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return Color(.tertiarySystemBackground).opacity(0.78)
        }
        return isProminent
            ? Color.accentColor.opacity(0.96)
            : Color(.systemBackground).opacity(0.86)
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return .secondary
        }
        return isProminent ? .white : Color.accentColor
    }

    private var borderColor: Color {
        guard isEnabled else {
            return Color.secondary.opacity(0.22)
        }
        return isProminent ? Color.white.opacity(0.24) : Color.accentColor.opacity(0.35)
    }

    private func shadowColor(configuration: Configuration) -> Color {
        guard isEnabled else {
            return .clear
        }
        return isProminent
            ? Color.accentColor.opacity(configuration.isPressed ? 0.12 : 0.26)
            : Color.black.opacity(configuration.isPressed ? 0.08 : 0.16)
    }
}

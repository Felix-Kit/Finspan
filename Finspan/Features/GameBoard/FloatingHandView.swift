import SwiftUI
import UniformTypeIdentifiers

struct FloatingHandView: View {
    let viewState: HandViewState
    let onSelectCard: (CardID) -> Void
    let onBeginDrag: (CardID) -> Bool
    let onCancelSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let blockingMessage = viewState.blockingMessage {
                Text(blockingMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .shadow(color: .white.opacity(0.8), radius: 2)
            }

            if viewState.cards.isEmpty {
                Text(AppStrings.GameBoard.noActiveHand)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .bottomLeading) {
                        ForEach(viewState.cards) { card in
                            stackedCardButton(card)
                        }
                    }
                    .frame(
                        width: handStackWidth,
                        height: viewState.pulledOutCardId == nil ? 164 : 252,
                        alignment: .bottomLeading
                    )
                    .padding(.horizontal, 18)
                }
                .scrollClipDisabled()
            }
        }
        .padding(.bottom, -46)
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: -2)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: viewState.pulledOutCardId)
    }

    private var handStackWidth: CGFloat {
        guard let lastCard = viewState.cards.last else {
            return 0
        }
        let trailingWidth: CGFloat = lastCard.isPulledOutFromStack ? 210 : 172
        return CGFloat(lastCard.stackOffsetX) + trailingWidth
    }

    @ViewBuilder
    private func stackedCardButton(_ card: HandCardViewState) -> some View {
        let button = Button {
            onSelectCard(card.cardId)
        } label: {
            HandStackCardView(card: card)
        }
        .buttonStyle(.plain)
        .disabled(!viewState.canSelectCards)
        .offset(x: card.stackOffsetX, y: card.stackOffsetY)
        .zIndex(card.stackZIndex)

        if viewState.canSelectCards {
            button.onDrag {
                _ = onBeginDrag(card.cardId)
                return NSItemProvider(object: card.cardId as NSString)
            }
        } else {
            button
        }
    }
}

struct HandStackCardView: View {
    let card: HandCardViewState

    var body: some View {
        VStack(alignment: .leading, spacing: card.isPulledOutFromStack ? 10 : 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.costSummaryText)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)

                    Text(card.shortName)
                        .font(card.isPulledOutFromStack ? .headline.weight(.bold) : .callout.weight(.bold))
                        .lineLimit(card.isPulledOutFromStack ? 2 : 1)
                }

                Spacer(minLength: 0)

                Text("\(card.printedPoints)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(scoreColor))
            }

            if card.isPulledOutFromStack {
                expandedContent
            } else {
                compactContent
            }
        }
        .padding(12)
        .frame(width: card.isPulledOutFromStack ? 180 : 148, height: card.isPulledOutFromStack ? 244 : 196, alignment: .topLeading)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(discardOverlay)
        .overlay(alignment: .topTrailing) {
            if let marker = card.overlayMarkerText {
                Text(marker)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.red))
                    .offset(x: 5, y: -5)
            }
        }
        .opacity(card.highlightStyle == .unavailable ? 0.74 : 1)
        .shadow(color: shadowColor, radius: card.isPulledOutFromStack ? 16 : 8, x: 0, y: card.isPulledOutFromStack ? 8 : 4)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.placementSummaryText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusColor)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            infoRow(AppStrings.GameBoard.costs, card.costSummaryText)
            infoRow(AppStrings.GameBoard.length, card.lengthText)
            infoRow(AppStrings.GameBoard.allowedZones, card.placementSummaryText)
            infoRow(AppStrings.GameBoard.requiredDiveSite, card.requiredDiveSiteText)
            infoRow(AppStrings.GameBoard.abilitySummary, card.abilitySummaryText)

            Spacer(minLength: 0)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(2)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundColor)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: card.isPulledOutFromStack || card.isPlayable || card.isDiscardPaymentSelectable ? 2 : 1)
            .shadow(color: glowColor, radius: card.isPlayable ? 5 : 0)
    }

    @ViewBuilder
    private var discardOverlay: some View {
        if card.isSelectedForDiscardPayment {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.18))
        }
    }

    private var backgroundColor: Color {
        if card.isSelectedForDiscardPayment {
            return Color(red: 0.98, green: 0.89, blue: 0.84)
        }
        return Color(red: 0.96, green: 0.93, blue: 0.82)
    }

    private var borderColor: Color {
        if card.isSelectedForDiscardPayment {
            return .red
        }
        if card.isDiscardPaymentSelectable {
            return .orange
        }
        switch card.highlightStyle {
        case .selected:
            return .accentColor
        case .playable:
            return .green
        case .unavailable:
            return .white.opacity(0.72)
        }
    }

    private var statusColor: Color {
        if card.isSelectedForDiscardPayment {
            return .red
        }
        if card.isDiscardPaymentSelectable {
            return .orange
        }
        return card.isPlayable ? .green : .secondary
    }

    private var statusText: String {
        if card.isSelectedForDiscardPayment {
            return AppStrings.GameBoard.discardPaymentSelected
        }
        if card.isDiscardPaymentSelectable {
            return AppStrings.GameBoard.discardPaymentSelectable
        }
        return card.isPlayable ? AppStrings.GameBoard.playable : (card.unavailableReasonText ?? AppStrings.GameBoard.notPlayable)
    }

    private var scoreColor: Color {
        card.isPulledOutFromStack ? .accentColor : .blue
    }

    private var glowColor: Color {
        card.isPlayable ? .green.opacity(0.36) : .clear
    }

    private var shadowColor: Color {
        card.isPulledOutFromStack ? .black.opacity(0.24) : .black.opacity(0.16)
    }
}

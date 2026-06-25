import SwiftUI

struct FloatingHandView: View {
    let viewState: HandViewState
    let onSelectCard: (CardID) -> Void
    let onBeginDrag: (CardID) -> Bool
    let onDragChanged: (CardID, CGPoint) -> Void
    let onDropOnBoard: (CardID, CGPoint) -> Bool
    let onCancelSelection: () -> Void

    @State private var activeDragCardId: CardID?
    @State private var activeDragTranslation: CGSize = .zero
    @State private var invalidFeedbackCardId: CardID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let perspectiveMessage = viewState.perspectiveMessage {
                Text(perspectiveMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 18)
                    .shadow(color: .white.opacity(0.8), radius: 2)
            }

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
                    HStack {
                        Spacer(minLength: 0)
                        ZStack(alignment: .bottomLeading) {
                            ForEach(viewState.cards) { card in
                                stackedCardButton(card)
                            }
                        }
                        .frame(
                            width: handStackWidth,
                            height: 252,
                            alignment: .bottomLeading
                        )
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                }
                .scrollClipDisabled()
            }
        }
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: -2)
        .animation(GameBoardAnimation.handSelection, value: viewState.pulledOutCardId)
        .animation(GameBoardAnimation.handReturn, value: activeDragCardId)
        .animation(GameBoardAnimation.quick, value: invalidFeedbackCardId)
    }

    private var handStackWidth: CGFloat {
        guard let lastCard = viewState.cards.last else {
            return 0
        }
        let trailingWidth = CGFloat(lastCard.cardWidth) + 24
        return CGFloat(lastCard.stackOffsetX) + trailingWidth
    }

    @ViewBuilder
    private func stackedCardButton(_ card: HandCardViewState) -> some View {
        let isDragging = activeDragCardId == card.cardId
        let isShowingInvalidFeedback = invalidFeedbackCardId == card.cardId
        HandStackCardView(
            card: card,
            isDragging: isDragging,
            isShowingInvalidFeedback: isShowingInvalidFeedback
        )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                guard viewState.canSelectCards else {
                    triggerInvalidFeedback(for: card.cardId)
                    return
                }
                withAnimation(GameBoardAnimation.handSelection) {
                    onSelectCard(card.cardId)
                }
            }
            .gesture(dragGesture(for: card))
            .offset(
                x: CGFloat(card.stackOffsetX) + activeDragOffset(for: card).width + invalidFeedbackOffset(for: card),
                y: CGFloat(card.stackOffsetY) + activeDragOffset(for: card).height + dragLiftOffset(for: card)
            )
            .zIndex(isDragging ? 2_000 : card.stackZIndex)
    }

    private func dragGesture(for card: HandCardViewState) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                guard viewState.canSelectCards else {
                    triggerInvalidFeedback(for: card.cardId)
                    return
                }
                if activeDragCardId == nil {
                    guard onBeginDrag(card.cardId) else {
                        triggerInvalidFeedback(for: card.cardId)
                        return
                    }
                    withAnimation(GameBoardAnimation.handSelection) {
                        activeDragCardId = card.cardId
                    }
                }
                guard activeDragCardId == card.cardId else {
                    return
                }
                activeDragTranslation = value.translation
                onDragChanged(card.cardId, value.location)
            }
            .onEnded { value in
                guard activeDragCardId == card.cardId else {
                    resetActiveDrag()
                    return
                }
                let didDrop = onDropOnBoard(card.cardId, value.location)
                withAnimation(GameBoardAnimation.handReturn) {
                    resetActiveDrag()
                }
                if !didDrop {
                    triggerInvalidFeedback(for: card.cardId)
                }
            }
    }

    private func activeDragOffset(for card: HandCardViewState) -> CGSize {
        activeDragCardId == card.cardId ? activeDragTranslation : .zero
    }

    private func dragLiftOffset(for card: HandCardViewState) -> CGFloat {
        activeDragCardId == card.cardId ? -10 : 0
    }

    private func invalidFeedbackOffset(for card: HandCardViewState) -> CGFloat {
        invalidFeedbackCardId == card.cardId ? -GameBoardAnimation.invalidCardNudge : 0
    }

    private func resetActiveDrag() {
        activeDragCardId = nil
        activeDragTranslation = .zero
    }

    private func triggerInvalidFeedback(for cardId: CardID) {
        withAnimation(GameBoardAnimation.quick) {
            invalidFeedbackCardId = cardId
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + GameBoardAnimation.Duration.quick) {
            guard invalidFeedbackCardId == cardId else {
                return
            }
            withAnimation(GameBoardAnimation.quick) {
                invalidFeedbackCardId = nil
            }
        }
    }
}

struct HandStackCardView: View {
    let card: HandCardViewState
    let isDragging: Bool
    let isShowingInvalidFeedback: Bool

    var body: some View {
        FishCardFaceView(viewState: card.cardFace)
        .frame(width: CGFloat(card.cardWidth), height: CGFloat(card.cardHeight), alignment: .topLeading)
        .scaleEffect(cardScale)
        .overlay(cardBorder)
        .overlay(discardOverlay)
        .overlay(alignment: .bottomLeading) {
            Text(statusText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground).opacity(0.86))
                )
                .padding(6)
        }
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
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
        .animation(GameBoardAnimation.handSelection, value: card.isPulledOutFromStack)
        .animation(GameBoardAnimation.handSelection, value: isDragging)
        .animation(GameBoardAnimation.quick, value: isShowingInvalidFeedback)
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

    private var glowColor: Color {
        card.isPlayable ? .green.opacity(0.36) : .clear
    }

    private var shadowColor: Color {
        if isDragging {
            return .black.opacity(0.30)
        }
        return card.isPulledOutFromStack ? .black.opacity(0.24) : .black.opacity(0.16)
    }

    private var shadowRadius: CGFloat {
        if isDragging {
            return 20
        }
        return card.isPulledOutFromStack ? 16 : 8
    }

    private var shadowYOffset: CGFloat {
        if isDragging {
            return 10
        }
        return card.isPulledOutFromStack ? 8 : 4
    }

    private var cardScale: CGFloat {
        let baseScale = CGFloat(card.scale)
        if isDragging {
            return baseScale * GameBoardAnimation.draggingHandCardScale
        }
        if card.isPulledOutFromStack {
            return baseScale * GameBoardAnimation.selectedHandCardScale
        }
        if isShowingInvalidFeedback {
            return baseScale * 0.985
        }
        return baseScale
    }
}

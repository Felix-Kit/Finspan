import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

private struct SlotFramePreferenceKey: PreferenceKey {
    static var defaultValue: [OceanSlotAddress: CGRect] = [:]

    static func reduce(
        value: inout [OceanSlotAddress: CGRect],
        nextValue: () -> [OceanSlotAddress: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private enum BoardSlotPresentation {
    case legacyGrid
    case boardCanvas
}

struct GameBoardView: View {
    private static let boardLayout = BoardLayoutStore.load() ?? BoardLayout.placeholderBaseGame

    @StateObject var viewModel: GameBoardViewModel
    @State private var slotFrames: [OceanSlotAddress: CGRect] = [:]
    @State private var isShowingSettings = false
    @State private var isConfirmingDissolveCurrentGame = false
    @State private var isBottomRewardDockExpanded = false
    var onTemporarilyExitGameAndReturnHome: (() -> Void)?
    var onDissolveCurrentGameAndReturnHome: (() -> Void)?

    var body: some View {
        Group {
            if viewModel.state.phase == .gameEnded,
               let finalScoreViewState = viewModel.finalScoreViewState {
                NavigationStack {
                    FinalScoreView(viewState: finalScoreViewState)
                        .navigationTitle(AppStrings.GameBoard.finalScoreTitle)
                }
            } else {
                NavigationStack {
                    ZStack(alignment: .bottom) {
                        boardScreenBackground

                        VStack(alignment: .leading, spacing: 12) {
                            gameHud
                            boardStatusStrip

                            ZStack(alignment: .bottom) {
                                playFishPanel
                                    .frame(maxWidth: .infinity, alignment: .topLeading)

                                bottomCardDock
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                        BottomRewardDockView(
                            state: viewModel.bottomRewardDockState,
                            isExpanded: isBottomRewardDockExpanded,
                            onToggleExpanded: {
                                withAnimation(GameBoardAnimation.dock) {
                                    isBottomRewardDockExpanded.toggle()
                                }
                            },
                            onAction: { action in
                                withAnimation(GameBoardAnimation.standard) {
                                    viewModel.performBottomRewardDockAction(action)
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(GameBoardAnimation.dockTransition)
                        .animation(GameBoardAnimation.dock, value: viewModel.bottomRewardDockState.displayMode)
                        .animation(GameBoardAnimation.dock, value: isBottomRewardDockExpanded)
                        .zIndex(10)

                        if let floatingActionPairState = viewModel.floatingActionPairState {
                            FloatingActionPairView(
                                state: floatingActionPairState,
                                onAction: { action in
                                    withAnimation(GameBoardAnimation.standard) {
                                        viewModel.performBottomRewardDockAction(action)
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                            .zIndex(11)
                        }

                        if let toast = viewModel.hudToastViewState {
                            hudToastBanner(toast)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 10)
                                .padding(.horizontal, 18)
                                .allowsHitTesting(false)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if let detail = viewModel.discardPileDetailViewState {
                            discardPileDetailOverlay(detail)
                                .transition(GameBoardAnimation.overlayDimTransition)
                                .zIndex(20)
                        }

                        if let overlay = viewModel.bottomDockOverlayState,
                           overlay.route != .discardPileSelection {
                            bottomDockOverlay(overlay)
                                .id(overlay.route.rawValue)
                                .transition(GameBoardAnimation.overlayDimTransition)
                                .zIndex(21)
                        }
                    }
                    .animation(GameBoardAnimation.quick, value: viewModel.hudToastViewState?.id)
                    .animation(GameBoardAnimation.overlay, value: viewModel.discardPileDetailViewState != nil)
                    .animation(GameBoardAnimation.overlay, value: viewModel.bottomDockOverlayState?.route.rawValue)
                    .animation(GameBoardAnimation.standard, value: viewModel.floatingActionPairState)
                    .toolbar(.hidden, for: .navigationBar)
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                }
            }
        }
        .statusBarHidden(true)
        .confirmationDialog(
            viewModel.settingsMenuViewState.title,
            isPresented: $isShowingSettings,
            titleVisibility: .visible
        ) {
            Button(viewModel.settingsMenuViewState.temporarilyExitGameAndReturnHomeText) {
                onTemporarilyExitGameAndReturnHome?()
            }
            Button(viewModel.settingsMenuViewState.dissolveCurrentGameAndReturnHomeText, role: .destructive) {
                isConfirmingDissolveCurrentGame = true
            }
            Button(viewModel.settingsMenuViewState.cancelText, role: .cancel) {}
        }
        .confirmationDialog(
            viewModel.settingsMenuViewState.dissolveConfirmationTitle,
            isPresented: $isConfirmingDissolveCurrentGame,
            titleVisibility: .visible
        ) {
            Button(viewModel.settingsMenuViewState.dissolveCurrentGameAndReturnHomeText, role: .destructive) {
                onDissolveCurrentGameAndReturnHome?()
            }
            Button(viewModel.settingsMenuViewState.cancelText, role: .cancel) {}
        } message: {
            Text(viewModel.settingsMenuViewState.dissolveConfirmationMessage)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.isEventLogPresented },
                set: { isPresented in
                    if isPresented {
                        viewModel.showEventLog()
                    } else {
                        viewModel.hideEventLog()
                    }
                }
            )
        ) {
            NavigationStack {
                eventLogPanel
                    .padding(20)
                    .navigationTitle(AppStrings.GameBoard.eventLog)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppStrings.GameBoard.cancel) {
                                viewModel.hideEventLog()
                            }
                        }
                    }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.weeklyGoalDetailViewState != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissWeeklyGoalDetail()
                    }
                }
            )
        ) {
            if let detail = viewModel.weeklyGoalDetailViewState {
                NavigationStack {
                    weeklyGoalDetailPanel(detail)
                        .padding(20)
                        .navigationTitle(detail.title)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(AppStrings.GameBoard.cancel) {
                                    viewModel.dismissWeeklyGoalDetail()
                                }
                            }
                        }
                }
            }
        }
        .onPreferenceChange(SlotFramePreferenceKey.self) { frames in
            slotFrames = frames
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private var boardScreenBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.035, green: 0.12, blue: 0.18),
                Color(red: 0.04, green: 0.22, blue: 0.30),
                Color(red: 0.06, green: 0.09, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.18),
                    Color.clear,
                    Color.indigo.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }

    private var gameHud: some View {
        let hud = viewModel.gameHudViewState
        return HStack(alignment: .top, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.headline.weight(.semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(hud.leftControls.settingsButtonText)

                Button {
                    viewModel.showEventLog()
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.headline.weight(.semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .disabled(!hud.leftControls.canShowLog)
                .accessibilityLabel(hud.leftControls.logButtonText)
            }

            VStack(spacing: 5) {
                playerHud(hud.playerHud)
            }
            .frame(maxWidth: .infinity)

            compactResourceHUD(hud.compactResourceHUD)

            weeklyGoalBoxes(hud.weeklyGoalHud)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private func playerHud(_ viewState: TopPlayerHudViewState) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                ForEach(viewState.players) { player in
                    Button {
                        withAnimation(GameBoardAnimation.boardPerspective) {
                            viewModel.selectPlayerAvatar(player.playerId)
                        }
                    } label: {
                        VStack(spacing: 2) {
                            ZStack(alignment: .bottomTrailing) {
                                Text(player.avatarText)
                                    .font(player.isActive ? .callout.weight(.black) : .caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: player.isActive ? 38 : 32, height: player.isActive ? 38 : 32)
                                    .background(Circle().fill(avatarColor(player.colorName)))
                                    .overlay(
                                        Circle()
                                            .stroke(player.isViewing ? Color.accentColor : Color.white.opacity(0.7), lineWidth: player.isViewing ? 3 : 1.5)
                                    )
                                    .shadow(color: player.isActive ? Color.yellow.opacity(0.28) : .clear, radius: 5)

                                if player.isActive {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: 10, height: 10)
                                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                                }
                            }

                            Text(player.displayName)
                                .font(.caption2.weight(player.isViewing ? .black : .semibold))
                                .foregroundStyle(player.isViewing ? .primary : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isViewing ? "\(player.displayName)，\(AppStrings.GameBoard.viewing)" : player.displayName)
                }
            }

            if let message = viewState.perspectiveMessage {
                HStack(spacing: 8) {
                    Text(message)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button(viewState.returnToLocalPlayerText) {
                        withAnimation(GameBoardAnimation.boardPerspective) {
                            viewModel.returnToLocalPlayerBoard()
                        }
                    }
                    .font(.caption2.weight(.bold))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(.tertiarySystemBackground).opacity(0.92)))
    }

    private func compactResourceHUD(_ viewState: CompactResourceHUDState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewState.entries) { entry in
                    HStack(spacing: 4) {
                        GameTokenIconView(icon: entry.icon, size: 18)
                        Text(entry.countText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemBackground).opacity(0.92))
                    )
                    .accessibilityLabel("\(entry.title) \(entry.count)")
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(maxWidth: 360)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewState.accessibilityText)
    }

    private func weeklyGoalBoxes(_ viewState: WeeklyGoalHudViewState) -> some View {
        HStack(spacing: 6) {
            ForEach(viewState.boxes) { box in
                Button {
                    viewModel.selectWeeklyGoalBox(box.index)
                } label: {
                    ZStack(alignment: .topLeading) {
                        HStack(spacing: 2) {
                            ForEach(Array(box.icons.prefix(2).enumerated()), id: \.offset) { _, icon in
                                GameTokenIconView(icon: icon, size: 19)
                            }
                        }
                        .scaleEffect(box.iconScale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Text("\(box.index)")
                            .font(.system(size: 8, weight: .black))
                            .padding(4)

                        VStack {
                            Spacer()
                            HStack {
                                if box.isCompleted {
                                    Text("已")
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                                Text(box.pointsText)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 8, weight: .black))
                            .padding(4)
                        }
                    }
                    .frame(width: 58, height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(box.isGameEndBox ? Color.indigo.opacity(0.18) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(box.isCurrent ? Color.yellow : Color.secondary.opacity(0.28), lineWidth: box.isCurrent ? 3 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(box.weekLabel)，\(box.shortDescription)")
            }
        }
    }

    private var topBar: some View {
        let state = viewModel.topBarViewState
        return HStack(spacing: 12) {
            topBarItem(state.weekText, systemImage: "calendar")
            topBarDivider
            topBarItem(state.activePlayerText, systemImage: "person.crop.circle")
            topBarDivider
            topBarItem(state.diverText, systemImage: "figure.pool.swim")
            topBarDivider
            topBarItem(state.resourceSummaryText, systemImage: "circle.hexagongrid.fill")
            Spacer(minLength: 8)
            topBarItem(state.playerCountText, systemImage: "person.2")
            Button {
            } label: {
                Label(state.logButtonText, systemImage: "list.bullet.rectangle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .disabled(!state.canShowLog)
        }
        .font(.callout.weight(.medium))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var topBarDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 16)
    }

    private func topBarItem(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.primary)
    }

    private func slotAddress(at globalLocation: CGPoint) -> OceanSlotAddress? {
        slotFrames.first { _, frame in
            frame.contains(globalLocation)
        }?.key
    }

    private var turnPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.GameBoard.turn)
                .font(.title2.weight(.semibold))

            infoRow(AppStrings.GameBoard.currentWeek, viewModel.currentWeekText)
            infoRow(AppStrings.GameBoard.currentTurn, viewModel.currentTurnText)
            infoRow(AppStrings.GameBoard.activePlayer, viewModel.activePlayerName)
            infoRow(AppStrings.GameBoard.phase, AppStrings.phaseName(viewModel.state.phase))

            if let prompt = viewModel.mainActionPrompt {
                Text(prompt)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(viewModel.hasBlockingPendingChoices ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            errorPanel

            Spacer(minLength: 0)
        }
    }

    private var errorPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppStrings.GameBoard.errorArea)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(AppStrings.GameBoard.noError)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playFishPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                oceanPanel
            }
            .padding(.bottom, 230)
        }
    }

    private var bottomCardDock: some View {
        ZStack(alignment: .bottom) {
            bottomHandBackdrop
                .allowsHitTesting(false)

            FloatingHandView(
                viewState: viewModel.handViewState,
                onSelectCard: { cardId in
                    viewModel.selectHandCard(cardId)
                },
                onBeginDrag: { cardId in
                    viewModel.beginDraggingHandCard(cardId)
                },
                onDragChanged: { _, location in
                    viewModel.updateDragTarget(slotAddress(at: location))
                },
                onDropOnBoard: { cardId, location in
                    guard let address = slotAddress(at: location) else {
                        viewModel.cancelHandCardDrag()
                        return false
                    }
                    return viewModel.dropHandCard(cardId, targetAddress: address)
                },
                onCancelSelection: {
                    viewModel.cancelPlayFishSelection()
                }
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            if !viewModel.discardPileViewState.isEmpty {
                discardPileEntry(viewModel.discardPileViewState)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 28)
                .padding(.bottom, 34)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(GameBoardAnimation.standard, value: viewModel.discardPileViewState.isEmpty)
    }

    private var bottomHandBackdrop: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.03, green: 0.18, blue: 0.25).opacity(0.46),
                    Color(red: 0.025, green: 0.10, blue: 0.17).opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 246)
        }
    }

    private func discardPileEntry(_ viewState: DiscardPileViewState) -> some View {
        Group {
            if viewState.isEmpty {
                EmptyView()
            } else {
                Button {
                    viewModel.showDiscardPile()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        discardPileStack(viewState)

                        Text(viewState.badgeText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor))
                            .padding(.top, 4)
                            .padding(.trailing, 2)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(viewState.title)，\(viewState.countText)")
            }
        }
    }

    private func discardPileStack(_ viewState: DiscardPileViewState) -> some View {
        let width: CGFloat = 82
        let height = width / CardRenderMetrics.cardAspectRatio
        return ZStack(alignment: .center) {
            ForEach(Array(viewState.topCards.enumerated()), id: \.offset) { index, card in
                FishCardFaceView(viewState: card)
                    .frame(width: width, height: height)
                    .rotationEffect(.degrees(Double(index - 1) * 0.8))
                    .offset(x: CGFloat(index) * 3, y: CGFloat(index) * -2)
                    .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
                    .zIndex(Double(index))
            }
        }
        .frame(width: width + 18, height: height + 12, alignment: .center)
    }

    private func discardPileDetailOverlay(_ detail: DiscardPileDetailViewState) -> some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(GameBoardAnimation.overlay) {
                        viewModel.hideDiscardPile()
                    }
                }
                .transition(GameBoardAnimation.overlayDimTransition)

            discardPileDetailPanel(detail)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .onTapGesture {}
                .transition(GameBoardAnimation.overlayPanelTransition)
        }
    }

    private func discardPileDetailPanel(_ detail: DiscardPileDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(detail.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail.countText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button(AppStrings.GameBoard.close) {
                    withAnimation(GameBoardAnimation.overlay) {
                        viewModel.hideDiscardPile()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            if let instructionText = detail.instructionText {
                Text(instructionText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
            }

            if detail.cards.isEmpty {
                ContentUnavailableView(
                    detail.emptyText,
                    systemImage: "tray"
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 12),
                            count: detail.maxCardsPerRow
                        ),
                        spacing: 12
                    ) {
                        ForEach(Array(detail.cards.enumerated()), id: \.element.cardId) { _, card in
                            FishCardFaceView(viewState: card)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(detail.selectedCardId == card.cardId ? 1.025 : 1)
                                .overlay {
                                    let isSelected = detail.selectedCardId == card.cardId
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            isSelected ? Color.yellow : Color.clear,
                                            lineWidth: isSelected ? 4 : 0
                                        )
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .onTapGesture {
                                    guard detail.mode == .recoverSelection,
                                          let cardId = card.cardId
                                    else {
                                        return
                                    }
                                    withAnimation(GameBoardAnimation.token) {
                                        viewModel.selectDiscardPileCard(cardId)
                                    }
                                }
                                .allowsHitTesting(detail.mode == .recoverSelection)
                                .transition(GameBoardAnimation.tokenTransition)
                        }
                    }
                    .padding(.vertical, 4)
                    .animation(GameBoardAnimation.token, value: detail.selectedCardId)
                }
            }

            if detail.mode == .recoverSelection {
                HStack(spacing: 12) {
                    Button(AppStrings.GameBoard.recoverSelectedDiscardCard) {
                        withAnimation(GameBoardAnimation.standard) {
                            viewModel.confirmRecoverSelectedDiscardCard()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!detail.canRecoverSelectedCard)

                    Button(AppStrings.GameBoard.drawInstead) {
                        withAnimation(GameBoardAnimation.standard) {
                            viewModel.drawInsteadFromDiscardSelection()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(!detail.showsDrawInsteadAction)

                    Button(AppStrings.GameBoard.cancel) {
                        withAnimation(GameBoardAnimation.overlay) {
                            viewModel.cancelDiscardPileSelection()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
        }
    }

    private func bottomDockOverlay(_ overlay: BottomDockOverlayState) -> some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(GameBoardAnimation.overlay) {
                        viewModel.dismissBottomDockOverlay()
                    }
                }
                .transition(GameBoardAnimation.overlayDimTransition)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(overlay.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(overlay.instructionText)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    Spacer()
                    Button(AppStrings.GameBoard.cancel) {
                        withAnimation(GameBoardAnimation.overlay) {
                            viewModel.dismissBottomDockOverlay()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }

                switch overlay.route {
                case .handCardPicker:
                    bottomDockHandPicker(overlay)
                case .debugFallback:
                    bottomDockDebugFallback(overlay)
                case .playFishStaging,
                     .reefTargetPicker,
                     .gameEndCandidate,
                     .discardPileSelection:
                    bottomDockDebugFallback(overlay)
                }
            }
            .padding(18)
            .frame(maxWidth: 860, maxHeight: 560, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .padding(.vertical, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture {}
            .transition(GameBoardAnimation.overlayPanelTransition)
        }
    }

    private func bottomDockHandPicker(_ overlay: BottomDockOverlayState) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(overlay.handCards) { card in
                    Button {
                        withAnimation(GameBoardAnimation.handSelection) {
                            viewModel.selectHandCard(card.cardId)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            FishCardFaceView(viewState: card.cardFace)
                                .frame(width: 132, height: 132 / CardRenderMetrics.cardAspectRatio)
                                .scaleEffect(card.isPlayable ? 1 : 0.985)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(card.isPlayable ? Color.green : Color.red.opacity(0.65), lineWidth: card.isPlayable ? 2 : 1)
                                }
                            Text(card.displayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(card.unavailableReasonText ?? card.placementSummaryText)
                                .font(.caption2)
                                .foregroundStyle(card.isPlayable ? Color.white.opacity(0.72) : Color.red.opacity(0.88))
                                .lineLimit(2)
                        }
                        .frame(width: 150, alignment: .topLeading)
                    }
                    .buttonStyle(.plain)
                    .disabled(!card.isPlayable)
                    .transition(GameBoardAnimation.tokenTransition)
                }
            }
            .padding(.vertical, 4)
            .animation(GameBoardAnimation.token, value: overlay.handCards.map(\.id))
        }
    }

    private func bottomDockDebugFallback(_ overlay: BottomDockOverlayState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(overlay.debugText ?? overlay.instructionText)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
            Text(AppStrings.GameBoard.chooseOption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weeklyAchievementPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.weeklyAchievementPanel)
                .font(.title2.weight(.semibold))

            if viewModel.weeklyAchievementResults.isEmpty {
                Text(AppStrings.GameBoard.noWeeklyAchievementResults)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.weeklyAchievementResults) { result in
                        weeklyAchievementRow(result)
                    }
                }
            }
        }
    }

    private func weeklyAchievementRow(_ result: WeeklyAchievementResultViewData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.title)
                .font(.headline)
                .lineLimit(2)
            Text(result.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private var boardStatusStrip: some View {
        if viewModel.boardInteractionPromptViewState != nil
            || viewModel.mainActionPrompt != nil
            || viewModel.errorMessage != nil {
            HStack(spacing: 10) {
                if let interactionPrompt = viewModel.boardInteractionPromptViewState {
                    Label(interactionPrompt.text, systemImage: "cursorarrow.click")
                        .foregroundStyle(Color.accentColor)
                } else if let prompt = viewModel.mainActionPrompt {
                    Label(prompt, systemImage: viewModel.hasBlockingPendingChoices ? "exclamationmark.circle" : "cursorarrow.click")
                        .foregroundStyle(viewModel.hasBlockingPendingChoices ? .red : .secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .font(.callout.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground).opacity(0.78))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var playerStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.players)
                .font(.title2.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(viewModel.players) { player in
                    playerRow(player)
                }
            }
        }
    }

    private var oceanPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.oceanSlots.isEmpty {
                ContentUnavailableView(
                    AppStrings.GameBoard.noOceanSlots,
                    systemImage: "square.grid.3x3"
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    diveActionBar

                    boardLayoutCanvas
                    .id(viewModel.viewingPlayerId ?? viewModel.activePlayerId ?? "no-viewing-player")
                    .transition(GameBoardAnimation.boardPerspectiveTransition)
                    .animation(GameBoardAnimation.boardPerspective, value: viewModel.viewingPlayerId)

                    Text(AppStrings.GameBoard.bottomBonus)
                        .font(.headline)

                    HStack(alignment: .top, spacing: 12) {
                        ForEach(viewModel.bottomAreas) { bottomArea in
                            bottomAreaPanel(bottomArea)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .id("bottom-\(viewModel.viewingPlayerId ?? viewModel.activePlayerId ?? "no-viewing-player")")
                    .transition(GameBoardAnimation.boardPerspectiveTransition)
                    .animation(GameBoardAnimation.boardPerspective, value: viewModel.viewingPlayerId)
                }
            }
        }
    }

    private var boardLayoutCanvas: some View {
        let layout = Self.boardLayout
        let showsCoralOverlay = viewModel.oceanColumns.contains { $0.coralReef != nil }
        let backgroundImage = layout.backgroundAssetName.flatMap {
            BoardImageAssetResolver.image(named: $0)
        }
        let coralOverlayImage = showsCoralOverlay
            ? layout.coralOverlayAssetName.flatMap { BoardImageAssetResolver.image(named: $0) }
            : nil
        let hasBoardArtwork = backgroundImage != nil
        return GeometryReader { proxy in
            let boardRect = BoardLayoutMapper.boardImageRect(
                in: proxy.size,
                imageAspectRatio: CGFloat(layout.imageAspectRatio)
            )
            ZStack(alignment: .topLeading) {
                boardBackground(
                    in: boardRect,
                    layout: layout,
                    backgroundImage: backgroundImage,
                    coralOverlayImage: coralOverlayImage
                )

                ForEach(viewModel.oceanSlots) { slot in
                    if let layoutSlot = layout.slot(id: BoardLayout.slotId(for: slot.address)) {
                        let hitRect = BoardLayoutMapper.mapBoardNormalizedRect(
                            layoutSlot.hitRect,
                            into: boardRect
                        )
                        let cardRect = BoardLayoutMapper.mapBoardNormalizedRect(
                            layoutSlot.cardRect,
                            into: boardRect
                        )
                        let highlightRect = BoardLayoutMapper.mapBoardNormalizedRect(
                            layoutSlot.highlightRect,
                            into: boardRect
                        )
                        let usesPrintedForageFish = hasBoardArtwork
                            && layout.includesPrintedForageFish == true
                        let usesSeparateResourceTokens = BoardSlotArtworkPolicy.shouldRenderSeparateResourceTokens(
                            kind: slot.cardFace.kind,
                            includesPrintedForageFish: usesPrintedForageFish
                        )

                        slotCanvasHighlight(slot, frame: highlightRect)
                        slotPanel(
                            slot,
                            presentation: .boardCanvas,
                            includesResourceTokenHitTargets: false,
                            usesPrintedForageFish: usesPrintedForageFish,
                            showsFallbackSlotOutline: !hasBoardArtwork
                        )
                            .frame(width: cardRect.width, height: cardRect.height)
                            .position(x: cardRect.midX, y: cardRect.midY)
                            .allowsHitTesting(false)
                        slotCanvasHitTarget(slot, frame: hitRect)
                        if usesSeparateResourceTokens, !slot.resourceTokens.isEmpty {
                            boardSlotResourceTokens(
                                slot,
                                layoutSlot: layoutSlot,
                                cardRect: cardRect,
                                boardRect: boardRect
                            )
                        } else if slot.resourceTokens.contains(where: \.isSelectable) {
                            cardResourceTokenHitTargets(slot)
                                .frame(width: cardRect.width, height: cardRect.height)
                                .position(x: cardRect.midX, y: cardRect.midY)
                        }
                    }
                }

                ForEach(viewModel.oceanColumns) { column in
                    if let coralReef = column.coralReef {
                        coralReefBadge(coralReef)
                            .frame(width: max(82, boardRect.width * 0.13))
                            .position(coralReefPosition(for: column, layout: layout, in: boardRect))
                    }
                }

                #if DEBUG
                if BoardLayoutCalibrationMode.isEnabled {
                    BoardLayoutCalibrationOverlay(layout: layout, showsLabels: true)
                }
                #endif
            }
        }
        .aspectRatio(CGFloat(layout.imageAspectRatio), contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func boardBackground(
        in boardRect: CGRect,
        layout: BoardLayout,
        backgroundImage: UIImage?,
        coralOverlayImage: UIImage?
    ) -> some View {
        ZStack {
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.20),
                                Color.blue.opacity(0.12),
                                Color.indigo.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            if let coralOverlayImage,
               let normalizedRect = layout.coralOverlayRect {
                let overlayRect = BoardLayoutMapper.mapBoardNormalizedRect(
                    normalizedRect,
                    into: CGRect(origin: .zero, size: boardRect.size)
                )
                Image(uiImage: coralOverlayImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: overlayRect.width, height: overlayRect.height)
                    .clipped()
                    .position(x: overlayRect.midX, y: overlayRect.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: boardRect.width, height: boardRect.height)
        .clipShape(RoundedRectangle(cornerRadius: max(12, boardRect.width * 0.014), style: .continuous))
        .offset(x: boardRect.minX, y: boardRect.minY)
    }

    private func slotCanvasHitTarget(
        _ slot: OceanSlotViewData,
        frame: CGRect
    ) -> some View {
        Color.clear
            .frame(width: frame.width, height: frame.height)
            .contentShape(Rectangle())
            .offset(x: frame.minX, y: frame.minY)
            .onTapGesture {
                viewModel.selectTargetSlot(slot.address)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SlotFramePreferenceKey.self,
                        value: [slot.address: proxy.frame(in: .global)]
                    )
                }
            )
    }

    @ViewBuilder
    private func slotCanvasHighlight(
        _ slot: OceanSlotViewData,
        frame: CGRect
    ) -> some View {
        if slot.isHighlightedByDiveQueue
            || slot.isHighlightedByRewardSelection
            || slot.isDropTarget
            || slot.isSelected {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(slotCanvasHighlightColor(slot))
                .blur(radius: 8)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false)
        }
    }

    private func slotCanvasHighlightColor(_ slot: OceanSlotViewData) -> Color {
        if slot.isHighlightedByDiveQueue {
            return Color.orange.opacity(0.30)
        }
        if slot.isHighlightedByRewardSelection {
            return Color.blue.opacity(0.24)
        }
        if slot.isDropTarget {
            return slot.isValidDropTarget ? Color.green.opacity(0.28) : Color.red.opacity(0.22)
        }
        if slot.isSelected {
            return Color.accentColor.opacity(0.24)
        }
        return .clear
    }

    private func coralReefPosition(
        for column: OceanDiveSiteColumnViewData,
        layout: BoardLayout,
        in boardRect: CGRect
    ) -> CGPoint {
        let address = OceanSlotAddress(
            playerId: "layout",
            diveSite: column.diveSite,
            rowIndex: 3
        )
        let point = layout.slot(id: BoardLayout.slotId(for: address))?.coralAnchor
            ?? BoardNormalizedPoint(x: 0.5, y: 0.525)
        return BoardLayoutMapper.mapBoardNormalizedPoint(point, into: boardRect)
    }

    private var diveActionBar: some View {
        let viewState = viewModel.diveActionBarViewState
        return VStack(alignment: .leading, spacing: 8) {
            Text(viewState.title)
                .font(.headline)

            HStack(alignment: .top, spacing: 14) {
                if viewState.buttons.count >= 3 {
                    diveActionButton(viewState.buttons[0])
                    diveActionButton(viewState.buttons[1])
                    diveActionButton(viewState.buttons[2])
                }
            }
        }
    }

    private func diveActionButton(_ buttonState: DiveActionButtonViewState) -> some View {
        VStack(spacing: 4) {
            Button {
                viewModel.submitDive(to: buttonState.diveSite)
            } label: {
                Label(buttonState.title, systemImage: "figure.pool.swim")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!buttonState.isEnabled)

            Text(buttonState.disabledReasonText ?? AppStrings.GameBoard.chooseDiveSite)
                .font(.caption2)
                .foregroundStyle(buttonState.isEnabled ? Color.secondary : Color.red)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func hudToastBanner(_ viewState: GameBoardToastViewState) -> some View {
        Text(viewState.text)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemBackground).opacity(0.92))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            )
            .frame(maxWidth: 280, alignment: .center)
    }

    private func weeklyGoalDetailPanel(_ detail: WeeklyGoalScoreboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(detail.sections) { section in
                    weeklyGoalScoreboardSection(section)
                }

                Text(detail.noteText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func weeklyGoalScoreboardSection(
        _ section: WeeklyGoalScoreboardSectionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(section.weekLabel)
                    .font(.headline.weight(.black))
                HStack(spacing: 4) {
                    ForEach(Array(section.icons.enumerated()), id: \.offset) { _, icon in
                        GameTokenIconView(icon: icon, size: 24)
                    }
                }
                Text(section.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(section.statusText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(weeklyGoalStatusColor(section.status))
            }

            Text(section.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let gameEndInfo = section.gameEndInfo {
                Text(gameEndInfo.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 9) {
                ForEach(section.playerScores) { score in
                    weeklyGoalPlayerScoreBar(score, status: section.status)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(section.isCurrent ? Color.green.opacity(0.10) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(section.isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: section.isSelected ? 2 : 1)
        )
    }

    private func weeklyGoalPlayerScoreBar(
        _ score: WeeklyGoalPlayerScoreBarState,
        status: WeeklyGoalScoreStatus
    ) -> some View {
        HStack(spacing: 9) {
            Text(score.avatarText)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(color(for: score.playerColor)))

            Text(score.playerName)
                .font(.caption.weight(score.isHighest ? .bold : .medium))
                .lineLimit(1)
                .frame(width: 74, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.14))
                    Capsule()
                        .fill(color(for: score.playerColor).opacity(status == .finalized ? 0.82 : 0.46))
                        .frame(width: max(score.totalPoints > 0 ? 5 : 0, proxy.size.width * score.widthRatio))
                }
            }
            .frame(height: 12)

            VStack(alignment: .trailing, spacing: 1) {
                Text(score.scoreText)
                    .font(.caption.weight(score.isHighest ? .black : .semibold))
                    .monospacedDigit()
                if score.highestBonusPoints > 0 {
                    Text(AppStrings.GameBoard.weeklyGoalHighestBonus)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 92, alignment: .trailing)
        }
    }

    private func weeklyGoalStatusColor(_ status: WeeklyGoalScoreStatus) -> Color {
        switch status {
        case .finalized:
            return .green
        case .currentProjection:
            return .blue
        case .futureProjection:
            return .secondary
        case .notImplemented:
            return .orange
        }
    }

    private func zoneSectionPanel(_ section: OceanZoneSectionViewData) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(section.title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(zoneForeground(section.zone))
                Rectangle()
                    .fill(zoneForeground(section.zone).opacity(0.35))
                    .frame(height: 1)
            }

            ForEach(section.slots) { slot in
                slotPanel(slot)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(zoneBackground(section.zone, isHighlighted: section.isHighlightedByDiveQueue))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    section.isHighlightedByDiveQueue ? zoneForeground(section.zone) : zoneForeground(section.zone).opacity(0.2),
                    lineWidth: section.isHighlightedByDiveQueue ? 2 : 1
                )
        )
    }

    private var paymentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.playFishPayment)
                .font(.title2.weight(.semibold))

            if let payment = viewModel.paymentProgressViewState {
                VStack(alignment: .leading, spacing: 10) {
                    paymentLine(AppStrings.GameBoard.playFishPaymentCard, payment.cardTitle, isComplete: true)
                    paymentLine(AppStrings.GameBoard.playFishPaymentTarget, payment.targetText, isComplete: payment.isTargetSelected)

                    if let discardProgress = payment.discardProgress {
                        Text(discardProgress.progressText)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(discardProgress.isComplete ? .green : .secondary)
                    }

                    ForEach(payment.resourceProgress) { progress in
                        Text(progress.progressText)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(progress.isComplete ? .green : .secondary)
                    }

                    if let blockingMessage = payment.blockingMessage {
                        Text(blockingMessage)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 10) {
                        Button {
                            viewModel.submitPlayFish()
                        } label: {
                            Label(AppStrings.GameBoard.confirmPlayFish, systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!payment.canConfirm)

                        Button {
                            viewModel.cancelPlayFishSelection()
                        } label: {
                            Label(AppStrings.GameBoard.cancelPlayFish, systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text(AppStrings.GameBoard.chooseMainAction)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var divePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.divePanel)
                .font(.title2.weight(.semibold))

            Text(AppStrings.GameBoard.chooseDiveSite)
                .font(.callout)
                .foregroundStyle(viewModel.isSelectingPlayFish ? .red : .secondary)

            if viewModel.isSelectingPlayFish {
                Text(AppStrings.GameBoard.finishOrCancelPlayFish)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.red)
            }

            if let diverWarning = viewModel.diverAvailabilityWarning {
                Text(diverWarning)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.red)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(viewModel.diveActionSites) { site in
                    Button {
                        viewModel.submitDive(to: site.diveSite)
                    } label: {
                        Label(site.title, systemImage: "figure.pool.swim")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canDive)
                }
            }
        }
    }

    private var pendingChoicePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.pendingChoicePanel)
                .font(.title2.weight(.semibold))

            if viewModel.pendingChoices.isEmpty {
                Text(AppStrings.GameBoard.noPendingChoices)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                if viewModel.hasBlockingPendingChoices {
                    Text(AppStrings.GameBoard.resolveCurrentRewardFirst)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.red)
                }

                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.pendingChoices) { choice in
                        pendingChoiceRow(choice)
                    }
                }
            }
        }
    }

    private var eventLogPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.GameBoard.eventLog)
                .font(.title2.weight(.semibold))

            if viewModel.eventLog.isEmpty {
                ContentUnavailableView(
                    AppStrings.GameBoard.noEvents,
                    systemImage: "list.bullet.rectangle",
                    description: Text(AppStrings.GameBoard.noEventsDescription)
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.eventLog.reversed(), id: \.sequenceNumber) { event in
                            Text(viewModel.eventSummary(event))
                                .font(.callout.monospacedDigit())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
        }
    }

    private func playerRow(_ player: RoomPlayer) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color(for: player.color))
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(player.displayName)
                        .font(.headline)

                    if player.playerId == viewModel.state.activePlayerId {
                        Label(AppStrings.GameBoard.active, systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }

                Text(player.playerId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppStrings.roleName(player.role))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(player.isConnected ? AppStrings.GameBoard.connected : AppStrings.GameBoard.disconnected)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(player.isConnected ? .primary : .secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(player.playerId == viewModel.state.activePlayerId ? Color.green.opacity(0.14) : Color(.secondarySystemBackground))
        )
    }

    private func paymentLine(_ label: String, _ value: String, isComplete: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(label)：")
                .font(.callout.weight(.semibold))
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(isComplete ? .green : .secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private func cardButton(_ card: GameBoardCardViewData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if card.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(card.subtitle)
                .font(.caption)
                .foregroundStyle(card.isDisabledByUI ? .red : .secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(card.isSelected ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(card.isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    private func slotPanel(
        _ slot: OceanSlotViewData,
        presentation: BoardSlotPresentation = .legacyGrid,
        includesResourceTokenHitTargets: Bool = true,
        usesPrintedForageFish: Bool = false,
        showsFallbackSlotOutline: Bool = false
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if slot.cardFace.kind == .empty {
                emptySlotPlaceholder(
                    slot,
                    presentation: presentation,
                    showsFallbackOutline: showsFallbackSlotOutline
                )
            } else if presentation == .boardCanvas,
                      !BoardSlotArtworkPolicy.shouldRenderCardFace(
                        kind: slot.cardFace.kind,
                        includesPrintedForageFish: usesPrintedForageFish
                      ) {
                Color.clear
                    .accessibilityLabel(slot.cardFace.displayName)
            } else {
                FishCardFaceView(viewState: slot.cardFace)
                if includesResourceTokenHitTargets {
                    cardResourceTokenHitTargets(slot)
                }
            }

            if shouldShowSlotChrome(for: slot, presentation: presentation) {
                VStack(alignment: .leading, spacing: 4) {
                    if presentation == .legacyGrid || shouldShowSlotTitle(for: slot) {
                        HStack(spacing: 5) {
                            Text(slot.title)
                                .font(.caption2.weight(.black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if slot.isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(.systemBackground).opacity(0.82)))
                    }

                    Spacer(minLength: 0)

                    if shouldShowSlotMessagePanel(for: slot, presentation: presentation) {
                        VStack(alignment: .leading, spacing: 3) {
                            if presentation == .legacyGrid || slot.isDropTarget || slot.isSelected {
                                Text(slot.playFishPreview.message)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(slot.playFishPreview.isSelectable ? .green : .secondary)
                                    .lineLimit(1)
                            }

                            if let highlightReasonText = slot.highlightReasonText {
                                Text(highlightReasonText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .lineLimit(1)
                            }

                            if let dropTargetReasonText = slot.dropTargetReasonText {
                                Text(dropTargetReasonText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(slot.isValidDropTarget ? .green : .red)
                                    .lineLimit(1)
                            }

                            if presentation == .legacyGrid,
                               let rewardSelectionReasonText = slot.rewardSelectionReasonText {
                                Text(rewardSelectionReasonText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                            }

                            if let readOnlyReasonText = slot.readOnlyReasonText {
                                Text(readOnlyReasonText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(.systemBackground).opacity(0.84))
                        )
                    }
                }
                .padding(presentation == .legacyGrid ? 6 : 4)
            }
        }
        .padding(presentation == .legacyGrid ? 10 : 0)
        .aspectRatio(slot.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if presentation == .legacyGrid {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(slotBackgroundColor(slot))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                }
            }
        )
        .overlay(
            Group {
                if presentation == .legacyGrid {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(slotBorderColor(slot), lineWidth: slot.isHighlightedByDiveQueue || slot.isDropTarget ? 2 : 1.5)
                }
            }
        )
        .scaleEffect(slot.isValidDropTarget ? 1.018 : 1)
        .shadow(
            color: slot.isValidDropTarget ? Color.green.opacity(0.18) : .clear,
            radius: slot.isValidDropTarget ? 7 : 0,
            y: slot.isValidDropTarget ? 3 : 0
        )
        .animation(GameBoardAnimation.quick, value: slot.isDropTarget)
        .animation(GameBoardAnimation.quick, value: slot.isValidDropTarget)
        .animation(GameBoardAnimation.quick, value: slot.isSelected)
        .background {
            if presentation == .legacyGrid {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SlotFramePreferenceKey.self,
                        value: [slot.address: proxy.frame(in: .global)]
                    )
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            if presentation == .legacyGrid {
                viewModel.selectTargetSlot(slot.address)
            }
        }
    }

    private func shouldShowSlotChrome(
        for slot: OceanSlotViewData,
        presentation: BoardSlotPresentation
    ) -> Bool {
        presentation == .legacyGrid
            || slot.isSelected
            || slot.isDropTarget
            || slot.isHighlightedByDiveQueue
            || slot.readOnlyReasonText != nil
    }

    private func shouldShowSlotTitle(for slot: OceanSlotViewData) -> Bool {
        slot.isSelected
            || slot.isDropTarget
            || slot.isHighlightedByDiveQueue
    }

    private func shouldShowSlotMessagePanel(
        for slot: OceanSlotViewData,
        presentation: BoardSlotPresentation
    ) -> Bool {
        presentation == .legacyGrid
            || slot.isSelected
            || slot.isDropTarget
            || slot.highlightReasonText != nil
            || slot.dropTargetReasonText != nil
            || (presentation == .legacyGrid && slot.rewardSelectionReasonText != nil)
            || slot.readOnlyReasonText != nil
    }

    private func cardResourceTokenHitTargets(_ slot: OceanSlotViewData) -> some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 100
            ZStack(alignment: .topLeading) {
                ForEach(
                    Array(slot.resourceTokens.prefix(CardRenderMetrics.BoardResourceTokenLayout.maxVisibleTokens).enumerated()),
                    id: \.element.id
                ) { offset, token in
                    let frame = CardRenderMetrics.BoardResourceTokenLayout.hitTargetFrame(at: offset)
                    Button {
                        viewModel.toggleResourcePayment(
                            address: token.address,
                            kind: token.kind,
                            tokenIndex: token.tokenIndex
                        )
                    } label: {
                        Color.clear
                            .frame(width: unit * frame.width, height: unit * frame.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!token.isSelectable)
                    .accessibilityLabel(token.title)
                    .accessibilityHint(token.unavailableReasonText ?? token.warningText ?? "")
                    .offset(
                        x: unit * frame.x,
                        y: unit * frame.y
                    )
                }
            }
        }
    }

    private func boardSlotResourceTokens(
        _ slot: OceanSlotViewData,
        layoutSlot: BoardLayoutSlot,
        cardRect: CGRect,
        boardRect: CGRect
    ) -> some View {
        let anchor = BoardLayoutMapper.mapBoardNormalizedPoint(
            layoutSlot.resourceAnchor,
            into: boardRect
        )
        return ZStack(alignment: .topLeading) {
            ForEach(
                Array(slot.resourceTokens.prefix(BoardSlotResourceTokenLayout.maxVisibleTokens).enumerated()),
                id: \.element.id
            ) { index, token in
                let frame = BoardSlotResourceTokenLayout.frame(
                    at: index,
                    anchor: anchor,
                    cardRect: cardRect
                )
                GameTokenIconView(
                    icon: token.icon,
                    size: frame.visualRect.width
                )
                .scaleEffect(token.isSelectedForPayment ? 1.10 : 1)
                .shadow(
                    color: token.isSelectedForPayment
                        ? Color.red.opacity(0.82)
                        : Color.black.opacity(0.20),
                    radius: token.isSelectedForPayment ? 3 : 1
                )
                .position(x: frame.visualRect.midX, y: frame.visualRect.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(GameBoardAnimation.tokenTransition)

                if token.isSelectable {
                    Button {
                        viewModel.toggleResourcePayment(
                            address: token.address,
                            kind: token.kind,
                            tokenIndex: token.tokenIndex
                        )
                    } label: {
                        Color.clear
                            .frame(width: frame.hitRect.width, height: frame.hitRect.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(token.title)
                    .accessibilityHint(token.unavailableReasonText ?? token.warningText ?? "")
                    .position(x: frame.hitRect.midX, y: frame.hitRect.midY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(GameBoardAnimation.token, value: slot.resourceTokens.map(\.id))
        .animation(GameBoardAnimation.quick, value: slot.resourceTokens.map(\.isSelectedForPayment))
    }

    private func emptySlotPlaceholder(
        _ slot: OceanSlotViewData,
        presentation: BoardSlotPresentation = .legacyGrid,
        showsFallbackOutline: Bool = false
    ) -> some View {
        Group {
            if presentation == .legacyGrid {
                RoundedRectangle(cornerRadius: 8)
                    .fill(slotBackgroundColor(slot).opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(slotBorderColor(slot).opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    )
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "square.dashed")
                                .font(.headline.weight(.semibold))
                            Text(AppStrings.GameBoard.empty)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        showsFallbackOutline
                            ? Color.white.opacity(0.035)
                            : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(slot.isValidDropTarget ? Color.green.opacity(0.12) : Color.clear)
                            .blur(radius: 2)
                    )
                    .overlay {
                        if showsFallbackOutline {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    Color.white.opacity(0.20),
                                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                                )
                        }
                    }
            }
        }
        .aspectRatio(slot.cardFace.aspectRatio, contentMode: .fit)
    }

    private func bottomAreaPanel(_ bottomArea: DiveSiteBottomAreaViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(bottomArea.diveSiteTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if bottomArea.isAlreadyReachedThisWeek {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(AppStrings.GameBoard.firstBottomBonus)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(bottomArea.bonusTitle)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let bonusDetailText = bottomArea.bonusDetailText {
                Text(bonusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(bottomArea.statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(bottomArea.isFirstBottomThisWeekAvailable ? .green : .secondary)

            if let highlightReasonText = bottomArea.highlightReasonText {
                Text(highlightReasonText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(bottomArea.isHighlightedByDiveQueue ? Color.orange.opacity(0.14) : Color(.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(bottomArea.isHighlightedByDiveQueue ? Color.orange : Color.secondary.opacity(0.2), lineWidth: bottomArea.isHighlightedByDiveQueue ? 2 : 1)
        )
    }

    private func coralReefBadge(_ reef: CoralReefViewState) -> some View {
        HStack(spacing: 4) {
            coralReefIcon(reef)
                .frame(width: 14, height: 14)

            Text(reef.progressText)
                .font(.caption2.weight(.black))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.systemBackground).opacity(0.78))
        )
        .shadow(color: coralReefColor(reef.diveSite).opacity(0.18), radius: 3, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reef.title) \(reef.progressText) \(reef.completionBonusText)")
    }

    private func coralReefIcon(_ reef: CoralReefViewState) -> some View {
        GameTokenIconView(icon: reef.icon, size: 16)
        .accessibilityHidden(true)
    }

    private func slotBackgroundColor(_ slot: OceanSlotViewData) -> Color {
        if slot.isHighlightedByDiveQueue {
            return Color.orange.opacity(0.14)
        }
        if slot.isHighlightedByRewardSelection {
            return Color.blue.opacity(0.12)
        }
        if slot.isDropTarget {
            return slot.isValidDropTarget ? Color.green.opacity(0.12) : Color.red.opacity(0.08)
        }
        if slot.isSelected {
            return Color.accentColor.opacity(0.16)
        }
        return Color(.secondarySystemBackground)
    }

    private func slotBorderColor(_ slot: OceanSlotViewData) -> Color {
        if slot.isHighlightedByDiveQueue {
            return .orange
        }
        if slot.isHighlightedByRewardSelection {
            return .blue
        }
        if slot.isDropTarget {
            return slot.isValidDropTarget ? .green : .red.opacity(0.55)
        }
        if slot.isSelected {
            return .accentColor
        }
        return .clear
    }

    private func zoneBackground(_ zone: OceanZone, isHighlighted: Bool) -> Color {
        let opacity = isHighlighted ? 0.22 : 0.1
        switch zone {
        case .sunlit:
            return Color.yellow.opacity(opacity)
        case .twilight:
            return Color.cyan.opacity(opacity)
        case .midnight:
            return Color.indigo.opacity(opacity)
        }
    }

    private func zoneForeground(_ zone: OceanZone) -> Color {
        switch zone {
        case .sunlit:
            return .orange
        case .twilight:
            return .cyan
        case .midnight:
            return .indigo
        }
    }

    private func coralReefColor(_ diveSite: DiveSite) -> Color {
        switch diveSite {
        case .blue:
            return .cyan
        case .purple:
            return .purple
        case .green:
            return .green
        }
    }

    private func resourceSourceSection(
        title: String,
        sources: [ResourceSourceViewData],
        action: @escaping (OceanSlotAddress) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                ForEach(sources) { source in
                    Button {
                        action(source.address)
                    } label: {
                        resourceSourceButton(source)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func resourceSourceButton(_ source: ResourceSourceViewData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(source.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if source.selectedCount > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text("\(AppStrings.GameBoard.sourceSelectedCount) \(source.selectedCount) / \(AppStrings.GameBoard.sourceAvailableCount) \(source.availableCount)")
                .font(.callout.weight(.medium))
                .foregroundStyle(source.selectedCount > 0 ? .primary : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(source.selectedCount > 0 ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(source.selectedCount > 0 ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    private func pendingChoiceRow(_ choice: PendingChoiceViewData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(choice.title)
                        .font(.headline)
                    Text(choice.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(choice.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(choice.canResolve ? .green : .secondary)
            }

            if let targetPrompt = choice.targetPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    Text(targetPrompt)
                        .font(.callout.weight(.semibold))

                    if let noTargetsText = choice.noTargetsText {
                        Text(noTargetsText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else if !choice.targets.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                            ForEach(choice.targets) { target in
                                Button {
                                    viewModel.resolvePendingChoice(choice.choiceId, target: target.address)
                                } label: {
                                    pendingChoiceTargetButton(target)
                                }
                                .buttonStyle(.plain)
                                .disabled(!target.isEnabled)
                            }
                        }
                    }

                    if !choice.cardTargets.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                            ForEach(choice.cardTargets) { target in
                                Button {
                                    viewModel.resolvePendingChoice(choice.choiceId, recoverCardId: target.cardId)
                                } label: {
                                    pendingChoiceCardTargetButton(target)
                                }
                                .buttonStyle(.plain)
                                .disabled(!target.isEnabled)
                            }
                        }
                    }

                    if !choice.moveTargets.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], spacing: 8) {
                            ForEach(choice.moveTargets) { target in
                                Button {
                                    viewModel.resolvePendingChoice(
                                        choice.choiceId,
                                        moveSource: target.source,
                                        target: target.target,
                                        kind: target.kind
                                    )
                                } label: {
                                    pendingChoiceMoveTargetButton(target)
                                }
                                .buttonStyle(.plain)
                                .disabled(!target.isEnabled)
                            }
                        }
                    }
                }
            }

            if !choice.progressLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(choice.progressLines, id: \.self) { line in
                        Text(line)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }
            }

            HStack(spacing: 10) {
                ForEach(choice.actions) { action in
                    if action.action == .skip {
                        Button {
                            viewModel.performPendingChoiceAction(action)
                        } label: {
                            Text(action.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!action.isEnabled)
                    } else {
                        Button {
                            viewModel.performPendingChoiceAction(action)
                        } label: {
                            Text(action.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!action.isEnabled)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func pendingChoiceTargetButton(_ target: PendingChoiceTargetViewData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(target.title)
                .font(.headline)
                .lineLimit(2)
            Text(target.subtitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("\(AppStrings.GameBoard.resources)：\(target.resourcesText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
        )
    }

    private func pendingChoiceCardTargetButton(_ target: PendingChoiceCardTargetViewData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(target.title)
                .font(.headline)
                .lineLimit(2)
            Text(target.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))
        )
    }

    private func pendingChoiceMoveTargetButton(_ target: PendingChoiceMoveTargetViewData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(target.title)
                .font(.headline)
                .lineLimit(3)
            Text(target.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))
        )
    }

    private func color(for playerColor: PlayerColor?) -> Color {
        switch playerColor {
        case .blue:
            return .blue
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .red:
            return .red
        case .purple:
            return .purple
        case nil:
            return .gray
        }
    }

    private func avatarColor(_ colorName: String?) -> Color {
        if colorName == AppStrings.colorName(.blue) {
            return .blue
        }
        if colorName == AppStrings.colorName(.green) {
            return .green
        }
        if colorName == AppStrings.colorName(.yellow) {
            return .yellow
        }
        if colorName == AppStrings.colorName(.red) {
            return .red
        }
        if colorName == AppStrings.colorName(.purple) {
            return .purple
        }
        return .accentColor
    }
}

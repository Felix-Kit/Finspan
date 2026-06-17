import SwiftUI

private struct SlotFramePreferenceKey: PreferenceKey {
    static var defaultValue: [OceanSlotAddress: CGRect] = [:]

    static func reduce(
        value: inout [OceanSlotAddress: CGRect],
        nextValue: () -> [OceanSlotAddress: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct GameBoardView: View {
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
                                withAnimation(.snappy(duration: 0.2)) {
                                    isBottomRewardDockExpanded.toggle()
                                }
                            },
                            onAction: { action in
                                viewModel.performBottomRewardDockAction(action)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .zIndex(10)

                        if let toast = viewModel.hudToastViewState {
                            hudToastBanner(toast)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 10)
                                .padding(.horizontal, 18)
                                .allowsHitTesting(false)
                        }

                        if let detail = viewModel.discardPileDetailViewState {
                            discardPileDetailOverlay(detail)
                                .zIndex(20)
                        }

                        if let overlay = viewModel.bottomDockOverlayState,
                           overlay.route != .discardPileSelection {
                            bottomDockOverlay(overlay)
                                .zIndex(21)
                        }
                    }
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
                        viewModel.selectPlayerAvatar(player.playerId)
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
                        viewModel.returnToLocalPlayerBoard()
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
                    VStack(spacing: 2) {
                        Text(box.iconText)
                            .font(.subheadline)
                        Text(box.title)
                            .font(.caption2.weight(.black))
                            .lineLimit(1)
                    }
                    .frame(width: box.isCurrent ? 62 : 54, height: box.isCurrent ? 52 : 46)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(box.isGameEndBox ? Color.indigo.opacity(0.18) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(box.isCurrent ? Color.yellow : Color.secondary.opacity(0.28), lineWidth: box.isCurrent ? 3 : 1)
                    )
                    .offset(y: box.isCurrent ? 4 : 0)
                }
                .buttonStyle(.plain)
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
            .padding(.bottom, 4)

            if !viewModel.discardPileViewState.isEmpty {
                HStack {
                    Spacer(minLength: 0)
                    discardPileEntry(viewModel.discardPileViewState)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 24)
                .padding(.bottom, 16)
            }
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
                    viewModel.hideDiscardPile()
                }

            discardPileDetailPanel(detail)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .onTapGesture {}
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
                    viewModel.hideDiscardPile()
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
                        ForEach(Array(detail.cards.enumerated()), id: \.offset) { _, card in
                            FishCardFaceView(viewState: card)
                                .frame(maxWidth: .infinity)
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
                                    viewModel.selectDiscardPileCard(cardId)
                                }
                                .allowsHitTesting(detail.mode == .recoverSelection)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if detail.mode == .recoverSelection {
                HStack(spacing: 12) {
                    Button(AppStrings.GameBoard.recoverSelectedDiscardCard) {
                        viewModel.confirmRecoverSelectedDiscardCard()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!detail.canRecoverSelectedCard)

                    Button(AppStrings.GameBoard.drawInstead) {
                        viewModel.drawInsteadFromDiscardSelection()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(!detail.showsDrawInsteadAction)

                    Button(AppStrings.GameBoard.cancel) {
                        viewModel.cancelDiscardPileSelection()
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
                    viewModel.dismissBottomDockOverlay()
                }

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
                        viewModel.dismissBottomDockOverlay()
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
        }
    }

    private func bottomDockHandPicker(_ overlay: BottomDockOverlayState) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(overlay.handCards) { card in
                    Button {
                        viewModel.selectHandCard(card.cardId)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            FishCardFaceView(viewState: card.cardFace)
                                .frame(width: 132, height: 132 / CardRenderMetrics.cardAspectRatio)
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
                }
            }
            .padding(.vertical, 4)
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

    private var boardStatusStrip: some View {
        HStack(spacing: 10) {
            if let prompt = viewModel.mainActionPrompt {
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
                .fill(Color(.tertiarySystemBackground))
        )
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

                    HStack(alignment: .top, spacing: 14) {
                        ForEach(viewModel.oceanColumns) { column in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(column.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let coralReef = column.coralReef {
                                    coralReefBadge(coralReef)
                                }

                                ForEach(column.zoneSections) { section in
                                    zoneSectionPanel(section)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
                        }
                    }

                    Text(AppStrings.GameBoard.bottomBonus)
                        .font(.headline)

                    HStack(alignment: .top, spacing: 12) {
                        ForEach(viewModel.bottomAreas) { bottomArea in
                            bottomAreaPanel(bottomArea)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
        }
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

    private func weeklyGoalDetailPanel(_ detail: WeeklyGoalDetailViewState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(detail.weeklyScoreItems) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(item.iconText)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.scoringText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.isCurrent ? .green : .secondary)
                        }

                        ForEach(item.playerScores) { score in
                            HStack {
                                Text(score.playerName)
                                Spacer()
                                Text(score.scoreText)
                                    .fontWeight(.semibold)
                            }
                            .font(.callout)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.isCurrent ? Color.green.opacity(0.12) : Color(.secondarySystemBackground))
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.gameEndInfo.title)
                        .font(.headline)
                    Text(detail.gameEndInfo.description)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail.gameEndInfo.noteText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.indigo.opacity(0.12))
                )

                Text(detail.noteText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
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

    private func slotPanel(_ slot: OceanSlotViewData) -> some View {
        ZStack(alignment: .topLeading) {
            if slot.cardFace.kind == .empty {
                emptySlotPlaceholder(slot)
            } else {
                FishCardFaceView(viewState: slot.cardFace)
            }

            VStack(alignment: .leading, spacing: 4) {
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

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.playFishPreview.message)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(slot.playFishPreview.isSelectable ? .green : .secondary)
                        .lineLimit(1)

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

                    if let rewardSelectionReasonText = slot.rewardSelectionReasonText {
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

                if !slot.resourceTokens.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 4)], alignment: .leading, spacing: 4) {
                        ForEach(slot.resourceTokens) { token in
                            Button {
                                viewModel.toggleResourcePayment(
                                    address: token.address,
                                    kind: token.kind,
                                    tokenIndex: token.tokenIndex
                                )
                            } label: {
                                resourceToken(token)
                            }
                            .buttonStyle(.plain)
                            .disabled(!token.isSelectable)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(6)
        }
        .padding(10)
        .aspectRatio(slot.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(slotBackgroundColor(slot))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(slotBorderColor(slot), lineWidth: slot.isHighlightedByDiveQueue || slot.isDropTarget ? 2 : 1.5)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SlotFramePreferenceKey.self,
                    value: [slot.address: proxy.frame(in: .global)]
                )
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            viewModel.selectTargetSlot(slot.address)
        }
    }

    private func resourceToken(_ token: SlotResourceTokenViewState) -> some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(resourceTokenBackgroundColor(token))
                    GameTokenIconView(icon: token.icon, size: 16)
                }
                .foregroundStyle(resourceTokenForegroundColor(token))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(
                        resourceTokenBorderColor(token),
                        lineWidth: token.isSelectedForPayment ? 2 : 1
                    )
                )

                if let marker = token.selectionMarkerText {
                    Text(marker)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 12, height: 12)
                        .background(Circle().fill(Color.red))
                        .offset(x: 3, y: -3)
                }
            }

            Text(token.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(token.isSelectable || token.isSelectedForPayment ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if token.isSelectedForPayment {
                Text(AppStrings.GameBoard.sourceSelectedCount)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else if let warning = token.warningText {
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else if let reason = token.unavailableReasonText {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(token.isSelectedForPayment ? Color.red.opacity(0.12) : Color(.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(token.isSelectedForPayment ? Color.red.opacity(0.65) : Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private func emptySlotPlaceholder(_ slot: OceanSlotViewData) -> some View {
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
        HStack(spacing: 8) {
            coralReefIcon(reef)
                .frame(width: 16, height: 16)

            Text(reef.progressText)
                .font(.caption.weight(.black))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(reef.completionBonusText)
                .font(.caption.weight(.black))
                .foregroundStyle(coralReefColor(reef.diveSite))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(coralReefColor(reef.diveSite).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(coralReefColor(reef.diveSite).opacity(0.32), lineWidth: 1)
        )
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

    private func resourceTokenBackgroundColor(_ token: SlotResourceTokenViewState) -> Color {
        if token.isSelectedForPayment {
            return .red.opacity(0.2)
        }
        if token.isSelectable {
            return .green.opacity(0.18)
        }
        if token.kind == .egg {
            return .yellow.opacity(0.22)
        }
        if token.kind == .young {
            return .cyan.opacity(0.16)
        }
        if token.kind == .school {
            return .blue.opacity(0.16)
        }
        return Color(.secondarySystemBackground)
    }

    private func resourceTokenBorderColor(_ token: SlotResourceTokenViewState) -> Color {
        if token.isSelectedForPayment {
            return .red
        }
        if token.isSelectable {
            return .green
        }
        return .secondary.opacity(0.25)
    }

    private func resourceTokenForegroundColor(_ token: SlotResourceTokenViewState) -> Color {
        if token.isSelectedForPayment {
            return .red
        }
        if token.isSelectable {
            return .green
        }
        return .primary
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

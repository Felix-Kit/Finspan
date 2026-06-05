import SwiftUI
import UniformTypeIdentifiers

struct GameBoardView: View {
    @StateObject var viewModel: GameBoardViewModel

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
                    ZStack(alignment: .bottomLeading) {
                        HStack(alignment: .top, spacing: 14) {
                            turnPanel
                                .frame(width: 220, alignment: .topLeading)

                            Divider()

                            playFishPanel
                                .frame(maxWidth: .infinity, alignment: .topLeading)

                            Divider()

                            eventLogPanel
                                .frame(width: 300, alignment: .topLeading)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)

                        FloatingHandView(
                            viewState: viewModel.handViewState,
                            onSelectCard: { cardId in
                                viewModel.selectHandCard(cardId)
                            },
                            onBeginDrag: { cardId in
                                viewModel.beginDraggingHandCard(cardId)
                            },
                            onCancelSelection: {
                                viewModel.cancelPlayFishSelection()
                            }
                        )
                        .background(Color.clear)
                    }
                    .navigationTitle(AppStrings.GameBoard.title)
                }
            }
        }
        .onAppear {
            viewModel.refresh()
        }
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
                playerStrip
                weeklyAchievementPanel
                oceanPanel
                paymentPanel
                divePanel
                pendingChoicePanel
            }
            .padding(.bottom, 230)
        }
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
            Text(AppStrings.GameBoard.ocean)
                .font(.title2.weight(.semibold))

            if viewModel.oceanSlots.isEmpty {
                ContentUnavailableView(
                    AppStrings.GameBoard.noOceanSlots,
                    systemImage: "square.grid.3x3"
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(viewModel.oceanColumns) { column in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(column.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(column.slots) { slot in
                                    slotPanel(slot)
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
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 7) {
                Button {
                    viewModel.selectTargetSlot(slot.address)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(slot.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Spacer()
                            if slot.isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        Text(slot.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(slot.isOccupied ? .secondary : .primary)
                            .lineLimit(2)

                        Text(slot.playFishPreview.message)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(slot.playFishPreview.isSelectable ? .green : .secondary)
                            .lineLimit(1)

                        if let highlightReasonText = slot.highlightReasonText {
                            Text(highlightReasonText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }

                        if let dropTargetReasonText = slot.dropTargetReasonText {
                            Text(dropTargetReasonText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(slot.isValidDropTarget ? .green : .red)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .disabled(!slot.playFishPreview.isSelectable)

                Spacer(minLength: 0)

                if slot.resourceTokens.isEmpty {
                    Text(AppStrings.GameBoard.noResources)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
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
                }
            }
            .padding(10)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
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
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            viewModel.dropHandCard(targetAddress: slot.address)
        }
    }

    private func resourceToken(_ token: SlotResourceTokenViewState) -> some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Text(token.iconText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(resourceTokenForegroundColor(token))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(resourceTokenBackgroundColor(token))
                    )
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

    private func slotBackgroundColor(_ slot: OceanSlotViewData) -> Color {
        if slot.isHighlightedByDiveQueue {
            return Color.orange.opacity(0.14)
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
        if slot.isDropTarget {
            return slot.isValidDropTarget ? .green : .red.opacity(0.55)
        }
        if slot.isSelected {
            return .accentColor
        }
        return .clear
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

            HStack(spacing: 10) {
                ForEach(choice.actions) { action in
                    if action.action == .skip {
                        Button {
                            viewModel.performPendingChoiceAction(action.action, for: choice.choiceId)
                        } label: {
                            Text(action.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!action.isEnabled)
                    } else {
                        Button {
                            viewModel.performPendingChoiceAction(action.action, for: choice.choiceId)
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
}

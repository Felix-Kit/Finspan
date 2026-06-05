import SwiftUI

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
                    HStack(alignment: .top, spacing: 20) {
                        turnPanel
                            .frame(width: 260, alignment: .topLeading)

                        Divider()

                        playFishPanel
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        Divider()

                        eventLogPanel
                            .frame(width: 360, alignment: .topLeading)
                    }
                    .padding(24)
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
                handPanel
                selectedFishCardPanel
                oceanPanel
                paymentPanel
                divePanel
                pendingChoicePanel

                Button {
                    viewModel.submitPlayFish()
                } label: {
                    Label(AppStrings.GameBoard.playFish, systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmitPlayFish)
            }
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

    private var handPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.hand)
                .font(.title2.weight(.semibold))

            if viewModel.handCards.isEmpty {
                ContentUnavailableView(
                    AppStrings.GameBoard.noActiveHand,
                    systemImage: "rectangle.stack"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.handCards) { card in
                        Button {
                            viewModel.selectCard(card.cardId)
                        } label: {
                            cardButton(card)
                        }
                        .buttonStyle(.plain)
                    }
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
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(viewModel.oceanColumns) { column in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(column.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(column.slots) { slot in
                                    slotPanel(slot)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
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

    @ViewBuilder
    private var selectedFishCardPanel: some View {
        if let card = viewModel.selectedFishCardDetails {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(AppStrings.GameBoard.selectedFishCard)
                        .font(.title2.weight(.semibold))

                    Spacer()

                    Button {
                        viewModel.cancelPlayFishSelection()
                    } label: {
                        Label(AppStrings.GameBoard.cancelPlayFishSelection, systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    selectedFishInfoRow(AppStrings.GameBoard.fishCardName, card.title)
                    selectedFishInfoRow(AppStrings.GameBoard.score, card.scoreText)
                    selectedFishInfoRow(AppStrings.GameBoard.length, card.lengthText)
                    selectedFishInfoRow(AppStrings.GameBoard.allowedZones, card.allowedZonesText)
                    selectedFishInfoRow(AppStrings.GameBoard.requiredDiveSite, card.requiredDiveSiteText)
                    selectedFishInfoRow(AppStrings.GameBoard.costs, card.costsText)
                }

                if let unsupportedText = card.unsupportedText {
                    Text("\(AppStrings.GameBoard.unsupportedItems)：\(unsupportedText)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var paymentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.actionPanel)
                .font(.title2.weight(.semibold))

            if let prompt = viewModel.selectedCardPaymentPrompt {
                Text(prompt)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(viewModel.selectedCardHasUnsupportedUICost ? .red : .secondary)
            }

            if !viewModel.resourcePaymentProgress.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppStrings.GameBoard.resourcePaymentProgress)
                        .font(.headline)

                    ForEach(viewModel.resourcePaymentProgress) { progress in
                        Text(progress.progressText)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(progress.isComplete ? .green : .secondary)
                    }
                }
            }

            if !viewModel.discardPaymentOptions.isEmpty {
                Text(AppStrings.GameBoard.chooseDiscardCards)
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.discardPaymentOptions) { card in
                        Button {
                            viewModel.toggleDiscardPaymentCard(card.cardId)
                        } label: {
                            cardButton(card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.selectTargetSlot(slot.address)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(slot.title)
                            .font(.headline)
                            .lineLimit(2)
                        Spacer()
                        if slot.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    Text(slot.subtitle)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(slot.isOccupied ? .secondary : .primary)
                        .lineLimit(2)

                    Text(slot.playFishPreview.message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(slot.playFishPreview.isSelectable ? .green : .secondary)
                        .lineLimit(1)

                    if let highlightReasonText = slot.highlightReasonText {
                        Text(highlightReasonText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .buttonStyle(.plain)
            .disabled(!slot.playFishPreview.isSelectable)

            if slot.resourceTokens.isEmpty {
                Text(AppStrings.GameBoard.noResources)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 6)], alignment: .leading, spacing: 6) {
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
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(slotBackgroundColor(slot))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(slotBorderColor(slot), lineWidth: slot.isHighlightedByDiveQueue ? 2 : 1.5)
        )
    }

    private func resourceToken(_ token: SlotResourceTokenViewState) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Text(token.iconText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(resourceTokenForegroundColor(token))
                    .frame(width: 26, height: 26)
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
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(Color.red))
                        .offset(x: 3, y: -3)
                }
            }

            Text(token.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(token.isSelectable || token.isSelectedForPayment ? .primary : .secondary)
                .lineLimit(1)

            if token.isSelectedForPayment {
                Text(AppStrings.GameBoard.sourceSelectedCount)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            } else if let warning = token.warningText {
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else if let reason = token.unavailableReasonText {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
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
        if slot.isSelected {
            return Color.accentColor.opacity(0.16)
        }
        return Color(.secondarySystemBackground)
    }

    private func slotBorderColor(_ slot: OceanSlotViewData) -> Color {
        if slot.isHighlightedByDiveQueue {
            return .orange
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

    private func selectedFishInfoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

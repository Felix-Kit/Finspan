import SwiftUI

struct GameBoardView: View {
    @StateObject var viewModel: GameBoardViewModel

    var body: some View {
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

            errorPanel

            Button {
                viewModel.endTurn()
            } label: {
                Label(AppStrings.GameBoard.endTurn, systemImage: "arrowshape.turn.up.right.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canEndTurn)

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
                handPanel
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.oceanSlots) { slot in
                        Button {
                            viewModel.selectTargetSlot(slot.address)
                        } label: {
                            slotButton(slot)
                        }
                        .buttonStyle(.plain)
                        .disabled(slot.isOccupied)
                    }
                }
            }
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

            if !viewModel.eggSourceOptions.isEmpty || !viewModel.youngSourceOptions.isEmpty {
                Text(AppStrings.GameBoard.anyResourceSourceHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
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

            if !viewModel.eggSourceOptions.isEmpty {
                resourceSourceSection(
                    title: AppStrings.GameBoard.chooseEggSources,
                    sources: viewModel.eggSourceOptions,
                    action: viewModel.toggleEggSource
                )
            }

            if !viewModel.youngSourceOptions.isEmpty {
                resourceSourceSection(
                    title: AppStrings.GameBoard.chooseYoungSources,
                    sources: viewModel.youngSourceOptions,
                    action: viewModel.toggleYoungSource
                )
            }
        }
    }

    private var divePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.divePanel)
                .font(.title2.weight(.semibold))

            Text(AppStrings.GameBoard.chooseDiveSite)
                .font(.callout)
                .foregroundStyle(.secondary)

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

    private func slotButton(_ slot: OceanSlotViewData) -> some View {
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

            Text("\(AppStrings.GameBoard.resources)：\(slot.resourcesText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(slot.isSelected ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(slot.isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .opacity(slot.isOccupied ? 0.58 : 1)
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(choice.title)
                    .font(.headline)
                Text(choice.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                viewModel.skipPendingChoice(choice.choiceId)
            } label: {
                Label(AppStrings.GameBoard.skipChoice, systemImage: "forward.end")
            }
            .buttonStyle(.bordered)
            .disabled(!choice.canSkip)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
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

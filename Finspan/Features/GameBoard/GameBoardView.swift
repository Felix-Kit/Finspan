import SwiftUI

struct GameBoardView: View {
    @StateObject var viewModel: GameBoardViewModel

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 24) {
                turnPanel
                    .frame(maxWidth: 320, alignment: .topLeading)

                Divider()

                playersPanel
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Divider()

                eventLogPanel
                    .frame(maxWidth: 420, alignment: .topLeading)
            }
            .padding(24)
            .navigationTitle("Finspan Game Board")
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private var turnPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Turn")
                .font(.title2.weight(.semibold))

            infoRow("Current Week", viewModel.currentWeekText)
            infoRow("Current Turn", viewModel.currentTurnText)
            infoRow("Active Player", viewModel.activePlayerName)
            infoRow("Phase", viewModel.state.phase.rawValue)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                viewModel.endTurn()
            } label: {
                Label("End Turn", systemImage: "arrowshape.turn.up.right.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canEndTurn)

            Spacer(minLength: 0)
        }
    }

    private var playersPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Players")
                .font(.title2.weight(.semibold))

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.players) { player in
                        playerRow(player)
                    }
                }
            }
        }
    }

    private var eventLogPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event Log")
                .font(.title2.weight(.semibold))

            if viewModel.eventLog.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Events will appear after room commands are accepted.")
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
                        Label("Active", systemImage: "play.fill")
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
                Text(player.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(player.isConnected ? "Connected" : "Disconnected")
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

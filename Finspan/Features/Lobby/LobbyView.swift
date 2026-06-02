import SwiftUI

struct LobbyView: View {
    @StateObject var viewModel: LobbyViewModel

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 24) {
                roomSummary
                    .frame(maxWidth: 340, alignment: .topLeading)

                Divider()

                playerList
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Divider()

                controls
                    .frame(maxWidth: 320, alignment: .topLeading)
            }
            .padding(24)
            .navigationTitle("Finspan Lobby")
        }
    }

    private var roomSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Room")
                .font(.title2.weight(.semibold))

            infoRow("Code", viewModel.roomCode)
            infoRow("Host", viewModel.hostName)
            infoRow("Status", viewModel.status)
            infoRow("Players", "\(viewModel.players.count)")

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var playerList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Players")
                .font(.title2.weight(.semibold))

            if viewModel.players.isEmpty {
                ContentUnavailableView(
                    "No Local Room",
                    systemImage: "person.2.slash",
                    description: Text("Create a local room to start testing the flow.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.players) { player in
                            Button {
                                viewModel.selectedPlayerId = player.playerId
                                viewModel.selectedColor = player.color ?? .blue
                            } label: {
                                playerRow(player)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.title2.weight(.semibold))

            Button {
                viewModel.createLocalRoom()
            } label: {
                Label("Create Local Room", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canCreateRoom)

            Button {
                viewModel.joinSimulatedPlayer()
            } label: {
                Label("Join Simulated Player", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canJoinPlayer)

            Divider()

            Picker("Active Player", selection: $viewModel.selectedPlayerId) {
                Text("None").tag(Optional<PlayerID>.none)
                ForEach(viewModel.players) { player in
                    Text(player.displayName).tag(Optional(player.playerId))
                }
            }
            .pickerStyle(.menu)

            Picker("Color", selection: $viewModel.selectedColor) {
                ForEach(PlayerColor.allCases, id: \.self) { color in
                    Text(color.rawValue.capitalized).tag(color)
                }
            }
            .pickerStyle(.segmented)

            Button {
                viewModel.chooseSelectedColor()
            } label: {
                Label("Choose Color", systemImage: "paintpalette")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedPlayerId == nil)

            Button {
                viewModel.toggleReadyForSelectedPlayer()
            } label: {
                Label("Toggle Ready", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedPlayerId == nil)

            Divider()

            Button {
                viewModel.startGameAsHost()
            } label: {
                Label("Host Start Game", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartGame)

            Spacer(minLength: 0)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
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
                    if player.role == .host {
                        Image(systemName: "crown")
                            .foregroundStyle(.yellow)
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
                Text(player.isReady ? "Ready" : "Not Ready")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(player.isReady ? .green : .secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.selectedPlayerId == player.playerId ? Color.accentColor.opacity(0.14) : Color(.secondarySystemBackground))
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

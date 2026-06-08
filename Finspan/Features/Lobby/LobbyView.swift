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
            .navigationTitle(AppStrings.Lobby.title)
        }
    }

    private var roomSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.Lobby.room)
                .font(.title2.weight(.semibold))

            infoRow(AppStrings.Lobby.code, viewModel.roomCode)
            infoRow(AppStrings.Lobby.host, viewModel.hostName)
            infoRow(AppStrings.Lobby.status, viewModel.status)
            infoRow(AppStrings.Lobby.players, "\(viewModel.players.count)")

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
            Text(AppStrings.Lobby.players)
                .font(.title2.weight(.semibold))

            if viewModel.players.isEmpty {
                ContentUnavailableView(
                    AppStrings.Lobby.noLocalRoom,
                    systemImage: "person.2.slash",
                    description: Text(AppStrings.Lobby.noLocalRoomDescription)
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
            Text(AppStrings.Lobby.actions)
                .font(.title2.weight(.semibold))

            Picker(AppStrings.Lobby.gameDataMode, selection: $viewModel.selectedGameDataMode) {
                ForEach(GameDataMode.allCases) { mode in
                    Text(AppStrings.gameDataModeName(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!viewModel.canCreateRoom)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppStrings.Lobby.expansions)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(AppStrings.Lobby.sharksAndReefsExpansion, isOn: $viewModel.isSharksAndReefsExpansionEnabled)
                    .disabled(!viewModel.canSelectExpansions)

                Toggle(
                    AppStrings.Lobby.nautomaExpansion,
                    isOn: Binding(
                        get: { viewModel.isNautomaExpansionEnabled },
                        set: { viewModel.setNautomaExpansionEnabled($0) }
                    )
                )
                .disabled(!viewModel.canSelectNautomaExpansion)
            }
            .toggleStyle(.switch)

            Button {
                viewModel.createLocalRoom()
            } label: {
                Label(AppStrings.Lobby.createLocalRoom, systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canCreateRoom)

            Button {
                viewModel.joinSimulatedPlayer()
            } label: {
                Label(AppStrings.Lobby.joinSimulatedPlayer, systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canJoinPlayer)

            Divider()

            Picker(AppStrings.Lobby.activePlayer, selection: $viewModel.selectedPlayerId) {
                Text(AppStrings.Lobby.none).tag(Optional<PlayerID>.none)
                ForEach(viewModel.players) { player in
                    Text(player.displayName).tag(Optional(player.playerId))
                }
            }
            .pickerStyle(.menu)

            Picker(AppStrings.Lobby.color, selection: $viewModel.selectedColor) {
                ForEach(PlayerColor.allCases, id: \.self) { color in
                    Text(AppStrings.colorName(color)).tag(color)
                }
            }
            .pickerStyle(.segmented)

            Button {
                viewModel.chooseSelectedColor()
            } label: {
                Label(AppStrings.Lobby.chooseColor, systemImage: "paintpalette")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedPlayerId == nil)

            Button {
                viewModel.toggleReadyForSelectedPlayer()
            } label: {
                Label(AppStrings.Lobby.toggleReady, systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedPlayerId == nil)

            Divider()

            Button {
                viewModel.startGameAsHost()
            } label: {
                Label(AppStrings.Lobby.hostStartGame, systemImage: "play.circle")
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
                Text(AppStrings.roleName(player.role))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(player.isReady ? AppStrings.Lobby.ready : AppStrings.Lobby.notReady)
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

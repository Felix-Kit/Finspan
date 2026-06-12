import SwiftUI

struct LobbyView: View {
    @StateObject var viewModel: LobbyViewModel
    @StateObject var cardLibraryViewModel: CardLibraryViewModel
    @State private var selectingWeeklyGoalWeek: Int?
    var onResumeActiveGame: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.requiresProfileSetup {
                    PlayerProfileSetupView(viewModel: viewModel)
                } else {
                    screenContent
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                if !viewModel.requiresProfileSetup {
                    ToolbarItem(placement: .topBarLeading) {
                        PlayerProfileButton(
                            name: viewModel.profileDisplayName,
                            avatarSymbol: viewModel.profileAvatarSymbol
                        ) {
                            viewModel.beginProfileEditing()
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isProfileEditorPresented) {
                NavigationStack {
                    PlayerProfileSetupView(viewModel: viewModel)
                        .navigationTitle(AppStrings.Lobby.editProfile)
                }
            }
            .sheet(item: weeklyGoalSelectionSheetBinding) { week in
                WeeklyGoalSelectionPanel(
                    week: week.value,
                    options: viewModel.availableWeeklyGoalOptions(for: week.value),
                    selectedGoalId: viewModel.selectedWeeklyGoalIdsByWeek[week.value],
                    onSelect: { goalId in
                        viewModel.selectedWeeklyGoalIdsByWeek[week.value] = goalId
                        selectingWeeklyGoalWeek = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            switch viewModel.screen {
            case .mainMenu:
                MainMenuView(viewModel: viewModel, onResumeActiveGame: onResumeActiveGame)
            case .createRoom:
                CreateRoomSetupView(
                    viewModel: viewModel,
                    selectingWeeklyGoalWeek: $selectingWeeklyGoalWeek
                )
            case .roomLobby:
                RoomLobbyView(viewModel: viewModel)
            case .joinGame:
                JoinGameBrowserView(viewModel: viewModel, onResumeActiveGame: onResumeActiveGame)
            case .cardLibrary:
                CardLibraryView(viewModel: cardLibraryViewModel) {
                    viewModel.showMainMenu()
                }
            case .automa:
                AutomaPlaceholderView(viewModel: viewModel)
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.screen {
        case .mainMenu:
            return AppStrings.Lobby.mainMenuTitle
        case .createRoom:
            return AppStrings.Lobby.createRoomEntry
        case .roomLobby:
            return AppStrings.Lobby.roomLobbyTitle
        case .joinGame:
            return AppStrings.Lobby.joinGameTitle
        case .cardLibrary:
            return AppStrings.Lobby.CardLibrary.title
        case .automa:
            return AppStrings.Lobby.automaTitle
        }
    }

    private var weeklyGoalSelectionSheetBinding: Binding<WeeklyGoalWeekSheet?> {
        Binding(
            get: { selectingWeeklyGoalWeek.map(WeeklyGoalWeekSheet.init(value:)) },
            set: { selectingWeeklyGoalWeek = $0?.value }
        )
    }
}

private struct WeeklyGoalWeekSheet: Identifiable {
    let value: Int
    var id: Int { value }
}

private struct PlayerProfileSetupView: View {
    @ObservedObject var viewModel: LobbyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppStrings.Lobby.profileSetupTitle)
                    .font(.largeTitle.weight(.bold))
                Text(AppStrings.Lobby.profileSetupDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            TextField(AppStrings.Lobby.nickname, text: $viewModel.profileNicknameDraft)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Lobby.avatar)
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 12), count: 4), spacing: 12) {
                    ForEach(PlayerAvatarCatalog.symbols, id: \.self) { symbol in
                        Button {
                            viewModel.profileAvatarDraft = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.title2)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Color.cyan.opacity(0.18)))
                                .overlay(
                                    Circle()
                                        .stroke(
                                            viewModel.profileAvatarDraft == symbol ? Color.accentColor : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Button {
                viewModel.saveProfileDraft()
            } label: {
                Label(AppStrings.Lobby.saveProfile, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 560, alignment: .leading)
    }
}

private struct PlayerProfileButton: View {
    let name: String
    let avatarSymbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AvatarCircle(symbol: avatarSymbol, size: 36)
                Text(name)
                    .font(.headline)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MainMenuView: View {
    @ObservedObject var viewModel: LobbyViewModel
    var onResumeActiveGame: (() -> Void)?

    private let entryIconSize: CGFloat = 26

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            if let room = viewModel.activeRoomSummary {
                Button {
                    viewModel.enterActiveRoom()
                    onResumeActiveGame?()
                } label: {
                    HStack(spacing: 16) {
                        AvatarCircle(symbol: room.hostAvatarSymbol, size: 44)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppStrings.Lobby.continueRoomEntry)
                                .font(.title3.weight(.bold))
                            Text(room.roomName)
                                .font(.headline)
                            Text("\(room.playerCountText) · \(room.expansionText) · \(room.weeklyGoalSummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 820, alignment: .leading)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 18)], spacing: 18) {
                menuCard(
                    title: AppStrings.Lobby.createRoomEntry,
                    subtitle: AppStrings.Lobby.createRoomEntryDescription,
                    systemImage: "plus.circle.fill"
                ) {
                    viewModel.showCreateRoom()
                }

                menuCard(
                    title: AppStrings.Lobby.joinGameEntry,
                    subtitle: AppStrings.Lobby.joinGameEntryDescription,
                    systemImage: "person.2.fill"
                ) {
                    viewModel.showJoinGame()
                }

                menuCard(
                    title: AppStrings.Lobby.cardLibraryEntry,
                    subtitle: AppStrings.Lobby.cardLibraryEntryDescription,
                    systemImage: "rectangle.stack.fill"
                ) {
                    viewModel.showCardLibrary()
                }

                menuCard(
                    title: AppStrings.Lobby.automaEntry,
                    subtitle: AppStrings.Lobby.automaEntryDescription,
                    systemImage: "cpu"
                ) {
                    viewModel.showAutoma()
                }
            }
            .frame(maxWidth: 820)

            Spacer(minLength: 20)
        }
        .padding(32)
    }

    private func menuCard(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: entryIconSize, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text(title)
                    .font(.title2.weight(.bold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CreateRoomSetupView: View {
    @ObservedObject var viewModel: LobbyViewModel
    @Binding var selectingWeeklyGoalWeek: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                roomNameSection
                playerCountSection
                dataAndExpansionSection
                WeeklyGoalSetupSection(
                    viewModel: viewModel,
                    selectingWeeklyGoalWeek: $selectingWeeklyGoalWeek
                )

                if let message = viewModel.createRoomValidationMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
            .padding(.bottom, 90)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(AppStrings.Lobby.back) {
                    viewModel.showMainMenu()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    viewModel.createLocalRoom()
                } label: {
                    Label(AppStrings.Lobby.createRoomFooter, systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmitCreateRoom)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.regularMaterial)
        }
    }

    private var roomNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.Lobby.roomName)
                .font(.headline)
            HStack(spacing: 10) {
                TextField(AppStrings.Lobby.roomNamePlaceholder, text: $viewModel.roomNameDraft)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.randomizeRoomName()
                } label: {
                    Image(systemName: "dice.fill")
                        .accessibilityLabel(AppStrings.Lobby.randomRoomName)
                }
                .buttonStyle(.bordered)
            }
            Text(viewModel.effectiveRoomName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var playerCountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.Lobby.playerCount)
                .font(.headline)
            Picker(AppStrings.Lobby.playerCount, selection: $viewModel.playerCount) {
                ForEach(1...4, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
            Text(AppStrings.Lobby.localPlayerCountNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dataAndExpansionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppStrings.Lobby.gameDataMode)
                .font(.headline)
            Picker(AppStrings.Lobby.gameDataMode, selection: $viewModel.selectedGameDataMode) {
                ForEach(GameDataMode.allCases) { mode in
                    Text(AppStrings.gameDataModeName(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle(AppStrings.Lobby.sharksAndReefsExpansion, isOn: $viewModel.isSharksAndReefsExpansionEnabled)

            Toggle(
                AppStrings.Lobby.nautomaExpansion,
                isOn: Binding(
                    get: { viewModel.isNautomaExpansionEnabled },
                    set: { viewModel.setNautomaExpansionEnabled($0) }
                )
            )
            .disabled(true)
        }
    }
}

private struct WeeklyGoalSetupSection: View {
    @ObservedObject var viewModel: LobbyViewModel
    @Binding var selectingWeeklyGoalWeek: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppStrings.Lobby.weeklyGoalSetup)
                .font(.headline)

            Picker(AppStrings.Lobby.weeklyGoalSetup, selection: $viewModel.weeklyGoalBoardSide) {
                Text(AppStrings.Lobby.weeklyGoalSideA).tag(AchievementBoardSide.sideA)
                Text(AppStrings.Lobby.weeklyGoalSideB).tag(AchievementBoardSide.sideB)
            }
            .pickerStyle(.segmented)

            if viewModel.weeklyGoalBoardSide == .sideB {
                Picker(AppStrings.Lobby.weeklyGoalSelectionMode, selection: $viewModel.weeklyGoalSelectionMode) {
                    Text(AppStrings.Lobby.weeklyGoalRandom).tag(WeeklyGoalSelectionMode.random)
                    Text(AppStrings.Lobby.weeklyGoalCustom).tag(WeeklyGoalSelectionMode.custom)
                }
                .pickerStyle(.segmented)

                if viewModel.weeklyGoalSelectionMode == .random {
                    Text(AppStrings.Lobby.randomWeeklyGoalHiddenNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(WeeklyGoalCatalog.supportedWeeks, id: \.self) { week in
                            WeeklyGoalWeekSlotView(
                                week: week,
                                selectedGoal: selectedGoal(for: week)
                            ) {
                                selectingWeeklyGoalWeek = week
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectedGoal(for week: Int) -> WeeklyGoalOptionViewData? {
        guard let goalId = viewModel.selectedWeeklyGoalIdsByWeek[week] else {
            return nil
        }
        return viewModel.availableWeeklyGoalOptions(for: week).first { $0.id == goalId }
    }
}

private struct WeeklyGoalWeekSlotView: View {
    let week: Int
    let selectedGoal: WeeklyGoalOptionViewData?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppStrings.Lobby.weeklyGoalWeekTitle(week))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let selectedGoal {
                    WeeklyGoalTileContent(option: selectedGoal)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                    Text("选择第 \(week) 周目标")
                        .font(.headline)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

private struct WeeklyGoalSelectionPanel: View {
    let week: Int
    let options: [WeeklyGoalOptionViewData]
    let selectedGoalId: WeeklyGoalID?
    let onSelect: (WeeklyGoalID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(options) { option in
                        Button {
                            onSelect(option.id)
                        } label: {
                            WeeklyGoalTileView(option: option, isSelected: selectedGoalId == option.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle(AppStrings.Lobby.weeklyGoalWeekTitle(week))
        }
    }
}

private struct WeeklyGoalTileView: View {
    let option: WeeklyGoalOptionViewData
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeeklyGoalTileContent(option: option)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 3 : 1)
        )
    }
}

private struct WeeklyGoalTileContent: View {
    let option: WeeklyGoalOptionViewData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppStrings.Lobby.weeklyGoalWeekTitle(option.week))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(option.sourceExpansion == .sharksAndReefs ? "S&R" : "Base")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.16)))
            }
            Text(option.title)
                .font(.headline)
            Text("每项 1-2 分")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RoomLobbyView: View {
    @ObservedObject var viewModel: LobbyViewModel
    @State private var isConfirmingDissolve = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let summary = viewModel.roomLobbySummary {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.roomName)
                            .font(.largeTitle.weight(.bold))
                        HStack(spacing: 8) {
                            AvatarCircle(symbol: summary.hostAvatarSymbol, size: 32)
                            Text(summary.hostName)
                            Text(AppStrings.Lobby.hostBadge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Button(AppStrings.Lobby.returnToMainMenu) {
                            viewModel.returnToMainMenuKeepingRoom()
                        }
                        .buttonStyle(.bordered)

                        Button(AppStrings.Lobby.dissolveRoom, role: .destructive) {
                            isConfirmingDissolve = true
                        }
                        .buttonStyle(.bordered)

                        Button(AppStrings.Lobby.startGame) {
                            viewModel.startGameAsHost()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canStartGame)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppStrings.Lobby.roomConfigSummary)
                        .font(.headline)
                    Text("\(AppStrings.Lobby.playerCount)：\(summary.playerCountText)")
                    Text("\(AppStrings.Lobby.enabledExpansions)：\(summary.expansionText)")
                    Text("\(AppStrings.Lobby.weeklyGoalSetup)：\(summary.weeklyGoalSummary)")
                    ForEach(summary.weeklyGoalDetails, id: \.self) { detail in
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(AppStrings.Lobby.players)
                        .font(.headline)
                    ForEach(summary.players) { player in
                        HStack(spacing: 12) {
                            AvatarCircle(symbol: player.avatarSymbol, size: 34)
                            Text(player.name)
                                .font(.body.weight(.medium))
                            if player.isHost {
                                Text(AppStrings.Lobby.hostBadge)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(player.isReady ? AppStrings.Lobby.readyStatus : AppStrings.Lobby.notReadyStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    }
                }

                Button(AppStrings.Lobby.joinSimulatedPlayer) {
                    viewModel.joinSimulatedPlayer()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(24)
        .confirmationDialog(
            AppStrings.Lobby.dissolveRoomConfirmTitle,
            isPresented: $isConfirmingDissolve,
            titleVisibility: .visible
        ) {
            Button(AppStrings.Lobby.dissolveRoom, role: .destructive) {
                viewModel.dissolveCurrentRoom()
            }
            Button(AppStrings.GameBoard.cancel, role: .cancel) {}
        } message: {
            Text(AppStrings.Lobby.dissolveRoomConfirmMessage)
        }
    }
}

private struct JoinGameBrowserView: View {
    @ObservedObject var viewModel: LobbyViewModel
    var onResumeActiveGame: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button(AppStrings.Lobby.back) {
                    viewModel.showMainMenu()
                }
                .buttonStyle(.bordered)
                Spacer()
                Text(AppStrings.Lobby.localRoomListNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(AppStrings.Lobby.refreshRooms) {
                    viewModel.refresh()
                }
                    .buttonStyle(.bordered)
            }

            if viewModel.discoveredRooms.isEmpty {
                ContentUnavailableView(
                    AppStrings.Lobby.noJoinableRooms,
                    systemImage: "wifi.slash",
                    description: Text(AppStrings.Lobby.noJoinableRoomsDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.discoveredRooms) { room in
                            Button {
                                viewModel.enterRoom(room.id)
                                onResumeActiveGame?()
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarCircle(symbol: room.hostAvatarSymbol, size: 42)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(room.roomName)
                                                .font(.headline)
                                            if room.isHostedByLocalPlayer {
                                                Text(AppStrings.Lobby.hostedByMeBadge)
                                                    .font(.caption2.weight(.bold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Capsule().fill(Color.cyan.opacity(0.16)))
                                            }
                                        }
                                        Text(room.hostName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(room.playerCountText) · \(room.expansionText) · \(room.weeklyGoalSummary)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}

private struct AutomaPlaceholderView: View {
    @ObservedObject var viewModel: LobbyViewModel

    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                AppStrings.Lobby.automaTitle,
                systemImage: "cpu",
                description: Text(AppStrings.Lobby.automaPlaceholder)
            )
            Button(AppStrings.Lobby.back) {
                viewModel.showMainMenu()
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }
}

private struct AvatarCircle: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.cyan.gradient))
    }
}

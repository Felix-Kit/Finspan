//
//  ContentView.swift
//  Finspan
//
//  Created by work on 2026/6/2.
//

import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment
    @StateObject private var lobbyViewModel: LobbyViewModel
    @StateObject private var gameBoardViewModel: GameBoardViewModel
    @StateObject private var cardLibraryViewModel: CardLibraryViewModel
    @State private var phase: GamePhase
    @State private var isShowingLobbyOverride = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _lobbyViewModel = StateObject(
            wrappedValue: LobbyViewModel(
                roomService: environment.roomService,
                gameDataController: environment.gameDataController,
                profileStore: environment.playerProfileStore
            )
        )
        _gameBoardViewModel = StateObject(
            wrappedValue: GameBoardViewModel(
                roomService: environment.roomService
            )
        )
        _cardLibraryViewModel = StateObject(
            wrappedValue: CardLibraryViewModel()
        )
        _phase = State(initialValue: environment.roomService.gameState.phase)
    }

    var body: some View {
        Group {
            if !isShowingLobbyOverride,
               phase == .playing || phase == .awaitingChoice || phase == .weekScoring || phase == .endGamePending || phase == .gameEnded {
                GameBoardView(
                    viewModel: gameBoardViewModel,
                    onTemporarilyExitGameAndReturnHome: {
                        temporarilyExitGameAndReturnToLobby()
                    },
                    onDissolveCurrentGameAndReturnHome: {
                        dissolveCurrentGameAndReturnToLobby()
                    }
                )
            } else {
                LobbyView(
                    viewModel: lobbyViewModel,
                    cardLibraryViewModel: cardLibraryViewModel,
                    onResumeActiveGame: {
                        resumeActiveGameFromLobby()
                    }
                )
            }
        }
        .task {
            syncViewModels()
            for await _ in environment.roomService.eventStream {
                syncViewModels()
            }
        }
    }

    private func syncViewModels() {
        phase = environment.roomService.gameState.phase
        if phase == .lobby || phase == .setup {
            isShowingLobbyOverride = false
        }
        lobbyViewModel.refresh()
        gameBoardViewModel.refresh()
    }

    private func temporarilyExitGameAndReturnToLobby() {
        lobbyViewModel.returnToMainMenuKeepingRoom()
        isShowingLobbyOverride = true
        syncViewModels()
    }

    private func resumeActiveGameFromLobby() {
        isShowingLobbyOverride = false
        syncViewModels()
    }

    private func dissolveCurrentGameAndReturnToLobby() {
        lobbyViewModel.dissolveCurrentRoom()
        isShowingLobbyOverride = false
        syncViewModels()
    }
}

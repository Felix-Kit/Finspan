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
    @State private var phase: GamePhase

    init(environment: AppEnvironment) {
        self.environment = environment
        _lobbyViewModel = StateObject(
            wrappedValue: LobbyViewModel(
                roomService: environment.roomService,
                gameDataController: environment.gameDataController
            )
        )
        _gameBoardViewModel = StateObject(
            wrappedValue: GameBoardViewModel(
                roomService: environment.roomService,
                cardCatalogProvider: environment.gameDataController.currentCatalog
            )
        )
        _phase = State(initialValue: environment.roomService.gameState.phase)
    }

    var body: some View {
        Group {
            if phase == .playing || phase == .awaitingChoice || phase == .weekScoring || phase == .endGamePending || phase == .gameEnded {
                GameBoardView(viewModel: gameBoardViewModel)
            } else {
                LobbyView(viewModel: lobbyViewModel)
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
        lobbyViewModel.refresh()
        gameBoardViewModel.refresh()
    }
}

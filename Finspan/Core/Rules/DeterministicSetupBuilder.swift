import Foundation

struct DeterministicSetupBuilder {
    private let catalog: any CardCatalog
    private let enabledExpansions: [Expansion]

    init(
        catalog: any CardCatalog = SampleCardCatalog(),
        enabledExpansions: [Expansion] = []
    ) {
        self.catalog = catalog
        self.enabledExpansions = enabledExpansions
    }

    func makeSetup(players: [RoomPlayer], randomSeed: Int) throws -> GameSetup {
        let activePlayers = players.filter { $0.role != .spectator }
        guard !activePlayers.isEmpty else {
            throw GameEngineError.invalidCommand("Setup requires at least one active player.")
        }

        let starterDeck = SeededShuffle.shuffled(
            catalog.starterFishCards.map(\.id),
            seed: randomSeed &+ 101
        )
        let fishDeck = SeededShuffle.shuffled(
            catalog.fishCards.map(\.id),
            seed: randomSeed &+ 202
        )

        let requiredStarterCount = activePlayers.count * 2
        let requiredFishCount = activePlayers.count * 3
        guard starterDeck.count >= requiredStarterCount, fishDeck.count >= requiredFishCount else {
            throw GameEngineError.invalidCommand("Card catalog does not contain enough sample cards for setup.")
        }

        var startingPlayerRandom = SeededRandom(seed: randomSeed)
        let startingPlayerIndex = startingPlayerRandom.nextInt(upperBound: activePlayers.count)
        let startingPlayerId = activePlayers[startingPlayerIndex].playerId

        var playerStates: [PlayerGameState] = []
        var starterOffset = 0
        var fishOffset = 0

        for player in activePlayers {
            let starterHand = Array(starterDeck[starterOffset..<starterOffset + 2])
            let fishHand = Array(fishDeck[fishOffset..<fishOffset + 3])
            starterOffset += 2
            fishOffset += 3

            playerStates.append(
                PlayerGameState(
                    playerId: player.playerId,
                    hand: starterHand + fishHand,
                    availableDivers: 6,
                    usedDivers: 0,
                    ocean: initialOcean(for: player.playerId)
                )
            )
        }

        return GameSetup(
            randomSeed: randomSeed,
            startingPlayerId: startingPlayerId,
            playerStates: playerStates,
            deckState: DeckState(
                starterFishDrawPile: Array(starterDeck.dropFirst(starterOffset)),
                fishDrawPile: Array(fishDeck.dropFirst(fishOffset)),
                discardPile: []
            )
        )
    }

    private func initialOcean(for playerId: PlayerID) -> OceanState {
        guard enabledExpansions.contains(.sharksAndReefs) else {
            return .baseGameInitial(for: playerId)
        }
        return .sharksAndReefsInitial(for: playerId)
    }
}

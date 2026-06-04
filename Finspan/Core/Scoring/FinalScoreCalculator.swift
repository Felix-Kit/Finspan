import Foundation

struct FinalScoreBreakdown: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var weeklyAchievementPoints: Int
    var fishPrintedPoints: Int
    var gameEndAbilityPoints: Int
    var eggPoints: Int
    var youngPoints: Int
    var schoolPoints: Int
    var consumedFishPoints: Int
    var totalPoints: Int
}

struct FinalScoreResult: Codable, Equatable, Sendable {
    var results: [FinalScoreBreakdown]
    var winnerPlayerIds: [PlayerID]
    var isTie: Bool
}

struct FinalScoreCalculator: Sendable {
    func calculate(in state: GameState, cardCatalog: any CardCatalog) -> FinalScoreResult {
        let cardsById = Dictionary(
            uniqueKeysWithValues: (cardCatalog.starterFishCards + cardCatalog.fishCards).map { ($0.id, $0) }
        )
        let results = state.players.compactMap { player in
            state.playerGameStates[player.id].map { playerState in
                score(
                    playerState: playerState,
                    weeklyAchievementResults: state.weeklyAchievementResults,
                    cardsById: cardsById
                )
            }
        }
        let highestTotal = results.map(\.totalPoints).max()
        let winnerPlayerIds = highestTotal.map { highestTotal in
            results.filter { $0.totalPoints == highestTotal }.map(\.playerId)
        } ?? []

        return FinalScoreResult(
            results: results,
            winnerPlayerIds: winnerPlayerIds,
            isTie: winnerPlayerIds.count > 1
        )
    }

    private func score(
        playerState: PlayerGameState,
        weeklyAchievementResults: [WeeklyAchievementResult],
        cardsById: [CardID: Card]
    ) -> FinalScoreBreakdown {
        let weeklyAchievementPoints = weeklyAchievementResults
            .filter { $0.playerId == playerState.playerId }
            .reduce(0) { $0 + $1.points }
        let fishPrintedPoints = playerState.ocean.slots.reduce(0) { total, slot in
            guard case let .fishCard(cardId) = slot.content else {
                return total
            }
            // TODO: Unknown cards score 0 until authoritative card data guarantees every lookup.
            return total + (cardsById[cardId]?.printedPoints ?? 0)
        }
        let eggPoints = resourceCount(.egg, in: playerState)
        let youngPoints = resourceCount(.young, in: playerState)
        let schoolPoints = resourceCount(.school, in: playerState) * 6
        let consumedFishPoints = playerState.ocean.slots.reduce(0) { total, slot in
            total + slot.consumedFish.count
        }
        // TODO: Insert the GAME END ability pending choice flow before final scoring.
        let gameEndAbilityPoints = 0
        let totalPoints = weeklyAchievementPoints
            + fishPrintedPoints
            + gameEndAbilityPoints
            + eggPoints
            + youngPoints
            + schoolPoints
            + consumedFishPoints

        return FinalScoreBreakdown(
            playerId: playerState.playerId,
            weeklyAchievementPoints: weeklyAchievementPoints,
            fishPrintedPoints: fishPrintedPoints,
            gameEndAbilityPoints: gameEndAbilityPoints,
            eggPoints: eggPoints,
            youngPoints: youngPoints,
            schoolPoints: schoolPoints,
            consumedFishPoints: consumedFishPoints,
            totalPoints: totalPoints
        )
    }

    private func resourceCount(_ kind: ResourceKind, in playerState: PlayerGameState) -> Int {
        playerState.ocean.slots.reduce(0) { total, slot in
            total + (slot.resources.first(where: { $0.kind == kind })?.amount ?? 0)
        }
    }
}

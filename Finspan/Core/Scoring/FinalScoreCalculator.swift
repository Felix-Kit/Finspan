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
    var coralPoints: Int
    var completeReefBonusPoints: Int
    var totalPoints: Int

    init(
        playerId: PlayerID,
        weeklyAchievementPoints: Int,
        fishPrintedPoints: Int,
        gameEndAbilityPoints: Int,
        eggPoints: Int,
        youngPoints: Int,
        schoolPoints: Int,
        consumedFishPoints: Int,
        coralPoints: Int = 0,
        completeReefBonusPoints: Int = 0,
        totalPoints: Int
    ) {
        self.playerId = playerId
        self.weeklyAchievementPoints = weeklyAchievementPoints
        self.fishPrintedPoints = fishPrintedPoints
        self.gameEndAbilityPoints = gameEndAbilityPoints
        self.eggPoints = eggPoints
        self.youngPoints = youngPoints
        self.schoolPoints = schoolPoints
        self.consumedFishPoints = consumedFishPoints
        self.coralPoints = coralPoints
        self.completeReefBonusPoints = completeReefBonusPoints
        self.totalPoints = totalPoints
    }

    private enum CodingKeys: String, CodingKey {
        case playerId
        case weeklyAchievementPoints
        case fishPrintedPoints
        case gameEndAbilityPoints
        case eggPoints
        case youngPoints
        case schoolPoints
        case consumedFishPoints
        case coralPoints
        case completeReefBonusPoints
        case totalPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try container.decode(PlayerID.self, forKey: .playerId)
        weeklyAchievementPoints = try container.decode(Int.self, forKey: .weeklyAchievementPoints)
        fishPrintedPoints = try container.decode(Int.self, forKey: .fishPrintedPoints)
        gameEndAbilityPoints = try container.decode(Int.self, forKey: .gameEndAbilityPoints)
        eggPoints = try container.decode(Int.self, forKey: .eggPoints)
        youngPoints = try container.decode(Int.self, forKey: .youngPoints)
        schoolPoints = try container.decode(Int.self, forKey: .schoolPoints)
        consumedFishPoints = try container.decode(Int.self, forKey: .consumedFishPoints)
        coralPoints = try container.decodeIfPresent(Int.self, forKey: .coralPoints) ?? 0
        completeReefBonusPoints = try container.decodeIfPresent(Int.self, forKey: .completeReefBonusPoints) ?? 0
        totalPoints = try container.decode(Int.self, forKey: .totalPoints)
    }
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
        let coralPoints = playerState.ocean.coralReefs.reduce(0) { total, reef in
            total + reef.coralCount
        }
        let completeReefBonusPoints = playerState.ocean.coralReefs.reduce(0) { total, reef in
            guard reef.coralCount >= reef.maxCoral else {
                return total
            }
            return total + reef.completionBonus
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
            + coralPoints
            + completeReefBonusPoints

        return FinalScoreBreakdown(
            playerId: playerState.playerId,
            weeklyAchievementPoints: weeklyAchievementPoints,
            fishPrintedPoints: fishPrintedPoints,
            gameEndAbilityPoints: gameEndAbilityPoints,
            eggPoints: eggPoints,
            youngPoints: youngPoints,
            schoolPoints: schoolPoints,
            consumedFishPoints: consumedFishPoints,
            coralPoints: coralPoints,
            completeReefBonusPoints: completeReefBonusPoints,
            totalPoints: totalPoints
        )
    }

    private func resourceCount(_ kind: ResourceKind, in playerState: PlayerGameState) -> Int {
        playerState.ocean.slots.reduce(0) { total, slot in
            total + (slot.resources.first(where: { $0.kind == kind })?.amount ?? 0)
        }
    }
}

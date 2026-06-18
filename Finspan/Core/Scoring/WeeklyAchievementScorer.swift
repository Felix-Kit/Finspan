import Foundation

enum AchievementKind: String, Codable, Equatable, Sendable {
    case eggsAndYoung
    case rowsOfFish
    case schools
    case coralCount
    case discardPileCards
    case sunlitFish
    case smallFish
    case mediumFish
    case largeFish
    case consumedFish
    case predatorTags
    case markedFish
    case unmarkedFish
    case activatedCards
    case everyTwoEggs
    case everyThreeEggs
    case distinctTags
    case printedPointsHigh
    case printedPointsLow
    case completeReefBonus
}

struct WeeklyAchievementResult: Codable, Equatable, Sendable {
    var week: Int
    var kind: AchievementKind
    var playerId: PlayerID
    var quantity: Int
    var points: Int
}

struct SideAWeeklyAchievementScorer: Sendable {
    func score(
        week: Int,
        playerStates: [PlayerGameState],
        weeklyGoals: [WeeklyGoalDefinition]? = nil,
        cardCatalog: (any CardCatalog)? = nil,
        abilityResolver: AbilityResolver = AbilityResolver()
    ) -> [WeeklyAchievementResult] {
        guard let goal = weeklyGoal(for: week, weeklyGoals: weeklyGoals) else {
            return []
        }

        let cardResolver = cardCatalog?.identityResolver()
        let baseResults = playerStates.map { playerState in
            let quantity = goal.isImplementedForScoring
                ? quantity(
                    for: goal.kind,
                    playerState: playerState,
                    cardResolver: cardResolver,
                    abilityResolver: abilityResolver
                )
                : 0
            return WeeklyAchievementResult(
                week: week,
                kind: goal.kind,
                playerId: playerState.playerId,
                quantity: quantity,
                points: quantity * goal.pointsPerUnit
            )
        }

        guard goal.source == .baseTilePool || goal.source == .sharksAndReefsTilePool,
              (1...3).contains(week),
              let highestBaseScore = baseResults.map(\.points).max()
        else {
            return baseResults
        }

        return baseResults.map { result in
            var result = result
            if result.points == highestBaseScore {
                result.points += 3
            }
            return result
        }
    }

    private func weeklyGoal(
        for week: Int,
        weeklyGoals: [WeeklyGoalDefinition]?
    ) -> WeeklyGoalDefinition? {
        let goals = weeklyGoals ?? WeeklyGoalCatalog.sideAGoals
        return goals.first { $0.week == week }
    }

    private func quantity(
        for kind: AchievementKind,
        playerState: PlayerGameState,
        cardResolver: CardIdentityResolver?,
        abilityResolver: AbilityResolver
    ) -> Int {
        switch kind {
        case .eggsAndYoung:
            return playerState.ocean.slots.reduce(0) { total, slot in
                total + resourceAmount(.egg, in: slot) + resourceAmount(.young, in: slot)
            }
        case .rowsOfFish:
            return SampleOceanLayout.rowIndices.filter { rowIndex in
                DiveSite.allCases.allSatisfy { diveSite in
                    playerState.ocean.slots.contains { slot in
                        slot.address.diveSite == diveSite
                            && slot.address.rowIndex == rowIndex
                            && slot.content.hasFish
                    }
                }
            }.count
        case .schools:
            return playerState.ocean.slots.reduce(0) { total, slot in
                total + resourceAmount(.school, in: slot)
            }
        case .coralCount:
            return playerState.ocean.coralReefs.reduce(0) { total, reef in
                total + reef.coralCount
            }
        case .discardPileCards:
            return playerState.discardPile.count
        case .sunlitFish:
            return playerState.ocean.slots.filter { slot in
                slot.address.zone == .sunlit && slot.content.hasFish
            }.count
        case .consumedFish:
            return playerState.ocean.slots.reduce(0) { total, slot in
                total + slot.consumedFish.count
            }
        case .smallFish:
            return visibleFishLengths(in: playerState, cardResolver: cardResolver).filter { $0 < 50 }.count
        case .mediumFish:
            return visibleFishLengths(in: playerState, cardResolver: cardResolver).filter { (50..<150).contains($0) }.count
        case .largeFish:
            return visibleFishLengths(in: playerState, cardResolver: cardResolver).filter { $0 >= 150 }.count
        case .predatorTags:
            return visibleCards(in: playerState, cardResolver: cardResolver).filter { card in
                card.tags.contains { $0.kind.lowercased() == "predator" && $0.count > 0 }
            }.count
        case .markedFish,
             .unmarkedFish:
            return 0
        case .activatedCards:
            return visibleCards(in: playerState, cardResolver: cardResolver).filter { card in
                abilityResolver.abilityDefinitions(for: card).contains { $0.trigger == .ifActivated }
            }.count
        case .everyTwoEggs:
            return totalEggs(in: playerState) / 2
        case .everyThreeEggs:
            return totalEggs(in: playerState) / 3
        case .distinctTags:
            let scoreableTagKinds: Set<String> = [
                "predator",
                "bioluminescent",
                "camouflage",
                "electric",
                "venomous"
            ]
            return Set(
                visibleCards(in: playerState, cardResolver: cardResolver)
                    .flatMap(\.tags)
                    .filter { $0.count > 0 && scoreableTagKinds.contains($0.kind.lowercased()) }
                    .map { $0.kind.lowercased() }
            ).count
        case .printedPointsHigh:
            return visibleCards(in: playerState, cardResolver: cardResolver).filter { $0.printedPoints > 4 }.count
        case .printedPointsLow:
            return visibleCards(in: playerState, cardResolver: cardResolver).filter { (1...3).contains($0.printedPoints) }.count
        case .completeReefBonus:
            return playerState.ocean.coralReefs.reduce(0) { total, reef in
                total + (reef.coralCount >= reef.maxCoral ? reef.completionBonus : 0)
            }
        }
    }

    private func visibleCards(
        in playerState: PlayerGameState,
        cardResolver: CardIdentityResolver?
    ) -> [Card] {
        guard let cardResolver else {
            return []
        }
        return playerState.ocean.slots.compactMap { slot in
            guard case let .fishCard(cardId) = slot.content else {
                return nil
            }
            return cardResolver.card(for: cardId)
        }
    }

    private func visibleFishLengths(
        in playerState: PlayerGameState,
        cardResolver: CardIdentityResolver?
    ) -> [Int] {
        playerState.ocean.slots.compactMap { slot in
            switch slot.content {
            case let .fishCard(cardId):
                return cardResolver?.card(for: cardId)?.lengthCm
            case let .forageFish(fish):
                return fish.lengthCm
            case .empty:
                return nil
            }
        }
    }

    private func totalEggs(in playerState: PlayerGameState) -> Int {
        playerState.ocean.slots.reduce(0) { total, slot in
            total + resourceAmount(.egg, in: slot)
        }
    }

    private func resourceAmount(_ kind: ResourceKind, in slot: OceanSlot) -> Int {
        slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
    }
}

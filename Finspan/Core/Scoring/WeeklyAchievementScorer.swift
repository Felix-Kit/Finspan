import Foundation

enum AchievementKind: String, Codable, Equatable, Sendable {
    case eggsAndYoung
    case rowsOfFish
    case schools
    case coralCount
    case discardPileCards
    case sunlitFish
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
        weeklyGoals: [WeeklyGoalDefinition]? = nil
    ) -> [WeeklyAchievementResult] {
        guard let goal = weeklyGoal(for: week, weeklyGoals: weeklyGoals) else {
            return []
        }

        return playerStates.map { playerState in
            let quantity = quantity(for: goal.kind, playerState: playerState)
            return WeeklyAchievementResult(
                week: week,
                kind: goal.kind,
                playerId: playerState.playerId,
                quantity: quantity,
                points: quantity * goal.pointsPerUnit
            )
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
        playerState: PlayerGameState
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
        }
    }

    private func resourceAmount(_ kind: ResourceKind, in slot: OceanSlot) -> Int {
        slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
    }
}

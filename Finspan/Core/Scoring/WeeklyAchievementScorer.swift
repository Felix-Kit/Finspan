import Foundation

enum AchievementKind: String, Codable, Equatable, Sendable {
    case eggsAndYoung
    case rowsOfFish
    case schools
}

struct WeeklyAchievementResult: Codable, Equatable, Sendable {
    var week: Int
    var kind: AchievementKind
    var playerId: PlayerID
    var quantity: Int
    var points: Int
}

struct SideAWeeklyAchievementScorer: Sendable {
    func score(week: Int, playerStates: [PlayerGameState]) -> [WeeklyAchievementResult] {
        guard let kind = achievementKind(for: week) else {
            return []
        }

        return playerStates.map { playerState in
            let quantity = quantity(for: kind, playerState: playerState)
            return WeeklyAchievementResult(
                week: week,
                kind: kind,
                playerId: playerState.playerId,
                quantity: quantity,
                points: quantity * pointsPerUnit(for: kind)
            )
        }
    }

    private func achievementKind(for week: Int) -> AchievementKind? {
        switch week {
        case 1:
            return .eggsAndYoung
        case 2:
            return .rowsOfFish
        case 3:
            return .schools
        default:
            return nil
        }
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
        }
    }

    private func pointsPerUnit(for kind: AchievementKind) -> Int {
        switch kind {
        case .eggsAndYoung:
            return 1
        case .rowsOfFish,
             .schools:
            return 2
        }
    }

    private func resourceAmount(_ kind: ResourceKind, in slot: OceanSlot) -> Int {
        slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
    }
}

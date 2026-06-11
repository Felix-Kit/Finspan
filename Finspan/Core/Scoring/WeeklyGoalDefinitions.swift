import Foundation

typealias WeeklyGoalID = String

enum AchievementBoardSide: String, Codable, CaseIterable, Equatable, Sendable {
    case sideA
    case sideB
}

enum WeeklyGoalSelectionMode: String, Codable, CaseIterable, Equatable, Sendable {
    case random
    case custom
}

struct WeeklyGoalSetupConfig: Codable, Equatable, Sendable {
    var boardSide: AchievementBoardSide
    var selectionMode: WeeklyGoalSelectionMode
    var selectedGoalIdsByWeek: [Int: WeeklyGoalID]

    init(
        boardSide: AchievementBoardSide = .sideA,
        selectionMode: WeeklyGoalSelectionMode = .random,
        selectedGoalIdsByWeek: [Int: WeeklyGoalID] = [:]
    ) {
        self.boardSide = boardSide
        self.selectionMode = selectionMode
        self.selectedGoalIdsByWeek = selectedGoalIdsByWeek
    }
}

struct WeeklyGoalDefinition: Codable, Equatable, Identifiable, Sendable {
    var id: WeeklyGoalID
    var week: Int
    var sourceExpansion: Expansion?
    var title: String
    var kind: AchievementKind
    var pointsPerUnit: Int
}

enum WeeklyGoalCatalog {
    static let supportedWeeks = [1, 2, 3]

    static let sideAGoals: [WeeklyGoalDefinition] = [
        WeeklyGoalDefinition(
            id: "base.sideA.week1.eggsAndYoung",
            week: 1,
            sourceExpansion: nil,
            title: "鱼卵和幼鱼",
            kind: .eggsAndYoung,
            pointsPerUnit: 1
        ),
        WeeklyGoalDefinition(
            id: "base.sideA.week2.rowsOfFish",
            week: 2,
            sourceExpansion: nil,
            title: "整排的鱼",
            kind: .rowsOfFish,
            pointsPerUnit: 2
        ),
        WeeklyGoalDefinition(
            id: "base.sideA.week3.schools",
            week: 3,
            sourceExpansion: nil,
            title: "鱼群",
            kind: .schools,
            pointsPerUnit: 2
        )
    ]

    static let baseSideBGoals: [WeeklyGoalDefinition] = sideAGoals

    static let sharksAndReefsSideBGoals: [WeeklyGoalDefinition] = [
        WeeklyGoalDefinition(
            id: "sr.sideB.week1.coralCount",
            week: 1,
            sourceExpansion: .sharksAndReefs,
            title: "珊瑚数量",
            kind: .coralCount,
            pointsPerUnit: 1
        ),
        WeeklyGoalDefinition(
            id: "sr.sideB.week2.discardPileCards",
            week: 2,
            sourceExpansion: .sharksAndReefs,
            title: "弃牌堆鱼牌",
            kind: .discardPileCards,
            pointsPerUnit: 1
        ),
        WeeklyGoalDefinition(
            id: "sr.sideB.week3.sunlitFish",
            week: 3,
            sourceExpansion: .sharksAndReefs,
            title: "阳光带鱼牌",
            kind: .sunlitFish,
            pointsPerUnit: 1
        )
    ]

    static func availableGoals(enabledExpansions: [Expansion]) -> [WeeklyGoalDefinition] {
        var goals = baseSideBGoals
        if enabledExpansions.contains(.sharksAndReefs) {
            goals.append(contentsOf: sharksAndReefsSideBGoals)
        }
        return goals
    }

    static func availableGoals(
        for week: Int,
        enabledExpansions: [Expansion]
    ) -> [WeeklyGoalDefinition] {
        availableGoals(enabledExpansions: enabledExpansions)
            .filter { $0.week == week }
    }

    static func resolveGoals(
        setupConfig: WeeklyGoalSetupConfig,
        enabledExpansions: [Expansion],
        randomSeed: Int
    ) throws -> [WeeklyGoalDefinition] {
        switch setupConfig.boardSide {
        case .sideA:
            return sideAGoals
        case .sideB:
            switch setupConfig.selectionMode {
            case .random:
                return try randomSideBGoals(
                    enabledExpansions: enabledExpansions,
                    randomSeed: randomSeed
                )
            case .custom:
                return try customSideBGoals(
                    selectedGoalIdsByWeek: setupConfig.selectedGoalIdsByWeek,
                    enabledExpansions: enabledExpansions
                )
            }
        }
    }

    static func validationError(
        setupConfig: WeeklyGoalSetupConfig,
        enabledExpansions: [Expansion]
    ) -> String? {
        do {
            _ = try resolveGoals(
                setupConfig: setupConfig,
                enabledExpansions: enabledExpansions,
                randomSeed: 0
            )
            return nil
        } catch {
            return String(describing: error)
        }
    }

    private static func randomSideBGoals(
        enabledExpansions: [Expansion],
        randomSeed: Int
    ) throws -> [WeeklyGoalDefinition] {
        var random = SeededRandom(seed: randomSeed &+ 303)
        return try supportedWeeks.map { week in
            let goals = availableGoals(for: week, enabledExpansions: enabledExpansions)
            guard !goals.isEmpty else {
                throw GameEngineError.invalidCommand("No weekly goals available for week \(week).")
            }
            return goals[random.nextInt(upperBound: goals.count)]
        }
    }

    private static func customSideBGoals(
        selectedGoalIdsByWeek: [Int: WeeklyGoalID],
        enabledExpansions: [Expansion]
    ) throws -> [WeeklyGoalDefinition] {
        try supportedWeeks.map { week in
            guard let selectedGoalId = selectedGoalIdsByWeek[week] else {
                throw GameEngineError.invalidCommand("Missing weekly goal selection for week \(week).")
            }
            let goals = availableGoals(for: week, enabledExpansions: enabledExpansions)
            guard let goal = goals.first(where: { $0.id == selectedGoalId }) else {
                throw GameEngineError.invalidCommand("Invalid weekly goal selection for week \(week).")
            }
            return goal
        }
    }
}

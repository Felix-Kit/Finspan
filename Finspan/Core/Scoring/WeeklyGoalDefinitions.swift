import Foundation

typealias WeeklyGoalID = String

enum AchievementBoardSet: String, Codable, CaseIterable, Equatable, Sendable {
    case base
    case sharksAndReefs
}

enum AchievementBoardSide: String, Codable, CaseIterable, Equatable, Sendable {
    case sideA
    case sideB
}

enum WeeklyGoalWeek: Int, Codable, CaseIterable, Equatable, Sendable {
    case week1 = 1
    case week2 = 2
    case week3 = 3
    case week4 = 4
}

enum WeeklyGoalSelectionMode: String, Codable, CaseIterable, Equatable, Sendable {
    case random
    case custom
}

enum WeeklyGoalSource: String, Codable, Equatable, Sendable {
    case fixedBoard
    case baseTilePool
    case sharksAndReefsTilePool
    case fixedGameEnd
}

enum WeeklyGoalIconToken: String, Codable, CaseIterable, Equatable, Sendable {
    case egg
    case young
    case school
    case fish
    case smallFish
    case mediumFish
    case largeFish
    case predator
    case consumedFish
    case card
    case discard
    case sun
    case twilight
    case night
    case blueCoral
    case purpleCoral
    case greenCoral
    case anyCoral
    case completeReefBonus
    case gameEnd
    case wave
}

enum WeeklyGoalScoringRule: String, Codable, Equatable, Sendable {
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
    case gameEnd
}

struct WeeklyGoalSetupConfig: Codable, Equatable, Sendable {
    var boardSet: AchievementBoardSet
    var boardSide: AchievementBoardSide
    var selectionMode: WeeklyGoalSelectionMode
    var selectedGoalIdsByWeek: [Int: WeeklyGoalID]

    init(
        boardSet: AchievementBoardSet = .base,
        boardSide: AchievementBoardSide = .sideA,
        selectionMode: WeeklyGoalSelectionMode = .random,
        selectedGoalIdsByWeek: [Int: WeeklyGoalID] = [:]
    ) {
        self.boardSet = boardSet
        self.boardSide = boardSide
        self.selectionMode = selectionMode
        self.selectedGoalIdsByWeek = selectedGoalIdsByWeek
    }

    private enum CodingKeys: String, CodingKey {
        case boardSet
        case boardSide
        case selectionMode
        case selectedGoalIdsByWeek
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boardSet = try container.decodeIfPresent(AchievementBoardSet.self, forKey: .boardSet) ?? .base
        boardSide = try container.decodeIfPresent(AchievementBoardSide.self, forKey: .boardSide) ?? .sideA
        selectionMode = try container.decodeIfPresent(WeeklyGoalSelectionMode.self, forKey: .selectionMode) ?? .random
        selectedGoalIdsByWeek = try container.decodeIfPresent([Int: WeeklyGoalID].self, forKey: .selectedGoalIdsByWeek) ?? [:]
    }
}

struct WeeklyGoalDefinition: Codable, Equatable, Identifiable, Sendable {
    var id: WeeklyGoalID
    var boardSet: AchievementBoardSet
    var week: Int
    var sourceExpansion: Expansion?
    var source: WeeklyGoalSource
    var title: String
    var shortTitle: String
    var description: String
    var iconTokens: [WeeklyGoalIconToken]
    var kind: AchievementKind
    var scoringRule: WeeklyGoalScoringRule
    var pointsPerUnit: Int
    var sourceImageNote: String
    var isImplementedForScoring: Bool
    var needsReview: Bool

    init(
        id: WeeklyGoalID,
        boardSet: AchievementBoardSet = .base,
        week: Int,
        sourceExpansion: Expansion? = nil,
        source: WeeklyGoalSource = .fixedBoard,
        title: String,
        shortTitle: String? = nil,
        description: String? = nil,
        iconTokens: [WeeklyGoalIconToken] = [],
        kind: AchievementKind,
        scoringRule: WeeklyGoalScoringRule? = nil,
        pointsPerUnit: Int,
        sourceImageNote: String = "",
        isImplementedForScoring: Bool = true,
        needsReview: Bool = false
    ) {
        self.id = id
        self.boardSet = boardSet
        self.week = week
        self.sourceExpansion = sourceExpansion
        self.source = source
        self.title = title
        self.shortTitle = shortTitle ?? title
        self.description = description ?? title
        self.iconTokens = iconTokens
        self.kind = kind
        self.scoringRule = scoringRule ?? WeeklyGoalScoringRule(kind)
        self.pointsPerUnit = pointsPerUnit
        self.sourceImageNote = sourceImageNote
        self.isImplementedForScoring = isImplementedForScoring
        self.needsReview = needsReview
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case boardSet
        case week
        case sourceExpansion
        case source
        case title
        case shortTitle
        case description
        case iconTokens
        case kind
        case scoringRule
        case pointsPerUnit
        case sourceImageNote
        case isImplementedForScoring
        case needsReview
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(WeeklyGoalID.self, forKey: .id)
        boardSet = try container.decodeIfPresent(AchievementBoardSet.self, forKey: .boardSet) ?? .base
        week = try container.decode(Int.self, forKey: .week)
        sourceExpansion = try container.decodeIfPresent(Expansion.self, forKey: .sourceExpansion)
        source = try container.decodeIfPresent(WeeklyGoalSource.self, forKey: .source) ?? .fixedBoard
        title = try container.decode(String.self, forKey: .title)
        shortTitle = try container.decodeIfPresent(String.self, forKey: .shortTitle) ?? title
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? title
        iconTokens = try container.decodeIfPresent([WeeklyGoalIconToken].self, forKey: .iconTokens) ?? []
        kind = try container.decode(AchievementKind.self, forKey: .kind)
        scoringRule = try container.decodeIfPresent(WeeklyGoalScoringRule.self, forKey: .scoringRule)
            ?? WeeklyGoalScoringRule(kind)
        pointsPerUnit = try container.decode(Int.self, forKey: .pointsPerUnit)
        sourceImageNote = try container.decodeIfPresent(String.self, forKey: .sourceImageNote) ?? ""
        isImplementedForScoring = try container.decodeIfPresent(Bool.self, forKey: .isImplementedForScoring) ?? true
        needsReview = try container.decodeIfPresent(Bool.self, forKey: .needsReview) ?? false
    }
}

struct WeeklyGoalSlot: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(boardSet.rawValue)-\(side.rawValue)-week-\(week.rawValue)" }

    var boardSet: AchievementBoardSet
    var side: AchievementBoardSide
    var week: WeeklyGoalWeek
    var source: WeeklyGoalSource
    var tile: WeeklyGoalDefinition?

    var isGameEndSlot: Bool {
        week == .week4
    }
}

struct WeeklyGoalPool: Codable, Equatable, Sendable {
    var boardSet: AchievementBoardSet
    var week: WeeklyGoalWeek
    var goals: [WeeklyGoalDefinition]
}

struct AchievementBoard: Codable, Equatable, Sendable {
    var set: AchievementBoardSet
    var side: AchievementBoardSide
    var slots: [WeeklyGoalSlot]
    var scoringNotes: [String]
}

extension WeeklyGoalScoringRule {
    init(_ kind: AchievementKind) {
        switch kind {
        case .eggsAndYoung:
            self = .eggsAndYoung
        case .rowsOfFish:
            self = .rowsOfFish
        case .schools:
            self = .schools
        case .coralCount:
            self = .coralCount
        case .discardPileCards:
            self = .discardPileCards
        case .sunlitFish:
            self = .sunlitFish
        case .smallFish:
            self = .smallFish
        case .mediumFish:
            self = .mediumFish
        case .largeFish:
            self = .largeFish
        case .consumedFish:
            self = .consumedFish
        case .predatorTags:
            self = .predatorTags
        case .markedFish:
            self = .markedFish
        case .unmarkedFish:
            self = .unmarkedFish
        case .activatedCards:
            self = .activatedCards
        case .everyTwoEggs:
            self = .everyTwoEggs
        case .everyThreeEggs:
            self = .everyThreeEggs
        case .distinctTags:
            self = .distinctTags
        case .printedPointsHigh:
            self = .printedPointsHigh
        case .printedPointsLow:
            self = .printedPointsLow
        case .completeReefBonus:
            self = .completeReefBonus
        }
    }
}

enum WeeklyGoalCatalog {
    static let supportedWeeks = [1, 2, 3]

    static let sideAGoals: [WeeklyGoalDefinition] = sideAGoals(for: .base)

    static func sideAGoals(for boardSet: AchievementBoardSet) -> [WeeklyGoalDefinition] {
        [
            WeeklyGoalDefinition(
                id: "\(boardSet.idPrefix).sideA.week1.eggsAndYoung",
                boardSet: boardSet,
                week: 1,
                sourceExpansion: boardSet.sourceExpansion,
                source: .fixedBoard,
                title: "鱼卵和/或幼鱼",
                shortTitle: "鱼卵/幼鱼",
                description: "本周结束时，每个鱼卵和幼鱼计分。",
                iconTokens: [.egg, .young],
                kind: .eggsAndYoung,
                pointsPerUnit: 1,
                sourceImageNote: boardSet == .base ? "IMG_4890" : "IMG_4888"
            ),
            WeeklyGoalDefinition(
                id: "\(boardSet.idPrefix).sideA.week2.rowsOfFish",
                boardSet: boardSet,
                week: 2,
                sourceExpansion: boardSet.sourceExpansion,
                source: .fixedBoard,
                title: "整排的鱼",
                shortTitle: "整排",
                description: "本周结束时，每条完整横排的鱼计分。",
                iconTokens: [.fish, .fish, .fish],
                kind: .rowsOfFish,
                pointsPerUnit: 2,
                sourceImageNote: boardSet == .base ? "IMG_4890" : "IMG_4888"
            ),
            WeeklyGoalDefinition(
                id: "\(boardSet.idPrefix).sideA.week3.schools",
                boardSet: boardSet,
                week: 3,
                sourceExpansion: boardSet.sourceExpansion,
                source: .fixedBoard,
                title: "鱼群",
                shortTitle: "鱼群",
                description: "本周结束时，每个鱼群计分。",
                iconTokens: [.school],
                kind: .schools,
                pointsPerUnit: 2,
                sourceImageNote: boardSet == .base ? "IMG_4890" : "IMG_4888"
            )
        ]
    }

    static let baseSideBGoals: [WeeklyGoalDefinition] = [
        goal("base.sideB.week1.smallFish", .base, 1, "小型鱼", [.smallFish], .smallFish, 2, false, "IMG_4886"),
        goal("base.sideB.week1.eggsAndYoung", .base, 1, "鱼卵和/或幼鱼", [.egg, .young], .eggsAndYoung, 1, true, "IMG_4887"),
        goal("base.sideB.week1.markedFish", .base, 1, "上方有标记的鱼", [.egg, .young, .school], .markedFish, 1, false, "IMG_4887", needsReview: true),
        goal("base.sideB.week1.unmarkedFish", .base, 1, "上方没有标记的鱼", [.fish], .unmarkedFish, 1, false, "IMG_4887", needsReview: true),
        goal("base.sideB.week1.activatedCards", .base, 1, "若发动卡牌", [.card], .activatedCards, 2, false, "IMG_4886", needsReview: true),
        goal("base.sideB.week2.mediumFish", .base, 2, "中型鱼", [.mediumFish], .mediumFish, 2, false, "IMG_4887"),
        goal("base.sideB.week2.rowsOfFish", .base, 2, "整排的鱼", [.fish, .fish, .fish], .rowsOfFish, 2, true, "IMG_4887"),
        goal("base.sideB.week2.predatorTags", .base, 2, "每个捕食者标签", [.predator], .predatorTags, 2, false, "IMG_4887"),
        goal("base.sideB.week2.everyTwoEggs", .base, 2, "每 2 枚鱼卵", [.egg, .egg], .everyTwoEggs, 3, false, "IMG_4886"),
        goal("base.sideB.week2.consumedFish", .base, 2, "被吞食的鱼", [.consumedFish], .consumedFish, 2, true, "IMG_4886"),
        goal("base.sideB.week3.schools", .base, 3, "鱼群", [.school], .schools, 3, true, "IMG_4887"),
        goal("base.sideB.week3.youngFish", .base, 3, "幼鱼", [.young], .eggsAndYoung, 3, false, "IMG_4886", needsReview: true),
        goal("base.sideB.week3.largeFish", .base, 3, "大型鱼", [.largeFish], .largeFish, 2, false, "IMG_4887"),
        goal("base.sideB.week3.everyThreeEggs", .base, 3, "每 3 枚鱼卵", [.egg, .egg, .egg], .everyThreeEggs, 2, false, "IMG_4886")
    ]

    static let sharksAndReefsSideBGoals: [WeeklyGoalDefinition] = [
        goal("sr.sideB.week1.coralCount", .sharksAndReefs, 1, "珊瑚", [.anyCoral], .coralCount, 2, true, "IMG_4886"),
        goal("sr.sideB.week1.sunlitFish", .sharksAndReefs, 1, "透光带中的鱼", [.sun, .fish], .sunlitFish, 1, true, "IMG_4886"),
        goal("sr.sideB.week1.discardPileCards", .sharksAndReefs, 1, "弃牌堆中卡牌数量", [.discard], .discardPileCards, 1, true, "IMG_4887"),
        goal("sr.sideB.week1.printedPointsLow", .sharksAndReefs, 1, "分值 1-3 之间的鱼", [.wave, .fish], .printedPointsLow, 1, false, "IMG_4887"),
        goal("sr.sideB.week2.predatorTags", .sharksAndReefs, 2, "每个捕食者标签", [.predator], .predatorTags, 2, false, "IMG_4887"),
        goal("sr.sideB.week2.distinctTags", .sharksAndReefs, 2, "鱼类中的不同标签", [.predator, .wave], .distinctTags, 2, false, "IMG_4887", needsReview: true),
        goal("sr.sideB.week2.coralCount", .sharksAndReefs, 2, "珊瑚", [.blueCoral, .purpleCoral, .greenCoral], .coralCount, 2, true, "IMG_4886"),
        goal("sr.sideB.week3.printedPointsHigh", .sharksAndReefs, 3, "分值高于 4 的鱼", [.wave, .fish], .printedPointsHigh, 1, false, "IMG_4886"),
        goal("sr.sideB.week3.printedPointsLow", .sharksAndReefs, 3, "分值 1-3 之间的鱼", [.wave, .fish], .printedPointsLow, 1, false, "IMG_4887"),
        goal("sr.sideB.week3.completeReefBonus", .sharksAndReefs, 3, "完成珊瑚礁奖励", [.completeReefBonus], .completeReefBonus, 1, false, "IMG_4888", needsReview: true)
    ]

    static func board(
        set: AchievementBoardSet,
        side: AchievementBoardSide,
        selectedGoals: [WeeklyGoalDefinition] = []
    ) -> AchievementBoard {
        let goalByWeek = Dictionary(uniqueKeysWithValues: selectedGoals.map { ($0.week, $0) })
        let slots = WeeklyGoalWeek.allCases.map { week -> WeeklyGoalSlot in
            if week == .week4 {
                return WeeklyGoalSlot(boardSet: set, side: side, week: week, source: .fixedGameEnd, tile: nil)
            }
            let tile: WeeklyGoalDefinition?
            switch side {
            case .sideA:
                tile = sideAGoals(for: set).first { $0.week == week.rawValue }
            case .sideB:
                tile = goalByWeek[week.rawValue]
            }
            return WeeklyGoalSlot(
                boardSet: set,
                side: side,
                week: week,
                source: tile?.source ?? .fixedBoard,
                tile: tile
            )
        }
        return AchievementBoard(set: set, side: side, slots: slots, scoringNotes: scoringNotes(for: set))
    }

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

    static func availableGoals(
        for week: Int,
        boardSet: AchievementBoardSet,
        enabledExpansions: [Expansion]
    ) -> [WeeklyGoalDefinition] {
        guard isBoardSetAvailable(boardSet, enabledExpansions: enabledExpansions) else {
            return []
        }
        return sideBGoals(for: boardSet).filter { $0.week == week }
    }

    static func resolveGoals(
        setupConfig: WeeklyGoalSetupConfig,
        enabledExpansions: [Expansion],
        randomSeed: Int
    ) throws -> [WeeklyGoalDefinition] {
        guard isBoardSetAvailable(setupConfig.boardSet, enabledExpansions: enabledExpansions) else {
            throw GameEngineError.invalidCommand("Selected weekly achievement board is not available.")
        }
        switch setupConfig.boardSide {
        case .sideA:
            return sideAGoals(for: setupConfig.boardSet)
        case .sideB:
            switch setupConfig.selectionMode {
            case .random:
                return try randomSideBGoals(
                    boardSet: setupConfig.boardSet,
                    enabledExpansions: enabledExpansions,
                    randomSeed: randomSeed
                )
            case .custom:
                return try customSideBGoals(
                    boardSet: setupConfig.boardSet,
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

    static func scoringNotes(for set: AchievementBoardSet) -> [String] {
        switch set {
        case .base:
            return [
                "游戏结束分数",
                "可见鱼上印有的分数",
                "鱼卵：每个 1 分",
                "幼鱼：每个 1 分",
                "鱼群：每个 6 分",
                "被吞食的鱼：每个 1 分"
            ]
        case .sharksAndReefs:
            return [
                "游戏结束分数",
                "可见鱼上印有的分数",
                "鱼卵/幼鱼：每个 1 分",
                "鱼群：每个 6 分",
                "被吞食的鱼：每个 1 分",
                "珊瑚：每个 1 分 + 完成珊瑚礁的奖励分数"
            ]
        }
    }

    private static func randomSideBGoals(
        boardSet: AchievementBoardSet,
        enabledExpansions: [Expansion],
        randomSeed: Int
    ) throws -> [WeeklyGoalDefinition] {
        var random = SeededRandom(seed: randomSeed &+ 303)
        return try supportedWeeks.map { week in
            let goals = availableGoals(for: week, boardSet: boardSet, enabledExpansions: enabledExpansions)
            guard !goals.isEmpty else {
                throw GameEngineError.invalidCommand("No weekly goals available for week \(week).")
            }
            return goals[random.nextInt(upperBound: goals.count)]
        }
    }

    private static func customSideBGoals(
        boardSet: AchievementBoardSet,
        selectedGoalIdsByWeek: [Int: WeeklyGoalID],
        enabledExpansions: [Expansion]
    ) throws -> [WeeklyGoalDefinition] {
        try supportedWeeks.map { week in
            guard let selectedGoalId = selectedGoalIdsByWeek[week] else {
                throw GameEngineError.invalidCommand("Missing weekly goal selection for week \(week).")
            }
            let goals = availableGoals(for: week, boardSet: boardSet, enabledExpansions: enabledExpansions)
            guard let goal = goals.first(where: { $0.id == selectedGoalId }) else {
                throw GameEngineError.invalidCommand("Invalid weekly goal selection for week \(week).")
            }
            return goal
        }
    }

    private static func sideBGoals(for boardSet: AchievementBoardSet) -> [WeeklyGoalDefinition] {
        switch boardSet {
        case .base:
            return baseSideBGoals
        case .sharksAndReefs:
            return sharksAndReefsSideBGoals
        }
    }

    private static func isBoardSetAvailable(
        _ boardSet: AchievementBoardSet,
        enabledExpansions: [Expansion]
    ) -> Bool {
        switch boardSet {
        case .base:
            return true
        case .sharksAndReefs:
            return enabledExpansions.contains(.sharksAndReefs)
        }
    }

    private static func goal(
        _ id: WeeklyGoalID,
        _ set: AchievementBoardSet,
        _ week: Int,
        _ title: String,
        _ iconTokens: [WeeklyGoalIconToken],
        _ kind: AchievementKind,
        _ pointsPerUnit: Int,
        _ isImplementedForScoring: Bool,
        _ sourceImageNote: String,
        needsReview: Bool = false
    ) -> WeeklyGoalDefinition {
        WeeklyGoalDefinition(
            id: id,
            boardSet: set,
            week: week,
            sourceExpansion: set.sourceExpansion,
            source: set == .base ? .baseTilePool : .sharksAndReefsTilePool,
            title: title,
            shortTitle: title,
            description: "\(title)：按实体周目标 tile 计分。",
            iconTokens: iconTokens,
            kind: kind,
            pointsPerUnit: pointsPerUnit,
            sourceImageNote: sourceImageNote,
            isImplementedForScoring: isImplementedForScoring,
            needsReview: needsReview
        )
    }
}

private extension AchievementBoardSet {
    var idPrefix: String {
        switch self {
        case .base:
            return "base"
        case .sharksAndReefs:
            return "sr"
        }
    }

    var sourceExpansion: Expansion? {
        switch self {
        case .base:
            return nil
        case .sharksAndReefs:
            return .sharksAndReefs
        }
    }
}

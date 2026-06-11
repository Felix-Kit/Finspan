import Foundation

struct GameConfig: Codable, Equatable, Sendable {
    var playerCount: Int
    var enabledExpansions: [Expansion]
    var rulesetVersion: RulesetVersion
    var randomSeed: Int
    var gameDataMode: GameDataMode
    var weeklyGoalSetup: WeeklyGoalSetupConfig
    var roomName: String

    init(
        playerCount: Int,
        enabledExpansions: [Expansion] = [],
        rulesetVersion: RulesetVersion = .baseGameV1,
        randomSeed: Int,
        gameDataMode: GameDataMode = .sample,
        weeklyGoalSetup: WeeklyGoalSetupConfig = WeeklyGoalSetupConfig(),
        roomName: String = ""
    ) {
        self.playerCount = playerCount
        self.enabledExpansions = enabledExpansions
        self.rulesetVersion = rulesetVersion
        self.randomSeed = randomSeed
        self.gameDataMode = gameDataMode
        self.weeklyGoalSetup = weeklyGoalSetup
        self.roomName = roomName
    }

    private enum CodingKeys: String, CodingKey {
        case playerCount
        case enabledExpansions
        case rulesetVersion
        case randomSeed
        case gameDataMode
        case weeklyGoalSetup
        case roomName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerCount = try container.decode(Int.self, forKey: .playerCount)
        enabledExpansions = try container.decodeIfPresent([Expansion].self, forKey: .enabledExpansions) ?? []
        rulesetVersion = try container.decodeIfPresent(RulesetVersion.self, forKey: .rulesetVersion) ?? .baseGameV1
        randomSeed = try container.decode(Int.self, forKey: .randomSeed)
        gameDataMode = try container.decodeIfPresent(GameDataMode.self, forKey: .gameDataMode) ?? .sample
        weeklyGoalSetup = try container.decodeIfPresent(WeeklyGoalSetupConfig.self, forKey: .weeklyGoalSetup)
            ?? WeeklyGoalSetupConfig()
        roomName = try container.decodeIfPresent(String.self, forKey: .roomName) ?? ""
    }
}

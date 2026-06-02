import Foundation

struct GameConfig: Codable, Equatable, Sendable {
    var playerCount: Int
    var enabledExpansions: [Expansion]
    var rulesetVersion: RulesetVersion
    var randomSeed: Int

    init(
        playerCount: Int,
        enabledExpansions: [Expansion] = [],
        rulesetVersion: RulesetVersion = .baseGameV1,
        randomSeed: Int
    ) {
        self.playerCount = playerCount
        self.enabledExpansions = enabledExpansions
        self.rulesetVersion = rulesetVersion
        self.randomSeed = randomSeed
    }
}

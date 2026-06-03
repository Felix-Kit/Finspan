import Foundation

struct ResourceKind: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ResourceKind {
    static let egg = ResourceKind(rawValue: "egg")
    static let young = ResourceKind(rawValue: "young")
}

enum Cost: Codable, Equatable, Sendable {
    case discardCards(count: Int)
    case resource(kind: ResourceKind, count: Int)
}

struct Requirement: Codable, Equatable, Sendable {
    var kind: String
    var value: String
}

struct AbilityCondition: Codable, Equatable, Sendable {
    var kind: String
    var value: String
}

struct AbilityEffect: Codable, Equatable, Sendable {
    var kind: String
    var value: String
}

enum AbilityTrigger: String, Codable, Equatable, Sendable {
    case whenPlayed
    case whenActivated
    case endOfTurn
    case endOfWeek
    case endOfGame
}

struct AbilityDefinition: Codable, Equatable, Sendable {
    var id: String
    var trigger: AbilityTrigger
    var conditions: [AbilityCondition]
    var effects: [AbilityEffect]
}

struct ScoreCategory: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct ScoreBreakdown: Codable, Equatable, Sendable {
    var categories: [ScoreCategory: Int]

    init(categories: [ScoreCategory: Int] = [:]) {
        self.categories = categories
    }
}

struct AchievementDefinition: Codable, Equatable, Sendable {
    var id: String
    var requirements: [Requirement]
    var scoreCategory: ScoreCategory?
}

protocol RuleModule {
    var id: String { get }
}

struct Ruleset {
    var version: RulesetVersion
    var modules: [any RuleModule]

    init(version: RulesetVersion, modules: [any RuleModule] = []) {
        self.version = version
        self.modules = modules
    }
}

struct BaseGameRuleModule: RuleModule {
    let id = "baseGame"
}

import Foundation

struct ResourceKind: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ResourceKind {
    nonisolated static let egg = ResourceKind(rawValue: "egg")
    nonisolated static let young = ResourceKind(rawValue: "young")
    nonisolated static let school = ResourceKind(rawValue: "school")
}

enum Cost: Codable, Equatable, Sendable {
    case discardCards(count: Int)
    case resource(kind: ResourceKind, count: Int)
    case coverShorterFish(count: Int)
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

typealias AbilityID = String

enum AbilityTrigger: String, Codable, Equatable, Sendable {
    case whenPlayed
    case ifActivated
    case gameEnd
}

struct AbilityDefinition: Codable, Equatable, Sendable {
    var abilityId: AbilityID
    var trigger: AbilityTrigger
    var effects: [AbilityEffectUnit]
    var canResolveInAnyOrder: Bool
    var isOptional: Bool
    var displayText: String

    nonisolated init(
        abilityId: AbilityID,
        trigger: AbilityTrigger,
        effects: [AbilityEffectUnit],
        canResolveInAnyOrder: Bool = false,
        isOptional: Bool = true,
        displayText: String = ""
    ) {
        self.abilityId = abilityId
        self.trigger = trigger
        self.effects = effects
        self.canResolveInAnyOrder = canResolveInAnyOrder
        self.isOptional = isOptional
        self.displayText = displayText
    }
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

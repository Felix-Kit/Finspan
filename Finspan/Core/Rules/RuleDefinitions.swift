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

enum CoralRequirementDiveSite: String, Codable, Equatable, Sendable {
    case any
    case blue
    case purple
    case green
}

struct CoralRequirement: Codable, Equatable, Sendable {
    var diveSite: CoralRequirementDiveSite
    var count: Int
}

extension Requirement {
    nonisolated static let coralKind = "coral"

    nonisolated init(coralRequirement: CoralRequirement) {
        kind = Self.coralKind
        value = "\(coralRequirement.diveSite.rawValue):\(coralRequirement.count)"
    }

    var coralRequirement: CoralRequirement? {
        guard kind == Self.coralKind else {
            return nil
        }
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let diveSite = CoralRequirementDiveSite(rawValue: parts[0]),
              let count = Int(parts[1])
        else {
            return nil
        }
        return CoralRequirement(diveSite: diveSite, count: count)
    }
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

    static let coral = ScoreCategory(rawValue: "coral")
    static let completeReefBonus = ScoreCategory(rawValue: "completeReefBonus")
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

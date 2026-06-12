import Foundation

struct DiveResolutionQueue: Codable, Equatable, Sendable {
    var queueId: DiveResolutionQueueID
    var playerId: PlayerID
    var diveSite: DiveActionSite
    var steps: [DiveResolutionStep]
    var currentStepIndex: Int

    var isCompleted: Bool {
        currentStepIndex >= steps.count
    }

    var currentStep: DiveResolutionStep? {
        guard steps.indices.contains(currentStepIndex) else {
            return nil
        }
        return steps[currentStepIndex]
    }
}

struct DiveResolutionStep: Codable, Equatable, Sendable {
    var stepId: DiveResolutionStepID
    var source: DiveResolutionStepSource
    var pendingChoice: PendingChoice
}

enum DiveResolutionStepSource: Codable, Equatable, Sendable {
    case printedDiveBonus(OceanZone)
    case coralReefOverlay(diveSite: DiveSite)
    case bottomBonus
    case fishAbility(cardId: CardID, address: OceanSlotAddress)
    case compoundFishAbility(cardId: CardID, address: OceanSlotAddress)
}

enum DiveResolutionQueueUpdate: Codable, Equatable, Sendable {
    case updated(DiveResolutionQueue)
    case advanced(DiveResolutionQueue)
    case completed(queueId: DiveResolutionQueueID)
}

/// Reserved progress model for a future compound fish ability step.
///
/// A compound fish ability will be represented by one `DiveResolutionStep`.
/// That step may create multiple pending choices internally, and the dive queue
/// must not advance until all effects are completed or the player skips the
/// remaining optional effects.
struct CompoundAbilityProgress: Codable, Equatable, Sendable {
    var abilityId: String
    var playerId: PlayerID
    var sourceCardId: CardID
    var sourceAddress: OceanSlotAddress
    var remainingEffects: [AbilityEffectUnit]
    var completedEffects: [AbilityEffectUnit]
    var canResolveInAnyOrder: Bool
    var isOptional: Bool
}

enum AbilityEffectUnit: Codable, Equatable, Sendable {
    case drawFish(count: Int)
    case placeEgg(count: Int)
    case hatchEgg(count: Int)
    case placeYoung(count: Int)
    case moveYoungOrSchool(count: Int)
    case recoverFromDiscardOrDraw(count: Int)
    case gameEndScore(condition: GameEndScoreCondition, points: Int)
    case placeEggOnMatchingFish(filter: EggPlacementFilter, mode: EggPlacementMode)
    case playFishFromHand(filter: HandFishFilter, placement: FishPlacementConstraint, costMode: PlayFishCostMode)
    case gainCoral(selector: CoralDiveSiteSelector, count: Int)
    case scatterSchool(count: Int)
    case consumeFishFromHand(count: Int)
    case playFishForFree(filter: FreePlayFishFilter, count: Int)
    case unsupported
}

enum GameEndScoreCondition: Codable, Equatable, Sendable {
    case noTokensOnThisFish
    case consumedFishUnderThisFishAtLeast(Int)
    case youngOnThisFishExactly(Int)
    case bottomRow
    case schoolOnThisFish
    case eggYoungAndSchoolOnThisFish
    case allDiveSitesHaveCoralAtLeast(Int)
    case anyDiveSiteHasCoralAtLeast(Int)
}

enum EggPlacementFilter: Codable, Equatable, Sendable {
    case lengthBucket(FishLengthBucket)
    case topRow
    case bottomRow
    case diveSite(DiveSite)
    case tag(String)
}

enum EggPlacementMode: Codable, Equatable, Sendable {
    case onEachEligibleFish
    case chooseOneEligibleFish
}

enum HandFishFilter: Codable, Equatable, Sendable {
    case any
    case tag(String)
    case lengthBucket(FishLengthBucket)
    case unsupported(String)
}

enum FishPlacementConstraint: Codable, Equatable, Sendable {
    case topRow
    case bottomRow
    case sunlight
    case diveSite(DiveSite)
}

enum PlayFishCostMode: Codable, Equatable, Sendable {
    case payCost
}

enum FreePlayFishFilter: Codable, Equatable, Sendable {
    case any
    case tag(String)
    case lengthBucket(FishLengthBucket)
    case unsupported(String)
}

enum FishLengthBucket: String, Codable, Equatable, Sendable {
    case small
    case medium
    case large
}

enum CoralDiveSiteSelector: String, Codable, Equatable, Sendable {
    case blue
    case purple
    case green
    case any

    var fixedDiveSite: DiveSite? {
        switch self {
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .green:
            return .green
        case .any:
            return nil
        }
    }
}

import Foundation

typealias AbilityExecutionId = String
typealias EffectGraphId = String
typealias EffectNodeId = String
typealias CoralColor = DiveSite

struct AbilityIR: Codable, Equatable, Sendable {
    var id: AbilityExecutionId
    var sourceAbilityId: AbilityID
    var sourceCardId: CardID
    var sourcePlayerId: PlayerID
    var trigger: AbilityTrigger
    var graph: EffectGraph
    var parentExecutionId: AbilityExecutionId?
    var debugLabel: String
    var debugDescription: String
}

struct EffectGraph: Codable, Equatable, Sendable {
    var graphId: EffectGraphId
    var nodes: [EffectNode]
    var edges: [EffectEdge]
}

struct EffectEdge: Codable, Equatable, Sendable {
    var from: EffectNodeId
    var to: EffectNodeId
}

struct EffectNode: Codable, Equatable, Sendable {
    var id: EffectNodeId
    var effect: AbilityEffectUnit
    var scope: EffectScope
    var conditions: [EffectCondition]
    var dependencies: [EffectNodeId]
    var optionality: EffectOptionality
    var metadata: EffectNodeMetadata
}

enum EffectScope: Codable, Equatable, Sendable {
    case sourcePlayer
    case targetPlayer(PlayerID)
    case allPlayers(startingFrom: PlayerID)
}

enum EffectCondition: Codable, Equatable, Sendable {
    case sourceDiveSiteHasColoredCoral(color: CoralColor, minimum: Int)
    case sourceDiveSiteHasNoCoral
    case sourceFishVisible
    case sourceFishLocated
}

enum EffectOptionality: String, Codable, Equatable, Sendable {
    case required
    case optional
}

struct EffectNodeMetadata: Codable, Equatable, Sendable {
    var sourceAddress: OceanSlotAddress?
    var debugLabel: String
    var debugDescription: String
    var legacyChoiceKind: PendingChoiceKind?
    var decisionIndex: Int
    var targetRequirement: EffectTargetRequirement? = nil
    var paymentRequirement: EffectPaymentRequirement? = nil
    var resourceRequirement: EffectResourceRequirement? = nil
    var rewardTokenRequirement: EffectRewardTokenRequirement? = nil
    var stagedSelection: EffectStagedSelectionRequirement? = nil
}

struct PendingEffectSet: Codable, Equatable, Sendable {
    var executionId: AbilityExecutionId
    var sourceCardId: CardID
    var sourceAbilityId: AbilityID?
    var sourcePlayerId: PlayerID
    var activePlayerId: PlayerID
    var targetPlayerId: PlayerID?
    var trigger: AbilityTrigger?
    var decisionIndex: Int
    var parentExecutionId: AbilityExecutionId?
    var graph: EffectGraph?
    var available: [EffectNode]
    var blocked: [BlockedEffectNode]
    var completed: [CompletedEffectNode]
    var skipped: [SkippedEffectNode]
    var debugLabel: String
    var debugDescription: String
}

enum PendingEffectIntent: Codable, Equatable, Sendable {
    case resolveEffect(
        executionId: AbilityExecutionId,
        effectNodeId: EffectNodeId,
        sourcePlayerId: PlayerID,
        targetPlayerId: PlayerID?,
        payload: EffectResolutionPayload
    )
    case skipEffect(
        executionId: AbilityExecutionId,
        effectNodeId: EffectNodeId,
        sourcePlayerId: PlayerID,
        targetPlayerId: PlayerID?
    )
    case skipRemaining(
        executionId: AbilityExecutionId,
        sourcePlayerId: PlayerID,
        targetPlayerId: PlayerID?
    )

    nonisolated var executionId: AbilityExecutionId {
        switch self {
        case let .resolveEffect(executionId, _, _, _, _),
             let .skipEffect(executionId, _, _, _),
             let .skipRemaining(executionId, _, _):
            return executionId
        }
    }

    nonisolated var effectNodeId: EffectNodeId? {
        switch self {
        case let .resolveEffect(_, effectNodeId, _, _, _),
             let .skipEffect(_, effectNodeId, _, _):
            return effectNodeId
        case .skipRemaining:
            return nil
        }
    }

    nonisolated var sourcePlayerId: PlayerID {
        switch self {
        case let .resolveEffect(_, _, sourcePlayerId, _, _),
             let .skipEffect(_, _, sourcePlayerId, _),
             let .skipRemaining(_, sourcePlayerId, _):
            return sourcePlayerId
        }
    }

    nonisolated var targetPlayerId: PlayerID? {
        switch self {
        case let .resolveEffect(_, _, _, targetPlayerId, _),
             let .skipEffect(_, _, _, targetPlayerId),
             let .skipRemaining(_, _, targetPlayerId):
            return targetPlayerId
        }
    }
}

enum EffectResolutionPayload: Codable, Equatable, Sendable {
    case none
    case targetSlot(OceanSlotAddress)
    case selectedCard(CardID)
    case selectedDiscardCard(CardID)
    case payment(PlayFishPayment)
    case resourceSource(OceanSlotAddress)
}

struct EffectTargetRequirement: Codable, Equatable, Sendable {
    var kind: EffectTargetKind
    var ownerPlayerId: PlayerID
    var effectNodeId: EffectNodeId
    var debugLabel: String
    var allowedZones: [OceanZone]? = nil
    var allowedDiveSites: [DiveSite]? = nil
    var filters: [EffectTargetFilter] = []
    var minCount: Int = 1
    var maxCount: Int = 1
}

enum EffectTargetKind: Codable, Equatable, Sendable {
    case slot(EffectSlotTargetKind)
    case fish
    case visibleFish
    case handCard
    case discardCard
    case coralReef
    case sourceTargetSlotPair
}

enum EffectSlotTargetKind: String, Codable, Equatable, Sendable {
    case placeEgg
    case placeYoung
    case hatchEgg
    case scatterSchoolSource
    case scatterSchoolYoungTarget
    case consumeFishConsumer
    case freePlayTarget
    case playFishFromHandTarget
}

enum EffectTargetFilter: Codable, Equatable, Sendable {
    case hasVisibleFish
    case hasEgg
    case hasSchool
    case canAcceptEgg
    case canAcceptYoung
    case canHatchEgg
    case canScatterSchoolYoung
    case canConsumeHandFish
    case canPlaySelectedFish
    case matchesFishFilter(String)
}

struct EffectPaymentRequirement: Codable, Equatable, Sendable {
    var paymentKind: EffectPaymentKind
    var allowedSources: [EffectPaymentSourceKind]
    var requiredResources: [EffectRequiredPaymentResource]
    var isOptional: Bool
    var costWaived: Bool
    var debugLabel: String
}

enum EffectPaymentKind: Codable, Equatable, Sendable {
    case coral
    case playFish
    case freePlay
}

enum EffectPaymentSourceKind: Codable, Equatable, Sendable {
    case egg
    case young
    case handCard
    case discardCard
    case coralReef
    case waivedCost
}

struct EffectRequiredPaymentResource: Codable, Equatable, Sendable {
    var kind: ResourceKind?
    var count: Int
    var source: EffectPaymentSourceKind
}

struct EffectResourceRequirement: Codable, Equatable, Sendable {
    var resourceKind: ResourceKind
    var ownerPlayerId: PlayerID
    var minCount: Int
    var maxCount: Int
    var source: EffectResourceSource
}

enum EffectResourceSource: Codable, Equatable, Sendable {
    case oceanSlot
    case coralReef
}

struct EffectRewardTokenRequirement: Codable, Equatable, Sendable {
    var tokenKind: EffectRewardTokenKind
    var count: Int
    var source: EffectRewardTokenSource
    var isSelectable: Bool
    var debugLabel: String
}

enum EffectRewardTokenKind: Codable, Equatable, Sendable {
    case drawFish
    case recoverFromDiscardOrDraw
    case placeEgg
    case placeYoung
    case hatchEgg
    case moveYoungOrSchool
    case gainCoral
    case scatterSchool
    case consumeFishFromHand
    case playFishForFree
    case playFishFromHand
    case skipOrEnd
    case unsupported
}

enum EffectRewardTokenSource: Codable, Equatable, Sendable {
    case ability
    case compoundPool
    case printedDiveReward
    case coralPayment
    case stagedSelection
    case legacyFallback
}

struct EffectStagedSelectionRequirement: Codable, Equatable, Sendable {
    var stage: EffectSelectionStage
    var nextStageHint: EffectSelectionStage?
    var canResolveWithCurrentPayload: Bool
    var debugLabel: String
}

enum EffectSelectionStage: Codable, Equatable, Sendable {
    case selectTargetSlot
    case selectDiscardCard
    case selectMoveSource
    case selectMoveTarget
    case selectCoralPaymentSource
    case selectCoralPaymentCard
    case selectScatterSchoolSource
    case selectScatterSchoolYoungTarget
    case selectConsumerFish
    case selectConsumedHandFish
    case selectFreePlayHandFish
    case selectFreePlayTargetSlot
    case selectPlayFromHandFish
    case selectPlayFromHandTargetSlot
    case selectPlayFromHandPayment
}

enum PendingEffectIntentAdapterError: Equatable, Error {
    case executionMismatch
    case unavailableEffectNode(EffectNodeId)
    case unsupportedPayload
}

struct BlockedEffectNode: Codable, Equatable, Sendable {
    var node: EffectNode
    var reason: BlockedEffectReason
    var debugDescription: String
}

enum BlockedEffectReason: String, Codable, Equatable, Sendable {
    case waitingForDependency
    case currentlyIllegal
    case sourceConditionNotMet
    case unsupported
}

struct CompletedEffectNode: Codable, Equatable, Sendable {
    var effectNodeId: EffectNodeId
    var effect: AbilityEffectUnit
    var sourcePlayerId: PlayerID
    var targetPlayerId: PlayerID?
    var decisionIndex: Int
    var debugLabel: String
}

struct SkippedEffectNode: Codable, Equatable, Sendable {
    var effectNodeId: EffectNodeId
    var effect: AbilityEffectUnit?
    var sourcePlayerId: PlayerID
    var targetPlayerId: PlayerID?
    var decisionIndex: Int
    var debugLabel: String
}

enum AbilityEngineV2Adapter {
    nonisolated static func abilityIR(
        for ability: AbilityDefinition,
        sourceCardId: CardID,
        sourcePlayerId: PlayerID,
        sourceAddress: OceanSlotAddress?,
        allPlayerIds: [PlayerID] = [],
        parentExecutionId: AbilityExecutionId? = nil
    ) -> AbilityIR {
        let executionId = executionId(
            abilityId: ability.abilityId,
            sourceCardId: sourceCardId,
            sourcePlayerId: sourcePlayerId,
            parentExecutionId: parentExecutionId
        )
        let graph = effectGraph(
            for: ability,
            executionId: executionId,
            sourcePlayerId: sourcePlayerId,
            sourceAddress: sourceAddress,
            allPlayerIds: allPlayerIds
        )
        return AbilityIR(
            id: executionId,
            sourceAbilityId: ability.abilityId,
            sourceCardId: sourceCardId,
            sourcePlayerId: sourcePlayerId,
            trigger: ability.trigger,
            graph: graph,
            parentExecutionId: parentExecutionId,
            debugLabel: ability.displayText,
            debugDescription: "AbilityEngineV2 IR for \(ability.abilityId)"
        )
    }

    nonisolated static func pendingEffectSet(for choice: PendingChoice) -> PendingEffectSet {
        let sourceAbilityId = choice.abilityDefinition?.abilityId
        let sourceCardId = sourceCardId(for: choice)
        let sourcePlayerId = sourcePlayerId(for: choice)
        let activePlayerId = choice.playerId
        let targetPlayerId = choice.allPlayersProgress?.currentTargetPlayerId ?? activePlayerId
        let decisionIndex = decisionIndex(for: choice)
        let executionId = executionId(
            abilityId: sourceAbilityId ?? choice.choiceId,
            sourceCardId: sourceCardId,
            sourcePlayerId: sourcePlayerId,
            parentExecutionId: nil
        )
        let ir = choice.abilityDefinition.map {
            abilityIR(
                for: $0,
                sourceCardId: sourceCardId,
                sourcePlayerId: sourcePlayerId,
                sourceAddress: sourceAddress(for: choice),
                allPlayerIds: allPlayersTargetIds(for: choice)
            )
        }
        let nodes = currentNodes(for: choice, sourcePlayerId: sourcePlayerId, decisionIndex: decisionIndex)
        return PendingEffectSet(
            executionId: executionId,
            sourceCardId: sourceCardId,
            sourceAbilityId: sourceAbilityId,
            sourcePlayerId: sourcePlayerId,
            activePlayerId: activePlayerId,
            targetPlayerId: targetPlayerId,
            trigger: choice.abilityDefinition?.trigger,
            decisionIndex: decisionIndex,
            parentExecutionId: nil,
            graph: ir?.graph,
            available: nodes.available,
            blocked: nodes.blocked,
            completed: completedNodes(for: choice, sourcePlayerId: sourcePlayerId),
            skipped: skippedNodes(for: choice, sourcePlayerId: sourcePlayerId),
            debugLabel: choice.abilityDefinition?.displayText ?? "\(choice.kind)",
            debugDescription: "PendingEffectSet bridged from legacy PendingChoice \(choice.choiceId)"
        )
    }

    nonisolated static func legacyResolution(
        for intent: PendingEffectIntent,
        in choice: PendingChoice
    ) throws -> PendingChoiceResolution {
        let effectSet = choice.v2PendingEffectSet
        guard intent.executionId == effectSet.executionId else {
            throw PendingEffectIntentAdapterError.executionMismatch
        }

        switch intent {
        case let .skipEffect(_, effectNodeId, _, _):
            guard effectSet.available.contains(where: { $0.id == effectNodeId }) else {
                throw PendingEffectIntentAdapterError.unavailableEffectNode(effectNodeId)
            }
            return .skip
        case .skipRemaining:
            return choice.kind == .compoundAbility ? .finishAbility : .skip
        case let .resolveEffect(_, effectNodeId, _, _, payload):
            guard let node = effectSet.available.first(where: { $0.id == effectNodeId }) else {
                throw PendingEffectIntentAdapterError.unavailableEffectNode(effectNodeId)
            }
            return try legacyResolution(for: node.effect, payload: payload, choice: choice)
        }
    }

    nonisolated static func targetRequirement(
        for node: EffectNode,
        effectSet: PendingEffectSet
    ) -> EffectTargetRequirement? {
        if let targetRequirement = node.metadata.targetRequirement {
            var requirement = targetRequirement
            requirement.ownerPlayerId = effectSet.targetPlayerId ?? effectSet.activePlayerId
            return requirement
        }

        let ownerPlayerId = effectSet.targetPlayerId ?? effectSet.activePlayerId
        switch node.effect {
        case .placeEgg:
            return EffectTargetRequirement(
                kind: .slot(.placeEgg),
                ownerPlayerId: ownerPlayerId,
                effectNodeId: node.id,
                debugLabel: node.metadata.debugLabel
            )
        case .placeYoung:
            return EffectTargetRequirement(
                kind: .slot(.placeYoung),
                ownerPlayerId: ownerPlayerId,
                effectNodeId: node.id,
                debugLabel: node.metadata.debugLabel
            )
        case .hatchEgg:
            return EffectTargetRequirement(
                kind: .slot(.hatchEgg),
                ownerPlayerId: ownerPlayerId,
                effectNodeId: node.id,
                debugLabel: node.metadata.debugLabel
            )
        case .recoverFromDiscardOrDraw:
            return EffectTargetRequirement(
                kind: .discardCard,
                ownerPlayerId: ownerPlayerId,
                effectNodeId: node.id,
                debugLabel: node.metadata.debugLabel
            )
        case .drawFish,
             .moveYoungOrSchool,
             .gameEndScore,
             .placeEggOnMatchingFish,
             .playFishFromHand,
             .gainCoral,
             .scatterSchool,
             .consumeFishFromHand,
             .playFishForFree,
             .unsupported:
            return nil
        }
    }

    nonisolated static func rewardTokenRequirement(for node: EffectNode) -> EffectRewardTokenRequirement? {
        node.metadata.rewardTokenRequirement
    }

    nonisolated static func paymentRequirement(for node: EffectNode) -> EffectPaymentRequirement? {
        node.metadata.paymentRequirement
    }

    nonisolated static func stagedSelectionRequirement(for node: EffectNode) -> EffectStagedSelectionRequirement? {
        node.metadata.stagedSelection
    }

    nonisolated private static func legacyResolution(
        for effect: AbilityEffectUnit,
        payload: EffectResolutionPayload,
        choice: PendingChoice
    ) throws -> PendingChoiceResolution {
        switch (effect, payload) {
        case let (.drawFish(count), .none):
            return choice.kind == .compoundAbility
                ? .chooseAbilityEffect(.drawFish(count: 1))
                : .draw(count: count)
        case (.recoverFromDiscardOrDraw, .none):
            return choice.kind == .compoundAbility
                ? .chooseAbilityEffect(.recoverFromDiscardOrDraw(count: 1))
                : .drawFromDeck
        case let (.recoverFromDiscardOrDraw, .selectedDiscardCard(cardId)):
            return choice.kind == .compoundAbility
                ? .chooseAbilityEffect(.recoverFromDiscardOrDraw(count: 1))
                : .recoverCard(cardId)
        case (.placeEgg, .none):
            return .chooseAbilityEffect(.placeEgg(count: 1))
        case (.placeYoung, .none):
            return .chooseAbilityEffect(.placeYoung(count: 1))
        case (.hatchEgg, .none):
            return .chooseAbilityEffect(.hatchEgg(count: 1))
        case (.placeEgg, let .targetSlot(address)),
             (.placeYoung, let .targetSlot(address)),
             (.hatchEgg, let .targetSlot(address)):
            return choice.kind == .compoundAbility
                ? .chooseAbilityEffect(effectWithCount(effect, count: 1))
                : .chooseTarget(address)
        default:
            throw PendingEffectIntentAdapterError.unsupportedPayload
        }
    }

    nonisolated private static func effectGraph(
        for ability: AbilityDefinition,
        executionId: AbilityExecutionId,
        sourcePlayerId: PlayerID,
        sourceAddress: OceanSlotAddress?,
        allPlayerIds: [PlayerID]
    ) -> EffectGraph {
        if let conditionalBonus = ability.conditionalBonus {
            return conditionalBonusGraph(
                ability: ability,
                conditionalBonus: conditionalBonus,
                executionId: executionId,
                sourcePlayerId: sourcePlayerId,
                sourceAddress: sourceAddress
            )
        }

        let scope: EffectScope = ability.appliesToAllPlayers == true
            ? .allPlayers(startingFrom: sourcePlayerId)
            : .sourcePlayer
        let nodes = nodes(
            for: ability.effects,
            prefix: "effect",
            scope: scope,
            ownerPlayerId: sourcePlayerId,
            sourceAddress: sourceAddress,
            dependencies: ability.canResolveInAnyOrder ? [] : nil,
            optionality: ability.isOptional ? .optional : .required,
            decisionOffset: 0
        )
        return EffectGraph(
            graphId: "\(executionId)-graph",
            nodes: nodes,
            edges: edges(for: nodes)
        )
    }

    nonisolated private static func conditionalBonusGraph(
        ability: AbilityDefinition,
        conditionalBonus: ConditionalBonusAbilityDefinition,
        executionId: AbilityExecutionId,
        sourcePlayerId: PlayerID,
        sourceAddress: OceanSlotAddress?
    ) -> EffectGraph {
        let baseNodes = nodes(
            for: conditionalBonus.baseEffects,
            prefix: "base",
            scope: .sourcePlayer,
            ownerPlayerId: sourcePlayerId,
            sourceAddress: sourceAddress,
            dependencies: conditionalBonus.baseCanResolveInAnyOrder ? [] : nil,
            optionality: .optional,
            decisionOffset: 0
        )
        let baseDependencyIds = baseNodes.map(\.id)
        let bonusNodes = nodes(
            for: conditionalBonus.bonusEffects,
            prefix: "bonus",
            scope: .sourcePlayer,
            ownerPlayerId: sourcePlayerId,
            sourceAddress: sourceAddress,
            conditions: [
                .sourceFishLocated,
                .sourceFishVisible,
                .sourceDiveSiteHasColoredCoral(
                    color: conditionalBonus.requirement.coralColor,
                    minimum: conditionalBonus.requirement.count
                )
            ],
            dependencies: baseDependencyIds,
            optionality: .optional,
            decisionOffset: baseNodes.count
        )
        let allNodes = baseNodes + bonusNodes
        return EffectGraph(
            graphId: "\(executionId)-graph",
            nodes: allNodes,
            edges: edges(for: allNodes)
        )
    }

    nonisolated private static func nodes(
        for effects: [AbilityEffectUnit],
        prefix: String,
        scope: EffectScope,
        ownerPlayerId: PlayerID,
        sourceAddress: OceanSlotAddress?,
        conditions: [EffectCondition] = [],
        dependencies explicitDependencies: [EffectNodeId]?,
        optionality: EffectOptionality,
        decisionOffset: Int
    ) -> [EffectNode] {
        var priorNodeIds: [EffectNodeId] = []
        return effects.enumerated().map { index, effect in
            let nodeId = "\(prefix)-\(index)-\(effectKey(effect))"
            let dependencies = explicitDependencies ?? priorNodeIds
            priorNodeIds.append(nodeId)
            return EffectNode(
                id: nodeId,
                effect: effect,
                scope: scope,
                conditions: conditions + sourceConditions(for: effect),
                dependencies: dependencies,
                optionality: optionality,
                metadata: metadata(
                    for: effect,
                    sourceAddress: sourceAddress,
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: nodeId,
                    debugDescription: "\(prefix) effect \(index): \(effectKey(effect))",
                    legacyChoiceKind: pendingChoiceKind(for: effect),
                    decisionIndex: decisionOffset + index,
                    stagedSelection: nil
                )
            )
        }
    }

    nonisolated private static func edges(for nodes: [EffectNode]) -> [EffectEdge] {
        nodes.flatMap { node in
            node.dependencies.map { EffectEdge(from: $0, to: node.id) }
        }
    }

    nonisolated private static func currentNodes(
        for choice: PendingChoice,
        sourcePlayerId: PlayerID,
        decisionIndex: Int
    ) -> (available: [EffectNode], blocked: [BlockedEffectNode]) {
        if let progress = choice.compoundAbilityProgress {
            let remaining = currentlySelectableEffects(in: progress)
            let available = remaining.enumerated().map { index, effect in
                pendingNode(
                    id: "pending-\(index)-\(effectKey(effect))",
                    effect: effect,
                    choice: choice,
                    sourcePlayerId: sourcePlayerId,
                    decisionIndex: decisionIndex + index
                )
            }
            let blocked = blockedEffects(in: progress, available: remaining, choice: choice, sourcePlayerId: sourcePlayerId)
            return (available, blocked)
        }

        guard let effect = currentEffect(for: choice) else {
            return ([], [])
        }
        if case .unsupported = effect {
            let node = pendingNode(
                id: "pending-unsupported",
                effect: effect,
                choice: choice,
                sourcePlayerId: sourcePlayerId,
                decisionIndex: decisionIndex
            )
            return ([], [BlockedEffectNode(node: node, reason: .unsupported, debugDescription: "Unsupported legacy pending choice")])
        }
        return ([
            pendingNode(
                id: "pending-\(effectKey(effect))",
                effect: effect,
                choice: choice,
                sourcePlayerId: sourcePlayerId,
                decisionIndex: decisionIndex
            )
        ], [])
    }

    nonisolated private static func currentlySelectableEffects(in progress: CompoundAbilityProgress) -> [AbilityEffectUnit] {
        let normalized = progress.remainingEffects
            .filter { effectCount($0) > 0 }
            .map(normalizedSingleEffect)
        guard progress.canResolveInAnyOrder else {
            return normalized.first.map { [$0] } ?? []
        }
        return normalized.reduce(into: []) { result, effect in
            guard !result.contains(where: { effectKey($0) == effectKey(effect) }) else {
                return
            }
            result.append(effect)
        }
    }

    nonisolated private static func blockedEffects(
        in progress: CompoundAbilityProgress,
        available: [AbilityEffectUnit],
        choice: PendingChoice,
        sourcePlayerId: PlayerID
    ) -> [BlockedEffectNode] {
        let availableKeys = Set(available.map(effectKey))
        return progress.remainingEffects
            .filter { effectCount($0) > 0 && !availableKeys.contains(effectKey(normalizedSingleEffect($0))) }
            .enumerated()
            .map { index, effect in
                let node = pendingNode(
                    id: "blocked-\(index)-\(effectKey(effect))",
                    effect: normalizedSingleEffect(effect),
                    choice: choice,
                    sourcePlayerId: sourcePlayerId,
                    decisionIndex: progress.completedEffects.count + index
                )
                return BlockedEffectNode(
                    node: node,
                    reason: .waitingForDependency,
                    debugDescription: "Effect is waiting for an earlier ordered dependency"
                )
            }
    }

    nonisolated private static func pendingNode(
        id: EffectNodeId,
        effect: AbilityEffectUnit,
        choice: PendingChoice,
        sourcePlayerId: PlayerID,
        decisionIndex: Int
    ) -> EffectNode {
        let scope: EffectScope
        if let _ = choice.allPlayersProgress {
            scope = .targetPlayer(choice.playerId)
        } else {
            scope = .sourcePlayer
        }

        let stagedSelection = stagedSelectionRequirement(for: choice, effect: effect)
        return EffectNode(
            id: id,
            effect: effect,
            scope: scope,
            conditions: sourceConditions(for: effect),
            dependencies: [],
            optionality: choice.isOptional ? .optional : .required,
            metadata: metadata(
                for: effect,
                sourceAddress: sourceAddress(for: choice),
                ownerPlayerId: choice.playerId,
                effectNodeId: id,
                debugDescription: "Legacy pending choice \(choice.choiceId): \(effectKey(effect))",
                legacyChoiceKind: choice.kind,
                decisionIndex: decisionIndex,
                stagedSelection: stagedSelection
            )
        )
    }

    nonisolated private static func metadata(
        for effect: AbilityEffectUnit,
        sourceAddress: OceanSlotAddress?,
        ownerPlayerId: PlayerID,
        effectNodeId: EffectNodeId,
        debugDescription: String,
        legacyChoiceKind: PendingChoiceKind?,
        decisionIndex: Int,
        stagedSelection: EffectStagedSelectionRequirement?
    ) -> EffectNodeMetadata {
        let debugLabel = effectKey(effect)
        return EffectNodeMetadata(
            sourceAddress: sourceAddress,
            debugLabel: debugLabel,
            debugDescription: debugDescription,
            legacyChoiceKind: legacyChoiceKind,
            decisionIndex: decisionIndex,
            targetRequirement: targetRequirement(
                for: effect,
                ownerPlayerId: ownerPlayerId,
                effectNodeId: effectNodeId,
                debugLabel: debugLabel,
                stagedSelection: stagedSelection
            ),
            paymentRequirement: paymentRequirement(for: effect, stagedSelection: stagedSelection, debugLabel: debugLabel),
            resourceRequirement: resourceRequirement(for: effect, ownerPlayerId: ownerPlayerId),
            rewardTokenRequirement: rewardTokenRequirement(for: effect, stagedSelection: stagedSelection, debugLabel: debugLabel),
            stagedSelection: stagedSelection
        )
    }

    nonisolated private static func targetRequirement(
        for effect: AbilityEffectUnit,
        ownerPlayerId: PlayerID,
        effectNodeId: EffectNodeId,
        debugLabel: String,
        stagedSelection: EffectStagedSelectionRequirement?
    ) -> EffectTargetRequirement? {
        if let stage = stagedSelection?.stage {
            switch stage {
            case .selectTargetSlot:
                return EffectTargetRequirement(
                    kind: .slot(slotTargetKind(for: effect) ?? .placeEgg),
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel
                )
            case .selectDiscardCard:
                return EffectTargetRequirement(
                    kind: .discardCard,
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel
                )
            case .selectScatterSchoolSource:
                return EffectTargetRequirement(
                    kind: .slot(.scatterSchoolSource),
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel,
                    filters: [.hasSchool]
                )
            case .selectScatterSchoolYoungTarget:
                return EffectTargetRequirement(
                    kind: .slot(.scatterSchoolYoungTarget),
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel,
                    filters: [.canScatterSchoolYoung]
                )
            case .selectConsumerFish:
                return EffectTargetRequirement(
                    kind: .slot(.consumeFishConsumer),
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel,
                    filters: [.canConsumeHandFish]
                )
            case .selectConsumedHandFish:
                return EffectTargetRequirement(
                    kind: .handCard,
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel
                )
            case .selectFreePlayHandFish:
                return EffectTargetRequirement(
                    kind: .handCard,
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel,
                    filters: [.matchesFishFilter(effectKey(effect))]
                )
            case .selectFreePlayTargetSlot:
                return EffectTargetRequirement(
                    kind: .slot(.freePlayTarget),
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel,
                    filters: [.canPlaySelectedFish]
                )
            case .selectPlayFromHandFish:
                return EffectTargetRequirement(
                    kind: .handCard,
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel,
                    filters: [.matchesFishFilter(effectKey(effect))]
                )
            case .selectPlayFromHandTargetSlot:
                return EffectTargetRequirement(
                    kind: .slot(.playFishFromHandTarget),
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel,
                    filters: [.canPlaySelectedFish]
                )
            case .selectCoralPaymentSource,
                 .selectCoralPaymentCard,
                 .selectMoveSource,
                 .selectMoveTarget,
                 .selectPlayFromHandPayment:
                return nil
            }
        }

        guard let slotKind = slotTargetKind(for: effect) else {
            if case .recoverFromDiscardOrDraw = effect {
                return EffectTargetRequirement(
                    kind: .discardCard,
                    ownerPlayerId: ownerPlayerId,
                    effectNodeId: effectNodeId,
                    debugLabel: debugLabel
                )
            }
            return nil
        }
        return EffectTargetRequirement(
            kind: .slot(slotKind),
            ownerPlayerId: ownerPlayerId,
            effectNodeId: effectNodeId,
            debugLabel: debugLabel
        )
    }

    nonisolated private static func slotTargetKind(for effect: AbilityEffectUnit) -> EffectSlotTargetKind? {
        switch effect {
        case .placeEgg:
            return .placeEgg
        case .placeYoung:
            return .placeYoung
        case .hatchEgg:
            return .hatchEgg
        default:
            return nil
        }
    }

    nonisolated private static func paymentRequirement(
        for effect: AbilityEffectUnit,
        stagedSelection: EffectStagedSelectionRequirement?,
        debugLabel: String
    ) -> EffectPaymentRequirement? {
        switch effect {
        case .gainCoral:
            guard let stage = stagedSelection?.stage else {
                return nil
            }
            switch stage {
            case .selectCoralPaymentSource,
                 .selectCoralPaymentCard:
                break
            default:
                return nil
            }
            return EffectPaymentRequirement(
                paymentKind: .coral,
                allowedSources: [.egg, .young, .handCard],
                requiredResources: [
                    EffectRequiredPaymentResource(kind: .egg, count: 1, source: .egg),
                    EffectRequiredPaymentResource(kind: .young, count: 1, source: .young),
                    EffectRequiredPaymentResource(kind: nil, count: 1, source: .handCard)
                ],
                isOptional: true,
                costWaived: false,
                debugLabel: debugLabel
            )
        case .playFishForFree:
            return EffectPaymentRequirement(
                paymentKind: .freePlay,
                allowedSources: [.waivedCost],
                requiredResources: [],
                isOptional: true,
                costWaived: true,
                debugLabel: debugLabel
            )
        case .playFishFromHand:
            return EffectPaymentRequirement(
                paymentKind: .playFish,
                allowedSources: [.egg, .young, .handCard],
                requiredResources: [],
                isOptional: false,
                costWaived: false,
                debugLabel: debugLabel
            )
        default:
            return nil
        }
    }

    nonisolated private static func resourceRequirement(
        for effect: AbilityEffectUnit,
        ownerPlayerId: PlayerID
    ) -> EffectResourceRequirement? {
        switch effect {
        case .placeEgg:
            return EffectResourceRequirement(resourceKind: .egg, ownerPlayerId: ownerPlayerId, minCount: 1, maxCount: 1, source: .oceanSlot)
        case .placeYoung:
            return EffectResourceRequirement(resourceKind: .young, ownerPlayerId: ownerPlayerId, minCount: 1, maxCount: 1, source: .oceanSlot)
        case .hatchEgg:
            return EffectResourceRequirement(resourceKind: .egg, ownerPlayerId: ownerPlayerId, minCount: 1, maxCount: 1, source: .oceanSlot)
        case .moveYoungOrSchool:
            return EffectResourceRequirement(resourceKind: .young, ownerPlayerId: ownerPlayerId, minCount: 1, maxCount: 1, source: .oceanSlot)
        default:
            return nil
        }
    }

    nonisolated private static func rewardTokenRequirement(
        for effect: AbilityEffectUnit,
        stagedSelection: EffectStagedSelectionRequirement?,
        debugLabel: String
    ) -> EffectRewardTokenRequirement? {
        let tokenKind: EffectRewardTokenKind
        switch effect {
        case .drawFish:
            tokenKind = .drawFish
        case .recoverFromDiscardOrDraw:
            tokenKind = .recoverFromDiscardOrDraw
        case .placeEgg,
             .placeEggOnMatchingFish:
            tokenKind = .placeEgg
        case .placeYoung:
            tokenKind = .placeYoung
        case .hatchEgg:
            tokenKind = .hatchEgg
        case .moveYoungOrSchool:
            tokenKind = .moveYoungOrSchool
        case .gainCoral:
            tokenKind = .gainCoral
        case .scatterSchool:
            tokenKind = .scatterSchool
        case .consumeFishFromHand:
            tokenKind = .consumeFishFromHand
        case .playFishForFree:
            tokenKind = .playFishForFree
        case .playFishFromHand:
            tokenKind = .playFishFromHand
        case .gameEndScore:
            return nil
        case .unsupported:
            tokenKind = .unsupported
        }
        return EffectRewardTokenRequirement(
            tokenKind: tokenKind,
            count: effectCount(effect),
            source: stagedSelection.map { _ in EffectRewardTokenSource.stagedSelection } ?? .ability,
            isSelectable: true,
            debugLabel: debugLabel
        )
    }

    nonisolated private static func stagedSelectionRequirement(
        for choice: PendingChoice,
        effect: AbilityEffectUnit
    ) -> EffectStagedSelectionRequirement? {
        guard let expectedInput = choice.expectedInput else {
            return nil
        }
        let stage: EffectSelectionStage?
        let nextStageHint: EffectSelectionStage?
        let canResolveWithCurrentPayload: Bool
        switch expectedInput {
        case .none,
             .abilityEffectSelection,
             .count:
            return nil
        case .targetSlot,
             .matchingEggTarget:
            stage = .selectTargetSlot
            nextStageHint = nil
            canResolveWithCurrentPayload = false
        case .cardSelection:
            stage = .selectDiscardCard
            nextStageHint = nil
            canResolveWithCurrentPayload = false
        case .sourceAndTargetSlots:
            stage = .selectMoveSource
            nextStageHint = .selectMoveTarget
            canResolveWithCurrentPayload = false
        case .coralPayment:
            stage = .selectCoralPaymentSource
            nextStageHint = .selectCoralPaymentCard
            canResolveWithCurrentPayload = false
        case .coralPlacement:
            stage = .selectTargetSlot
            nextStageHint = nil
            canResolveWithCurrentPayload = false
        case .scatterSchoolSource:
            stage = .selectScatterSchoolSource
            nextStageHint = .selectScatterSchoolYoungTarget
            canResolveWithCurrentPayload = false
        case .scatterSchoolYoungTarget:
            stage = .selectScatterSchoolYoungTarget
            nextStageHint = nil
            canResolveWithCurrentPayload = false
        case .consumeFishConsumer:
            stage = .selectConsumerFish
            nextStageHint = .selectConsumedHandFish
            canResolveWithCurrentPayload = false
        case .consumeFishHandCard:
            stage = .selectConsumedHandFish
            nextStageHint = nil
            canResolveWithCurrentPayload = false
        case .freePlayHandCard:
            stage = .selectFreePlayHandFish
            nextStageHint = .selectFreePlayTargetSlot
            canResolveWithCurrentPayload = false
        case .freePlayTargetSlot:
            stage = .selectFreePlayTargetSlot
            nextStageHint = nil
            canResolveWithCurrentPayload = false
        case .playFishFromHandCard:
            stage = .selectPlayFromHandFish
            nextStageHint = .selectPlayFromHandTargetSlot
            canResolveWithCurrentPayload = false
        case .playFishFromHandTargetSlot:
            stage = .selectPlayFromHandTargetSlot
            nextStageHint = .selectPlayFromHandPayment
            canResolveWithCurrentPayload = false
        case .playFishFromHandPayment:
            stage = .selectPlayFromHandPayment
            nextStageHint = nil
            canResolveWithCurrentPayload = true
        }
        guard let stage else {
            return nil
        }
        return EffectStagedSelectionRequirement(
            stage: stage,
            nextStageHint: nextStageHint,
            canResolveWithCurrentPayload: canResolveWithCurrentPayload,
            debugLabel: "\(effectKey(effect)):\(stage)"
        )
    }

    nonisolated private static func completedNodes(
        for choice: PendingChoice,
        sourcePlayerId: PlayerID
    ) -> [CompletedEffectNode] {
        let compoundCompleted = choice.compoundAbilityProgress?.completedEffects.enumerated().map { index, effect in
            CompletedEffectNode(
                effectNodeId: "completed-\(index)-\(effectKey(effect))",
                effect: effect,
                sourcePlayerId: sourcePlayerId,
                targetPlayerId: choice.playerId,
                decisionIndex: index,
                debugLabel: effectKey(effect)
            )
        } ?? []
        let allPlayersCompleted = choice.allPlayersProgress?.resolvedPlayerIds.enumerated().map { index, playerId in
            CompletedEffectNode(
                effectNodeId: "allPlayers-completed-\(index)",
                effect: currentEffect(for: choice) ?? .unsupported,
                sourcePlayerId: sourcePlayerId,
                targetPlayerId: playerId,
                decisionIndex: index,
                debugLabel: "allPlayers resolved \(playerId)"
            )
        } ?? []
        return compoundCompleted + allPlayersCompleted
    }

    nonisolated private static func skippedNodes(
        for choice: PendingChoice,
        sourcePlayerId: PlayerID
    ) -> [SkippedEffectNode] {
        choice.allPlayersProgress?.skippedPlayerIds.enumerated().map { index, playerId in
            SkippedEffectNode(
                effectNodeId: "allPlayers-skipped-\(index)",
                effect: currentEffect(for: choice),
                sourcePlayerId: sourcePlayerId,
                targetPlayerId: playerId,
                decisionIndex: index,
                debugLabel: "allPlayers skipped \(playerId)"
            )
        } ?? []
    }

    nonisolated private static func allPlayersTargetIds(for choice: PendingChoice) -> [PlayerID] {
        guard let progress = choice.allPlayersProgress else {
            return []
        }
        return progress.resolvedPlayerIds
            + progress.skippedPlayerIds
            + [progress.currentTargetPlayerId]
            + progress.remainingPlayerIds
    }

    nonisolated private static func currentEffect(for choice: PendingChoice) -> AbilityEffectUnit? {
        if let effect = choice.selectedAbilityEffect {
            return effect
        }
        if let effect = choice.abilityDefinition?.effects.first, choice.kind != .compoundAbility {
            return effect
        }
        return effect(for: choice.kind)
    }

    nonisolated private static func sourceCardId(for choice: PendingChoice) -> CardID {
        if let progress = choice.allPlayersProgress {
            return progress.sourceCardId
        }
        if let progress = choice.conditionalBonusProgress {
            return progress.sourceCardId
        }
        if let progress = choice.compoundAbilityProgress {
            return progress.sourceCardId
        }
        if case let .fishAbility(cardId) = choice.source {
            return cardId
        }
        if case let .endGameAbility(sourceId) = choice.source {
            return sourceId
        }
        return choice.choiceId
    }

    nonisolated private static func sourcePlayerId(for choice: PendingChoice) -> PlayerID {
        choice.allPlayersProgress?.sourcePlayerId
            ?? choice.conditionalBonusProgress?.playerId
            ?? choice.compoundAbilityProgress?.playerId
            ?? choice.playerId
    }

    nonisolated private static func sourceAddress(for choice: PendingChoice) -> OceanSlotAddress? {
        choice.allPlayersProgress?.sourceAddress
            ?? choice.conditionalBonusProgress?.sourceAddress
            ?? choice.compoundAbilityProgress?.sourceAddress
    }

    nonisolated private static func decisionIndex(for choice: PendingChoice) -> Int {
        (choice.compoundAbilityProgress?.completedEffects.count ?? 0)
            + (choice.allPlayersProgress?.resolvedPlayerIds.count ?? 0)
            + (choice.allPlayersProgress?.skippedPlayerIds.count ?? 0)
    }

    nonisolated private static func executionId(
        abilityId: AbilityID,
        sourceCardId: CardID,
        sourcePlayerId: PlayerID,
        parentExecutionId: AbilityExecutionId?
    ) -> AbilityExecutionId {
        [
            parentExecutionId,
            "ability",
            sourcePlayerId,
            sourceCardId,
            abilityId
        ]
            .compactMap { $0 }
            .joined(separator: "::")
    }

    nonisolated private static func sourceConditions(for effect: AbilityEffectUnit) -> [EffectCondition] {
        switch effect {
        case let .playFishForFree(_, placement, sourceCondition, _):
            var conditions: [EffectCondition] = []
            if case .sameDiveSiteAsSource = placement {
                conditions.append(.sourceFishLocated)
                conditions.append(.sourceFishVisible)
            }
            if case .sourceDiveSiteHasNoCoral = sourceCondition {
                conditions.append(.sourceDiveSiteHasNoCoral)
            }
            return conditions
        default:
            return []
        }
    }

    nonisolated private static func normalizedSingleEffect(_ effect: AbilityEffectUnit) -> AbilityEffectUnit {
        effectWithCount(effect, count: 1)
    }

    nonisolated private static func effectCount(_ effect: AbilityEffectUnit) -> Int {
        switch effect {
        case let .drawFish(count),
             let .placeEgg(count),
             let .placeYoung(count),
             let .hatchEgg(count),
             let .moveYoungOrSchool(count),
             let .recoverFromDiscardOrDraw(count),
             let .gainCoral(_, count),
             let .scatterSchool(count),
             let .consumeFishFromHand(count),
             let .playFishForFree(_, _, _, count):
            return count
        case .gameEndScore,
             .placeEggOnMatchingFish,
             .playFishFromHand:
            return 1
        case .unsupported:
            return 0
        }
    }

    nonisolated private static func effectWithCount(_ effect: AbilityEffectUnit, count: Int) -> AbilityEffectUnit {
        switch effect {
        case .drawFish:
            return .drawFish(count: count)
        case .placeEgg:
            return .placeEgg(count: count)
        case .placeYoung:
            return .placeYoung(count: count)
        case .hatchEgg:
            return .hatchEgg(count: count)
        case .moveYoungOrSchool:
            return .moveYoungOrSchool(count: count)
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw(count: count)
        case let .gameEndScore(condition, points):
            return .gameEndScore(condition: condition, points: points)
        case let .placeEggOnMatchingFish(filter, mode):
            return .placeEggOnMatchingFish(filter: filter, mode: mode)
        case let .playFishFromHand(filter, placement, costMode):
            return .playFishFromHand(filter: filter, placement: placement, costMode: costMode)
        case let .gainCoral(selector, _):
            return .gainCoral(selector: selector, count: count)
        case .scatterSchool:
            return .scatterSchool(count: count)
        case .consumeFishFromHand:
            return .consumeFishFromHand(count: count)
        case let .playFishForFree(filter, placement, sourceCondition, _):
            return .playFishForFree(
                filter: filter,
                placement: placement,
                sourceCondition: sourceCondition,
                count: count
            )
        case .unsupported:
            return .unsupported
        }
    }

    nonisolated private static func effect(for kind: PendingChoiceKind) -> AbilityEffectUnit? {
        switch kind {
        case .drawFish:
            return .drawFish(count: 1)
        case .placeEgg:
            return .placeEgg(count: 1)
        case .hatchEgg:
            return .hatchEgg(count: 1)
        case .placeYoung:
            return .placeYoung(count: 1)
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw(count: 1)
        case .moveYoungOrSchool:
            return .moveYoungOrSchool(count: 1)
        case .gainCoral:
            return .gainCoral(selector: .any, count: 1)
        case .placeEggOnMatchingFish:
            return .placeEggOnMatchingFish(filter: .topRow, mode: .chooseOneEligibleFish)
        case .scatterSchool:
            return .scatterSchool(count: 1)
        case .consumeFishFromHand:
            return .consumeFishFromHand(count: 1)
        case .playFishForFree:
            return .playFishForFree(filter: .any, placement: .any, sourceCondition: .none, count: 1)
        case .playFishFromHand:
            return .playFishFromHand(filter: .any, placement: .any, costMode: .payCost)
        case .compoundAbility,
             .bottomBonus,
             .placeholder,
             .unsupported:
            return nil
        }
    }

    nonisolated private static func pendingChoiceKind(for effect: AbilityEffectUnit) -> PendingChoiceKind {
        switch effect {
        case .drawFish:
            return .drawFish
        case .placeEgg:
            return .placeEgg
        case .hatchEgg:
            return .hatchEgg
        case .placeYoung:
            return .placeYoung
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw
        case .moveYoungOrSchool:
            return .moveYoungOrSchool
        case .gainCoral:
            return .gainCoral
        case .placeEggOnMatchingFish:
            return .placeEggOnMatchingFish
        case .scatterSchool:
            return .scatterSchool
        case .consumeFishFromHand:
            return .consumeFishFromHand
        case .playFishForFree:
            return .playFishForFree
        case .playFishFromHand:
            return .playFishFromHand
        case .gameEndScore,
             .unsupported:
            return .unsupported
        }
    }

    nonisolated private static func effectKey(_ effect: AbilityEffectUnit) -> String {
        switch effect {
        case .drawFish:
            return "drawFish"
        case .placeEgg:
            return "placeEgg"
        case .hatchEgg:
            return "hatchEgg"
        case .placeYoung:
            return "placeYoung"
        case .moveYoungOrSchool:
            return "moveYoungOrSchool"
        case .recoverFromDiscardOrDraw:
            return "recoverFromDiscardOrDraw"
        case let .gameEndScore(condition, points):
            return "gameEndScore-\(condition)-\(points)"
        case let .placeEggOnMatchingFish(filter, mode):
            return "placeEggOnMatchingFish-\(filter)-\(mode)"
        case let .playFishFromHand(filter, placement, costMode):
            return "playFishFromHand-\(filter)-\(placement)-\(costMode)"
        case let .gainCoral(selector, _):
            return "gainCoral-\(selector.rawValue)"
        case .scatterSchool:
            return "scatterSchool"
        case .consumeFishFromHand:
            return "consumeFishFromHand"
        case let .playFishForFree(filter, placement, sourceCondition, _):
            return "playFishForFree-\(filter)-\(placement)-\(sourceCondition)"
        case .unsupported:
            return "unsupported"
        }
    }
}

extension PendingChoice {
    nonisolated var v2PendingEffectSet: PendingEffectSet {
        pendingEffectSet ?? AbilityEngineV2Adapter.pendingEffectSet(for: self)
    }
}

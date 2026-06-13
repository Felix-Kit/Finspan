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
        sourceAddress: OceanSlotAddress?
    ) -> EffectGraph {
        let baseNodes = nodes(
            for: conditionalBonus.baseEffects,
            prefix: "base",
            scope: .sourcePlayer,
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
                metadata: EffectNodeMetadata(
                    sourceAddress: sourceAddress,
                    debugLabel: effectKey(effect),
                    debugDescription: "\(prefix) effect \(index): \(effectKey(effect))",
                    legacyChoiceKind: pendingChoiceKind(for: effect),
                    decisionIndex: decisionOffset + index
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

        return EffectNode(
            id: id,
            effect: effect,
            scope: scope,
            conditions: sourceConditions(for: effect),
            dependencies: [],
            optionality: choice.isOptional ? .optional : .required,
            metadata: EffectNodeMetadata(
                sourceAddress: sourceAddress(for: choice),
                debugLabel: effectKey(effect),
                debugDescription: "Legacy pending choice \(choice.choiceId): \(effectKey(effect))",
                legacyChoiceKind: choice.kind,
                decisionIndex: decisionIndex
            )
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
    var v2PendingEffectSet: PendingEffectSet {
        pendingEffectSet ?? AbilityEngineV2Adapter.pendingEffectSet(for: self)
    }
}

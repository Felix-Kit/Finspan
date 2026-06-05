import Foundation

protocol AbilityDefinitionProvider: Sendable {
    nonisolated func abilityDefinition(for abilityId: AbilityID) -> AbilityDefinition?
}

struct AbilityRegistry: AbilityDefinitionProvider, Sendable {
    private let definitionsById: [AbilityID: AbilityDefinition]

    nonisolated init(definitions: [AbilityDefinition] = []) {
        definitionsById = Dictionary(uniqueKeysWithValues: definitions.map { ($0.abilityId, $0) })
    }

    nonisolated func abilityDefinition(for abilityId: AbilityID) -> AbilityDefinition? {
        definitionsById[abilityId]
    }
}

extension AbilityRegistry {
    nonisolated static let sample = AbilityRegistry(definitions: SampleAbilityDefinitions.all)
}

enum SampleAbilityIDs {
    nonisolated static let fishAIfActivatedDrawFishOne: AbilityID = "sample.ifActivated.drawFishOne"
    nonisolated static let fishBIfActivatedPlaceTwoEggsHatchOne: AbilityID = "sample.ifActivated.placeTwoEggsHatchOne"
    nonisolated static let fishCWhenPlayedDrawFishOne: AbilityID = "sample.whenPlayed.drawFishOne"
}

enum SampleAbilityDefinitions {
    nonisolated static let all: [AbilityDefinition] = [
        AbilityDefinition(
            abilityId: SampleAbilityIDs.fishAIfActivatedDrawFishOne,
            trigger: .ifActivated,
            effects: [.drawFish(count: 1)],
            displayText: "发动时：抽 1 张鱼牌"
        ),
        AbilityDefinition(
            abilityId: SampleAbilityIDs.fishBIfActivatedPlaceTwoEggsHatchOne,
            trigger: .ifActivated,
            effects: [
                .placeEgg(count: 2),
                .hatchEgg(count: 1)
            ],
            canResolveInAnyOrder: true,
            isOptional: true,
            displayText: "发动时：放置 2 个鱼卵，孵化 1 个鱼卵，可任选顺序"
        ),
        AbilityDefinition(
            abilityId: SampleAbilityIDs.fishCWhenPlayedDrawFishOne,
            trigger: .whenPlayed,
            effects: [.drawFish(count: 1)],
            displayText: "打出时：抽 1 张鱼牌"
        )
    ]
}

struct AbilityResolver: Sendable {
    private let provider: any AbilityDefinitionProvider
    private let fallbackAbilityIdsByCardId: [CardID: [AbilityID]]

    nonisolated init(
        provider: any AbilityDefinitionProvider = AbilityRegistry.sample,
        fallbackAbilityIdsByCardId: [CardID: [AbilityID]] = [:]
    ) {
        self.provider = provider
        self.fallbackAbilityIdsByCardId = fallbackAbilityIdsByCardId
    }

    nonisolated func abilityDefinitions(for card: Card) -> [AbilityDefinition] {
        let ids = card.abilityIds.isEmpty
            ? fallbackAbilityIdsByCardId[card.id, default: []]
            : card.abilityIds

        guard !ids.isEmpty else {
            return card.abilities
        }

        return ids.map { abilityId in
            provider.abilityDefinition(for: abilityId)
                ?? unsupportedAbilityDefinition(abilityId: abilityId)
        }
    }

    nonisolated func abilityDefinitions(
        for card: Card,
        trigger: AbilityTrigger
    ) -> [AbilityDefinition] {
        abilityDefinitions(for: card).filter { $0.trigger == trigger }
    }

    nonisolated private func unsupportedAbilityDefinition(abilityId: AbilityID) -> AbilityDefinition {
        AbilityDefinition(
            abilityId: abilityId,
            trigger: .ifActivated,
            effects: [.unsupported],
            isOptional: true
        )
    }
}

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
    nonisolated static let builtIn = AbilityRegistry(
        definitions: SampleAbilityDefinitions.all
            + BaseGameAbilityDefinitions.all
            + SharksAndReefsAbilityDefinitions.all
    )
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

enum BaseGameAbilityIDs {
    nonisolated static let blueLanternfishWhenPlayedDrawFour: AbilityID = "unsupported.base.whenPlayed.card_127"
}

enum BaseGameAbilityDefinitions {
    nonisolated static let all: [AbilityDefinition] = [
        AbilityDefinition(
            abilityId: BaseGameAbilityIDs.blueLanternfishWhenPlayedDrawFour,
            trigger: .whenPlayed,
            effects: [.drawFish(count: 4)],
            displayText: "打出时：抽 4 张鱼牌"
        )
    ]
}

enum SharksAndReefsAbilityIDs {
    nonisolated static let blueCoralIfActivated: AbilityID = "unsupported.sr.ifActivated.card_171"
    nonisolated static let purpleCoralIfActivated: AbilityID = "unsupported.sr.ifActivated.card_154"
    nonisolated static let anyCoralIfActivated: AbilityID = "unsupported.sr.ifActivated.card_210"
    nonisolated static let bluePurpleCoralWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_194"
    nonisolated static let greenCoralScatterSchoolWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_142"
    nonisolated static let consumeFishFromHandTwiceWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_136"
    nonisolated static let consumeFishFromHandIfActivated: AbilityID = "unsupported.sr.ifActivated.card_152"
}

enum SharksAndReefsAbilityDefinitions {
    nonisolated static let all: [AbilityDefinition] = [
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.blueCoralIfActivated,
            trigger: .ifActivated,
            effects: [.gainCoral(selector: .blue, count: 1)],
            displayText: "发动时：获得 1 个蓝色珊瑚"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.purpleCoralIfActivated,
            trigger: .ifActivated,
            effects: [.gainCoral(selector: .purple, count: 1)],
            displayText: "发动时：获得 1 个紫色珊瑚"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.anyCoralIfActivated,
            trigger: .ifActivated,
            effects: [.gainCoral(selector: .any, count: 1)],
            displayText: "发动时：选择一个潜水点获得 1 个珊瑚"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.bluePurpleCoralWhenPlayed,
            trigger: .whenPlayed,
            effects: [
                .gainCoral(selector: .blue, count: 1),
                .gainCoral(selector: .purple, count: 1)
            ],
            canResolveInAnyOrder: true,
            isOptional: true,
            displayText: "打出时：获得 1 个蓝色珊瑚和 1 个紫色珊瑚"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.greenCoralScatterSchoolWhenPlayed,
            trigger: .whenPlayed,
            effects: [
                .gainCoral(selector: .green, count: 1),
                .scatterSchool(count: 1)
            ],
            canResolveInAnyOrder: true,
            isOptional: true,
            displayText: "打出时：获得 1 个绿色珊瑚，打散鱼群"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.consumeFishFromHandTwiceWhenPlayed,
            trigger: .whenPlayed,
            effects: [
                .consumeFishFromHand(count: 1),
                .consumeFishFromHand(count: 1)
            ],
            canResolveInAnyOrder: true,
            isOptional: true,
            displayText: "打出时：海洋中的鱼吞噬 2 张更短手牌鱼"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.consumeFishFromHandIfActivated,
            trigger: .ifActivated,
            effects: [.consumeFishFromHand(count: 1)],
            isOptional: true,
            displayText: "发动时：海洋中的鱼吞噬 1 张更短手牌鱼"
        )
    ]
}

struct AbilityResolver: Sendable {
    private let provider: any AbilityDefinitionProvider
    private let fallbackAbilityIdsByCardId: [CardID: [AbilityID]]

    nonisolated init(
        provider: any AbilityDefinitionProvider = AbilityRegistry.builtIn,
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

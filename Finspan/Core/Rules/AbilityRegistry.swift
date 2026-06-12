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
    nonisolated static let abyssalAnglerfishGameEnd: AbilityID = "unsupported.base.gameEnd.card_001"
    nonisolated static let angelsharkGameEnd: AbilityID = "unsupported.base.gameEnd.card_004"
    nonisolated static let atlanticBonitoGameEnd: AbilityID = "unsupported.base.gameEnd.card_008"
    nonisolated static let atlanticSalmonGameEnd: AbilityID = "unsupported.base.gameEnd.card_011"
    nonisolated static let binocularFishGameEnd: AbilityID = "unsupported.base.gameEnd.card_019"
    nonisolated static let blobSculpinGameEnd: AbilityID = "unsupported.base.gameEnd.card_023"
    nonisolated static let chineseTrumpetfishGameEnd: AbilityID = "unsupported.base.gameEnd.card_028"
    nonisolated static let clownAnemonefishGameEnd: AbilityID = "unsupported.base.gameEnd.card_030"
    nonisolated static let commonFangtoothGameEnd: AbilityID = "unsupported.base.gameEnd.card_031"
    nonisolated static let cookiecutterSharkGameEnd: AbilityID = "unsupported.base.gameEnd.card_032"
    nonisolated static let crocodilefishGameEnd: AbilityID = "unsupported.base.gameEnd.card_035"
    nonisolated static let europeanAnchovyGameEnd: AbilityID = "unsupported.base.gameEnd.card_041"
    nonisolated static let facelessCuskGameEnd: AbilityID = "unsupported.base.gameEnd.card_044"
    nonisolated static let giantTrevallyGameEnd: AbilityID = "unsupported.base.gameEnd.card_054"
    nonisolated static let largetoothFlounderGameEnd: AbilityID = "unsupported.base.gameEnd.card_069"
    nonisolated static let leafySeadragonGameEnd: AbilityID = "unsupported.base.gameEnd.card_070"
    nonisolated static let marianaSnailfishGameEnd: AbilityID = "unsupported.base.gameEnd.card_077"
    nonisolated static let oceanSunfishGameEnd: AbilityID = "unsupported.base.gameEnd.card_081"
    nonisolated static let paleChimaeraGameEnd: AbilityID = "unsupported.base.gameEnd.card_085"
    nonisolated static let pudgyCuskEelGameEnd: AbilityID = "unsupported.base.gameEnd.card_093"
    nonisolated static let sloansViperfishGameEnd: AbilityID = "unsupported.base.gameEnd.card_105"
    nonisolated static let stripedMarlinGameEnd: AbilityID = "unsupported.base.gameEnd.card_115"
    nonisolated static let yellowtailSnapperGameEnd: AbilityID = "unsupported.base.gameEnd.card_125"
}

enum BaseGameAbilityDefinitions {
    nonisolated static let all: [AbilityDefinition] = [
        AbilityDefinition(
            abilityId: BaseGameAbilityIDs.blueLanternfishWhenPlayedDrawFour,
            trigger: .whenPlayed,
            effects: [.drawFish(count: 4)],
            displayText: "打出时：抽 4 张鱼牌"
        ),
        gameEndScore(
            BaseGameAbilityIDs.abyssalAnglerfishGameEnd,
            condition: .noTokensOnThisFish,
            points: 3,
            displayText: "游戏结束计分：若此鱼上没有任何标记，得 3 分"
        ),
        gameEndScore(
            BaseGameAbilityIDs.angelsharkGameEnd,
            condition: .consumedFishUnderThisFishAtLeast(3),
            points: 10,
            displayText: "游戏结束计分：若此鱼下方有至少 3 条被吞食鱼，得 10 分"
        ),
        gameEndScore(
            BaseGameAbilityIDs.atlanticBonitoGameEnd,
            condition: .consumedFishUnderThisFishAtLeast(2),
            points: 6,
            displayText: "游戏结束计分：若此鱼下方有至少 2 条被吞食鱼，得 6 分"
        ),
        playFishFromHand(
            BaseGameAbilityIDs.atlanticSalmonGameEnd,
            placement: .topRow,
            displayText: "游戏结束：支付费用，从手牌打出 1 张鱼到河口"
        ),
        placeEgg(
            BaseGameAbilityIDs.binocularFishGameEnd,
            filter: .lengthBucket(.small),
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在每条小型鱼上放置 1 个鱼卵"
        ),
        playFishFromHand(
            BaseGameAbilityIDs.blobSculpinGameEnd,
            placement: .diveSite(.green),
            displayText: "游戏结束：支付费用，从手牌打出 1 张鱼到绿色潜水点"
        ),
        placeEgg(
            BaseGameAbilityIDs.chineseTrumpetfishGameEnd,
            filter: .lengthBucket(.medium),
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在每条中型鱼上放置 1 个鱼卵"
        ),
        gameEndScore(
            BaseGameAbilityIDs.clownAnemonefishGameEnd,
            condition: .youngOnThisFishExactly(2),
            points: 6,
            displayText: "游戏结束计分：若此鱼上正好有 2 个幼鱼，得 6 分"
        ),
        gameEndScore(
            BaseGameAbilityIDs.commonFangtoothGameEnd,
            condition: .consumedFishUnderThisFishAtLeast(1),
            points: 3,
            displayText: "游戏结束计分：若此鱼下方有至少 1 条被吞食鱼，得 3 分"
        ),
        gameEndScore(
            BaseGameAbilityIDs.cookiecutterSharkGameEnd,
            condition: .bottomRow,
            points: 5,
            displayText: "游戏结束计分：若此鱼在底行，得 5 分"
        ),
        playFishFromHand(
            BaseGameAbilityIDs.crocodilefishGameEnd,
            placement: .diveSite(.blue),
            displayText: "游戏结束：支付费用，从手牌打出 1 张鱼到蓝色潜水点"
        ),
        placeEgg(
            BaseGameAbilityIDs.europeanAnchovyGameEnd,
            filter: .topRow,
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在河口中每条鱼上放置 1 个鱼卵"
        ),
        playFishFromHand(
            BaseGameAbilityIDs.facelessCuskGameEnd,
            placement: .bottomRow,
            displayText: "游戏结束：支付费用，从手牌打出 1 张鱼到底行"
        ),
        playFishFromHand(
            BaseGameAbilityIDs.giantTrevallyGameEnd,
            placement: .diveSite(.purple),
            displayText: "游戏结束：支付费用，从手牌打出 1 张鱼到紫色潜水点"
        ),
        placeEgg(
            BaseGameAbilityIDs.largetoothFlounderGameEnd,
            filter: .diveSite(.green),
            mode: .chooseOneEligibleFish,
            displayText: "游戏结束：选择绿色潜水点中 1 条鱼放置 1 个鱼卵"
        ),
        gameEndScore(
            BaseGameAbilityIDs.leafySeadragonGameEnd,
            condition: .schoolOnThisFish,
            points: 3,
            displayText: "游戏结束计分：若此鱼上有鱼群，得 3 分"
        ),
        placeEgg(
            BaseGameAbilityIDs.marianaSnailfishGameEnd,
            filter: .bottomRow,
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在底行每条鱼上放置 1 个鱼卵"
        ),
        placeEgg(
            BaseGameAbilityIDs.oceanSunfishGameEnd,
            filter: .lengthBucket(.large),
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在每条大型鱼上放置 1 个鱼卵"
        ),
        gameEndScore(
            BaseGameAbilityIDs.paleChimaeraGameEnd,
            condition: .eggYoungAndSchoolOnThisFish,
            points: 10,
            displayText: "游戏结束计分：若此鱼上有鱼卵、幼鱼和鱼群，得 10 分"
        ),
        placeEgg(
            BaseGameAbilityIDs.pudgyCuskEelGameEnd,
            filter: .diveSite(.blue),
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在蓝色潜水点每条鱼上放置 1 个鱼卵"
        ),
        placeEgg(
            BaseGameAbilityIDs.sloansViperfishGameEnd,
            filter: .tag("predator"),
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在每条捕食者鱼上放置 1 个鱼卵"
        ),
        playFishFromHand(
            BaseGameAbilityIDs.stripedMarlinGameEnd,
            placement: .sunlight,
            displayText: "游戏结束：支付费用，从手牌打出 1 张鱼到阳光层"
        ),
        placeEgg(
            BaseGameAbilityIDs.yellowtailSnapperGameEnd,
            filter: .diveSite(.purple),
            mode: .onEachEligibleFish,
            displayText: "游戏结束：在紫色潜水点每条鱼上放置 1 个鱼卵"
        )
    ]

    nonisolated private static func gameEndScore(
        _ abilityId: AbilityID,
        condition: GameEndScoreCondition,
        points: Int,
        displayText: String
    ) -> AbilityDefinition {
        AbilityDefinition(
            abilityId: abilityId,
            trigger: .gameEnd,
            effects: [.gameEndScore(condition: condition, points: points)],
            isOptional: false,
            displayText: displayText
        )
    }

    nonisolated private static func placeEgg(
        _ abilityId: AbilityID,
        filter: EggPlacementFilter,
        mode: EggPlacementMode,
        displayText: String
    ) -> AbilityDefinition {
        AbilityDefinition(
            abilityId: abilityId,
            trigger: .gameEnd,
            effects: [.placeEggOnMatchingFish(filter: filter, mode: mode)],
            isOptional: true,
            displayText: displayText
        )
    }

    nonisolated private static func playFishFromHand(
        _ abilityId: AbilityID,
        placement: FishPlacementConstraint,
        displayText: String
    ) -> AbilityDefinition {
        AbilityDefinition(
            abilityId: abilityId,
            trigger: .gameEnd,
            effects: [.playFishFromHand(filter: .any, placement: placement, costMode: .payCost)],
            isOptional: true,
            displayText: displayText
        )
    }
}

enum SharksAndReefsAbilityIDs {
    nonisolated static let blueCoralIfActivated: AbilityID = "unsupported.sr.ifActivated.card_171"
    nonisolated static let purpleCoralIfActivated: AbilityID = "unsupported.sr.ifActivated.card_154"
    nonisolated static let anyCoralIfActivated: AbilityID = "unsupported.sr.ifActivated.card_210"
    nonisolated static let bluePurpleCoralWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_194"
    nonisolated static let greenCoralScatterSchoolWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_142"
    nonisolated static let consumeFishFromHandTwiceWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_136"
    nonisolated static let consumeFishFromHandIfActivated: AbilityID = "unsupported.sr.ifActivated.card_152"
    nonisolated static let freePlayBioluminescentWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_150"
    nonisolated static let freePlaySmallWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_170"
    nonisolated static let freePlayMediumWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_192"
    nonisolated static let freePlayCamouflageWhenPlayed: AbilityID = "unsupported.sr.whenPlayed.card_200"
    nonisolated static let scatterSchoolTwiceGameEnd: AbilityID = "unsupported.sr.gameEnd.card_146"
    nonisolated static let blueCoralThreeGameEnd: AbilityID = "unsupported.sr.gameEnd.card_147"
    nonisolated static let freePlayMediumDuskySharkGameEnd: AbilityID = "unsupported.sr.gameEnd.card_149"
    nonisolated static let purpleCoralThreeGameEnd: AbilityID = "unsupported.sr.gameEnd.card_153"
    nonisolated static let freePlayMediumFrilledSharkGameEnd: AbilityID = "unsupported.sr.gameEnd.card_156"
    nonisolated static let anyCoralTwiceGameEnd: AbilityID = "unsupported.sr.gameEnd.card_174"
    nonisolated static let bluePurpleGreenCoralGameEnd: AbilityID = "unsupported.sr.gameEnd.card_181"
    nonisolated static let allDiveSitesCoralThreeGameEnd: AbilityID = "unsupported.sr.gameEnd.card_202"
    nonisolated static let anyDiveSiteCoralFiveGameEnd: AbilityID = "unsupported.sr.gameEnd.card_206"
    nonisolated static let greenCoralThreeGameEnd: AbilityID = "unsupported.sr.gameEnd.card_208"
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
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.freePlayBioluminescentWhenPlayed,
            trigger: .whenPlayed,
            effects: [.playFishForFree(filter: .tag("bioluminescent"), placement: .any, sourceCondition: .none, count: 1)],
            isOptional: true,
            displayText: "打出时：免费打出 1 张生物发光鱼"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.freePlaySmallWhenPlayed,
            trigger: .whenPlayed,
            effects: [.playFishForFree(filter: .lengthBucket(.small), placement: .any, sourceCondition: .none, count: 1)],
            isOptional: true,
            displayText: "打出时：免费打出 1 张小型鱼"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.freePlayMediumWhenPlayed,
            trigger: .whenPlayed,
            effects: [.playFishForFree(filter: .lengthBucket(.medium), placement: .any, sourceCondition: .none, count: 1)],
            isOptional: true,
            displayText: "打出时：免费打出 1 张中型鱼"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.freePlayCamouflageWhenPlayed,
            trigger: .whenPlayed,
            effects: [.playFishForFree(filter: .tag("camouflage"), placement: .any, sourceCondition: .none, count: 1)],
            isOptional: true,
            displayText: "打出时：免费打出 1 张伪装鱼"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.scatterSchoolTwiceGameEnd,
            trigger: .gameEnd,
            effects: [
                .scatterSchool(count: 1),
                .scatterSchool(count: 1)
            ],
            canResolveInAnyOrder: false,
            isOptional: true,
            displayText: "游戏结束：打散鱼群 2 次"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.blueCoralThreeGameEnd,
            trigger: .gameEnd,
            effects: [
                .gainCoral(selector: .blue, count: 1),
                .gainCoral(selector: .blue, count: 1),
                .gainCoral(selector: .blue, count: 1)
            ],
            canResolveInAnyOrder: false,
            isOptional: true,
            displayText: "游戏结束：获得 3 个蓝色珊瑚"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.freePlayMediumDuskySharkGameEnd,
            trigger: .gameEnd,
            effects: [.playFishForFree(filter: .lengthBucket(.medium), placement: .any, sourceCondition: .none, count: 1)],
            isOptional: true,
            displayText: "游戏结束：免费打出 1 张中型鱼"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.purpleCoralThreeGameEnd,
            trigger: .gameEnd,
            effects: [
                .gainCoral(selector: .purple, count: 1),
                .gainCoral(selector: .purple, count: 1),
                .gainCoral(selector: .purple, count: 1)
            ],
            canResolveInAnyOrder: false,
            isOptional: true,
            displayText: "游戏结束：获得 3 个紫色珊瑚"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.freePlayMediumFrilledSharkGameEnd,
            trigger: .gameEnd,
            effects: [.playFishForFree(filter: .lengthBucket(.medium), placement: .any, sourceCondition: .none, count: 1)],
            isOptional: true,
            displayText: "游戏结束：免费打出 1 张中型鱼"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.anyCoralTwiceGameEnd,
            trigger: .gameEnd,
            effects: [
                .gainCoral(selector: .any, count: 1),
                .gainCoral(selector: .any, count: 1)
            ],
            canResolveInAnyOrder: false,
            isOptional: true,
            displayText: "游戏结束：获得 2 个任意珊瑚"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.bluePurpleGreenCoralGameEnd,
            trigger: .gameEnd,
            effects: [
                .gainCoral(selector: .blue, count: 1),
                .gainCoral(selector: .purple, count: 1),
                .gainCoral(selector: .green, count: 1)
            ],
            canResolveInAnyOrder: false,
            isOptional: true,
            displayText: "游戏结束：获得蓝色、紫色、绿色珊瑚各 1 个"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.allDiveSitesCoralThreeGameEnd,
            trigger: .gameEnd,
            effects: [.gameEndScore(condition: .allDiveSitesHaveCoralAtLeast(3), points: 5)],
            isOptional: false,
            displayText: "游戏结束计分：若所有潜水点都有至少 3 个珊瑚，得 5 分"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.anyDiveSiteCoralFiveGameEnd,
            trigger: .gameEnd,
            effects: [.gameEndScore(condition: .anyDiveSiteHasCoralAtLeast(5), points: 3)],
            isOptional: false,
            displayText: "游戏结束计分：若任一潜水点有至少 5 个珊瑚，得 3 分"
        ),
        AbilityDefinition(
            abilityId: SharksAndReefsAbilityIDs.greenCoralThreeGameEnd,
            trigger: .gameEnd,
            effects: [
                .gainCoral(selector: .green, count: 1),
                .gainCoral(selector: .green, count: 1),
                .gainCoral(selector: .green, count: 1)
            ],
            canResolveInAnyOrder: false,
            isOptional: true,
            displayText: "游戏结束：获得 3 个绿色珊瑚"
        )
    ]
}

enum AbilityPatternParser {
    nonisolated static func abilityDefinition(
        abilityId: AbilityID,
        trigger: AbilityTrigger,
        rawAbilityText: String?
    ) -> AbilityDefinition? {
        guard let rawAbilityText,
              !rawAbilityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        let pattern = normalizedPattern(rawAbilityText)
        guard !pattern.contains("[AllPlayers]"),
              !pattern.contains(";")
        else {
            return nil
        }

        if let count = pureRepeatedTokenCount("[DrawCard]", in: pattern, maxCount: 5) {
            return AbilityDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effects: [.drawFish(count: count)],
                displayText: triggerText(trigger, action: "抽 \(count) 张鱼牌")
            )
        }

        if let count = pureRepeatedTokenCount("[Discard]", in: pattern, maxCount: 5) {
            return repeatedChoiceDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effect: .recoverFromDiscardOrDraw(count: 1),
                count: count,
                action: "从弃牌堆拿回 \(count) 张鱼牌，不足时从牌堆抽牌"
            )
        }

        if let compoundEffects = mixedCompoundEffects(from: pattern) {
            return AbilityDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effects: compoundEffects,
                canResolveInAnyOrder: true,
                isOptional: true,
                displayText: triggerText(trigger, action: "任选顺序结算多个收益")
            )
        }

        if let count = pureRepeatedTokenCount("[FishHatch]", in: pattern, maxCount: 4) {
            return repeatedChoiceDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effect: .hatchEgg(count: 1),
                count: count,
                action: "孵化 \(count) 个鱼卵"
            )
        }

        if let count = pureRepeatedTokenCount("[FishEgg]", in: pattern, maxCount: 4) {
            return repeatedChoiceDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effect: .placeEgg(count: 1),
                count: count,
                action: "放置 \(count) 个鱼卵"
            )
        }

        if let count = pureRepeatedTokenCount("[YoungFish]", in: pattern, maxCount: 4) {
            return repeatedChoiceDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effect: .placeYoung(count: 1),
                count: count,
                action: "放置 \(count) 个幼鱼"
            )
        }

        if let count = pureRepeatedTokenCount("[SchoolFeederMove]", in: pattern, maxCount: 4) {
            return repeatedChoiceDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effect: .moveYoungOrSchool(count: 1),
                count: count,
                action: "移动 \(count) 次幼鱼或鱼群"
            )
        }

        if let count = pureRepeatedTokenCount("[ConsumeFish1]", in: pattern, maxCount: 2) {
            return repeatedChoiceDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effect: .consumeFishFromHand(count: 1),
                count: count,
                action: "海洋中的鱼吞噬 \(count) 张更短手牌鱼"
            )
        }

        if let placement = paidPlayPlacement(from: pattern) {
            return AbilityDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effects: [.playFishFromHand(filter: .any, placement: placement, costMode: .payCost)],
                isOptional: true,
                displayText: triggerText(trigger, action: "从手牌打出 1 张鱼并支付费用")
            )
        }

        if let filter = freePlayFilter(from: pattern) {
            return AbilityDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effects: [
                    .playFishForFree(
                        filter: filter,
                        placement: .any,
                        sourceCondition: .none,
                        count: 1
                    )
                ],
                isOptional: true,
                displayText: triggerText(trigger, action: "免费从手牌打出 1 张鱼")
            )
        }

        if let filter = eggPlacementFilter(from: pattern) {
            return AbilityDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effects: [.placeEggOnMatchingFish(filter: filter, mode: .onEachEligibleFish)],
                isOptional: true,
                displayText: triggerText(trigger, action: "在每条匹配鱼上放置 1 个鱼卵")
            )
        }

        if let coralEffects = pureCoralGainEffects(from: pattern) {
            return AbilityDefinition(
                abilityId: abilityId,
                trigger: trigger,
                effects: coralEffects,
                canResolveInAnyOrder: false,
                isOptional: true,
                displayText: triggerText(trigger, action: "获得珊瑚")
            )
        }

        return nil
    }

    nonisolated private static func mixedCompoundEffects(from pattern: String) -> [AbilityEffectUnit]? {
        if pattern == "[FreePlayFishFromHand]ifno[AnyCoral]inthisfish'sdivesite" {
            return [
                .playFishForFree(
                    filter: .any,
                    placement: .sameDiveSiteAsSource,
                    sourceCondition: .sourceDiveSiteHasNoCoral,
                    count: 1
                )
            ]
        }

        var remaining = pattern
        var effects: [AbilityEffectUnit] = []
        while !remaining.isEmpty {
            if remaining.hasPrefix("[DrawCard]") {
                effects.append(.drawFish(count: 1))
                remaining.removeFirst("[DrawCard]".count)
            } else if remaining.hasPrefix("[Discard]") {
                effects.append(.recoverFromDiscardOrDraw(count: 1))
                remaining.removeFirst("[Discard]".count)
            } else if remaining.hasPrefix("[FishEgg]") {
                effects.append(.placeEgg(count: 1))
                remaining.removeFirst("[FishEgg]".count)
            } else if remaining.hasPrefix("[FishHatch]") {
                effects.append(.hatchEgg(count: 1))
                remaining.removeFirst("[FishHatch]".count)
            } else if remaining.hasPrefix("[YoungFish]") {
                effects.append(.placeYoung(count: 1))
                remaining.removeFirst("[YoungFish]".count)
            } else if remaining.hasPrefix("[SchoolFeederMove]") {
                effects.append(.moveYoungOrSchool(count: 1))
                remaining.removeFirst("[SchoolFeederMove]".count)
            } else if remaining.hasPrefix("[FishFromHandConsume]") {
                effects.append(.consumeFishFromHand(count: 1))
                remaining.removeFirst("[FishFromHandConsume]".count)
            } else {
                return nil
            }
        }

        guard effects.count > 1 else {
            return nil
        }

        let distinctKeys = Set(effects.map(abilityEffectKey))
        guard distinctKeys.count > 1 else {
            return nil
        }

        return effects
    }

    nonisolated private static func normalizedPattern(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
    }

    nonisolated private static func pureRepeatedTokenCount(
        _ token: String,
        in pattern: String,
        maxCount: Int
    ) -> Int? {
        guard !pattern.isEmpty else {
            return nil
        }
        for count in 1...maxCount where pattern == String(repeating: token, count: count) {
            return count
        }
        return nil
    }

    nonisolated private static func repeatedChoiceDefinition(
        abilityId: AbilityID,
        trigger: AbilityTrigger,
        effect: AbilityEffectUnit,
        count: Int,
        action: String
    ) -> AbilityDefinition {
        AbilityDefinition(
            abilityId: abilityId,
            trigger: trigger,
            effects: Array(repeating: effect, count: count),
            canResolveInAnyOrder: false,
            isOptional: true,
            displayText: triggerText(trigger, action: action)
        )
    }

    nonisolated private static func eggPlacementFilter(from pattern: String) -> EggPlacementFilter? {
        guard pattern.hasPrefix("[FishEgg][ArrowDown]") else {
            return nil
        }
        let remainder = String(pattern.dropFirst("[FishEgg][ArrowDown]".count))
            .replacingOccurrences(of: "(oneach)", with: "")
            .replacingOccurrences(of: "oneach", with: "")
        switch remainder {
        case "[Estuary]":
            return .topRow
        case "[PlayFishBottomRow]":
            return .bottomRow
        case "[Predator]":
            return .tag("predator")
        case "[FishLengthSmall]":
            return .lengthBucket(.small)
        case "[FishLengthMedium]":
            return .lengthBucket(.medium)
        case "[FishLengthLarge]":
            return .lengthBucket(.large)
        case "[FlipperBlue]":
            return .diveSite(.blue)
        case "[FlipperPurple]":
            return .diveSite(.purple)
        case "[FlipperGreen]":
            return .diveSite(.green)
        default:
            return nil
        }
    }

    nonisolated private static func paidPlayPlacement(from pattern: String) -> FishPlacementConstraint? {
        guard pattern.hasPrefix("[FishFromHand][ArrowDown]") else {
            return nil
        }
        let remainder = String(pattern.dropFirst("[FishFromHand][ArrowDown]".count))
        switch remainder {
        case "[Estuary]",
             "[PlayFishTopRow]":
            return .topRow
        case "[PlayFishBottomRow]",
             "[Deepwater]":
            return .bottomRow
        case "[Sun]":
            return .sunlight
        case "[FlipperBlue]":
            return .diveSite(.blue)
        case "[FlipperPurple]":
            return .diveSite(.purple)
        case "[FlipperGreen]":
            return .diveSite(.green)
        case "[AnyCoral][AnyCoral][AnyCoral](inadivesitewithatleast3)":
            return .diveSiteWithCoralAtLeast(3)
        case "[AnyCoral][AnyCoral][AnyCoral][AnyCoral][AnyCoral](inadivesitewithatleast5)":
            return .diveSiteWithCoralAtLeast(5)
        default:
            return nil
        }
    }

    nonisolated private static func freePlayFilter(from pattern: String) -> FreePlayFishFilter? {
        if pattern == "[FreePlayFishFromHand]ifno[AnyCoral]inthisfish'sdivesite" {
            return nil
        }
        guard pattern.hasPrefix("[FreePlayFishFromHand]") else {
            return nil
        }
        let remainder = String(pattern.dropFirst("[FreePlayFishFromHand]".count))
            .replacingOccurrences(of: "only", with: "")
        if remainder.isEmpty {
            return .any
        }
        switch remainder {
        case "[FishLengthSmall]":
            return .lengthBucket(.small)
        case "[FishLengthMedium]":
            return .lengthBucket(.medium)
        case "[FishLengthLarge]":
            return .lengthBucket(.large)
        case "[Bioluminescent]":
            return .tag("bioluminescent")
        case "[Camouflage]":
            return .tag("camouflage")
        default:
            return nil
        }
    }

    nonisolated private static func pureCoralGainEffects(from pattern: String) -> [AbilityEffectUnit]? {
        var remaining = pattern
        var effects: [AbilityEffectUnit] = []
        while !remaining.isEmpty {
            if remaining.hasPrefix("[BlueCoral]") {
                effects.append(.gainCoral(selector: .blue, count: 1))
                remaining.removeFirst("[BlueCoral]".count)
            } else if remaining.hasPrefix("[PurpleCoral]") {
                effects.append(.gainCoral(selector: .purple, count: 1))
                remaining.removeFirst("[PurpleCoral]".count)
            } else if remaining.hasPrefix("[GreenCoral]") {
                effects.append(.gainCoral(selector: .green, count: 1))
                remaining.removeFirst("[GreenCoral]".count)
            } else if remaining.hasPrefix("[AnyCoral]") {
                effects.append(.gainCoral(selector: .any, count: 1))
                remaining.removeFirst("[AnyCoral]".count)
            } else {
                return nil
            }
        }
        return effects.isEmpty ? nil : effects
    }

    nonisolated private static func triggerText(_ trigger: AbilityTrigger, action: String) -> String {
        switch trigger {
        case .whenPlayed:
            return "打出时：\(action)"
        case .ifActivated:
            return "发动时：\(action)"
        case .gameEnd:
            return "游戏结束：\(action)"
        }
    }

    nonisolated private static func abilityEffectKey(_ effect: AbilityEffectUnit) -> String {
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
        case .consumeFishFromHand:
            return "consumeFishFromHand"
        case .playFishForFree:
            return "playFishForFree"
        case .gameEndScore:
            return "gameEndScore"
        case .placeEggOnMatchingFish:
            return "placeEggOnMatchingFish"
        case .playFishFromHand:
            return "playFishFromHand"
        case .gainCoral:
            return "gainCoral"
        case .scatterSchool:
            return "scatterSchool"
        case .unsupported:
            return "unsupported"
        }
    }
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
                ?? AbilityPatternParser.abilityDefinition(
                    abilityId: abilityId,
                    trigger: abilityTrigger(for: abilityId),
                    rawAbilityText: card.abilityText
                )
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
        let trigger = abilityTrigger(for: abilityId)
        return AbilityDefinition(
            abilityId: abilityId,
            trigger: trigger,
            effects: [.unsupported],
            isOptional: true
        )
    }

    nonisolated private func abilityTrigger(for abilityId: AbilityID) -> AbilityTrigger {
        let trigger: AbilityTrigger
        if abilityId.contains(".gameEnd.") {
            trigger = .gameEnd
        } else if abilityId.contains(".whenPlayed.") {
            trigger = .whenPlayed
        } else {
            trigger = .ifActivated
        }
        return trigger
    }
}

import Foundation

enum AppStrings {
    enum Lobby {
        static let title = "本地房间"
        static let room = "房间"
        static let code = "房间码"
        static let host = "房主"
        static let status = "状态"
        static let players = "玩家"
        static let noLocalRoom = "暂无本地房间"
        static let noLocalRoomDescription = "创建本地房间后即可测试流程。"
        static let actions = "操作"
        static let gameDataMode = "卡牌数据"
        static let sampleGameData = "示例数据"
        static let baseGameData = "基础版真实卡牌"
        static let expansions = "扩展"
        static let sharksAndReefsExpansion = "Sharks & Reefs"
        static let nautomaExpansion = "Nautoma（暂未实现）"
        static let weeklyGoalSetup = "周目标面板"
        static let weeklyGoalSideA = "A 面"
        static let weeklyGoalSideB = "B 面"
        static let weeklyGoalSelectionMode = "B 面目标"
        static let weeklyGoalRandom = "随机三周目标"
        static let weeklyGoalCustom = "房主自选周目标"
        static func weeklyGoalWeekTitle(_ week: Int) -> String { "第 \(week) 周" }
        static let weeklyGoalMissingSelection = "请为 B 面自选目标选择第 1、2、3 周目标。"
        static let createLocalRoom = "创建本地房间"
        static let joinSimulatedPlayer = "加入模拟玩家"
        static let activePlayer = "当前选择玩家"
        static let none = "无"
        static let color = "颜色"
        static let chooseColor = "选择颜色"
        static let toggleReady = "切换准备"
        static let hostStartGame = "房主开始游戏"
        static let selectPlayerFirst = "请先选择玩家。"
        static let noRoom = "暂无房间"
        static let hostName = "房主"
        static let simulatedPlayerPrefix = "玩家"
        static let ready = "已准备"
        static let notReady = "未准备"
    }

    static func gameDataModeName(_ mode: GameDataMode) -> String {
        switch mode {
        case .sample:
            return Lobby.sampleGameData
        case .baseGame:
            return Lobby.baseGameData
        }
    }

    static func coralReefProgressText(coralCount: Int, maxCoral: Int) -> String {
        "\(coralCount)/\(maxCoral)"
    }

    static func coralReefCompletionBonusText(completionBonus: Int) -> String {
        "+\(completionBonus)"
    }

    enum GameBoard {
        static let title = "游戏面板"
        static let turn = "回合"
        static let settings = "设置"
        static let endCurrentGameAndReturnHome = "结束当前对局并返回主页"
        static let cancel = "取消"
        static let currentAction = "当前行动"
        static let activePlayerInfo = "行动玩家"
        static let currentPlayer = "当前玩家"
        static let remainingDivers = "剩余潜水员"
        static let eggTotal = "鱼卵总数"
        static let youngTotal = "幼鱼总数"
        static let schoolTotal = "鱼群总数"
        static let handCount = "手牌"
        static let consumedFishCount = "被吞食鱼"
        static let opponentBoardPreviewUnavailable = "查看对手海洋暂未接入"
        static let gameStartedSummary = "游戏开始"
        static let weeklyGoalDetailTitle = "周目标"
        static let weekOneGoalDescription = "鱼卵和幼鱼"
        static let weekTwoGoalDescription = "整排的鱼"
        static let weekThreeGoalDescription = "鱼群"
        static let coralCountGoalDescription = "珊瑚数量"
        static let discardPileCardsGoalDescription = "弃牌堆鱼牌"
        static let sunlitFishGoalDescription = "阳光带鱼牌"
        static let gameEndGoalTitle = "终局能力"
        static let gameEndGoalShortDescription = "发动游戏结束能力，随后计分"
        static let gameEndGoalDescription = "第 4 周结束后，以任意顺序发动自己海洋中任意多个“游戏结束”能力，随后进行最终计分。"
        static let gameEndGoalNote = "第 4 格不是周奖励分。"
        static let finalScoreHiddenHint = "最终计分会在游戏结束后显示。"
        static let settledScoreText = "已结算分"
        static let weeklyGoalNotScoredText = "未结算"
        static let logButton = "日志"
        static let currentWeek = "当前周数"
        static let currentTurn = "当前回合"
        static let activePlayer = "当前行动玩家"
        static let phase = "当前阶段"
        static let players = "玩家"
        static let eventLog = "事件日志"
        static let noEvents = "暂无事件"
        static let noEventsDescription = "房间命令被接受后会显示事件。"
        static let errorArea = "错误提示"
        static let noError = "暂无错误"
        static let hand = "当前玩家手牌"
        static let ocean = "玩家海域"
        static let coralReef = "珊瑚礁"
        static let actionPanel = "出牌操作"
        static let divePanel = "潜水操作"
        static let chooseDiveSite = "选择潜水点"
        static let dive = "潜水"
        static let pendingChoicePanel = "待处理选择"
        static let noPendingChoices = "暂无待处理选择。"
        static let currentRewards = "当前收益"
        static let noCurrentRewards = "当前没有待领取收益"
        static let triggering = "正在触发"
        static let activating = "正在发动"
        static let chooseRewardToken = "请选择一个收益"
        static let chooseRewardThenTarget = "请选择收益，再选择左侧目标"
        static let chooseRewardThenSource = "请选择收益，再选择来源"
        static let chooseCoralDiveSite = "选择一个潜水点放置珊瑚"
        static let chooseLeftTarget = "请选择左侧目标"
        static let chooseSource = "请选择来源"
        static let weeklyAchievementPanel = "周成就分"
        static let noWeeklyAchievementResults = "暂无周成就结果。"
        static let finalScoreTitle = "最终结算"
        static let finalScoreNoResult = "暂无最终结算结果。"
        static let finalScoreWinner = "获胜玩家"
        static let finalScoreTie = "并列获胜玩家"
        static let finalScoreLegend = "计分图例"
        static let finalScoreTotal = "总分"
        static let finalScoreFinalPoints = "最终得分"
        static let finalScoreWeeklyAchievements = "周成就"
        static let finalScoreFishPrintedPoints = "鱼牌分"
        static let finalScoreGameEndAbility = "游戏结束能力"
        static let finalScoreEggsAndYoung = "鱼卵 / 幼鱼"
        static let finalScoreSchools = "鱼群"
        static let finalScoreConsumedFish = "被吞食鱼"
        static let finalScoreCoral = "珊瑚"
        static let finalScoreCompleteReefBonus = "完整珊瑚礁奖励"
        static let gameEndAbilityPhaseTitle = "游戏结束能力"
        static let gameEndAbilityPhaseSummary = "可以按任意顺序发动可用的游戏结束能力。"
        static let gameEndAbilityPhaseEmpty = "没有可发动的游戏结束能力。"
        static let gameEndAbilityAvailable = "可发动"
        static let gameEndAbilityActivated = "已处理"
        static let gameEndAbilityAutomaticScoring = "计分时自动计算"
        static let gameEndAbilityUnsupported = "能力暂未接入"
        static let finishGameEndAbilities = "进入最终计分"
        static let playerColor = "玩家颜色"
        static let pendingChoicePlayer = "玩家"
        static let pendingChoiceSource = "来源"
        static let pendingChoiceStatus = "状态"
        static let pendingChoiceWaiting = "待处理"
        static let optionalChoice = "可跳过"
        static let requiredChoice = "必须处理"
        static let skipChoice = "跳过"
        static let drawOneFishCard = "抽 1 张鱼牌"
        static func drawFishCard(count: Int) -> String { "抽 \(count) 张鱼牌" }
        static let recoverOneFromDiscard = "从弃牌堆拿回 1 张"
        static let triggeringFishAbilityPrefix = "正在发动"
        static let placeEggAbilityAction = "放置鱼卵"
        static let hatchEggAbilityAction = "孵化鱼卵"
        static let finishAbility = "结束此能力"
        static let chooseTargetUnsupported = "选择目标（暂未接入）"
        static let chooseTargetFromList = "请从目标列表中选择格子。"
        static let choosePlaceEggTarget = "选择放置鱼卵的格子"
        static let chooseHatchEggTarget = "选择要孵化的鱼卵"
        static let recoverFromDiscardOrDraw = "从弃牌堆拿回 1 张牌"
        static let discardPile = "弃牌堆"
        static let discardPileEmpty = "弃牌堆为空"
        static let close = "关闭"
        static let discardPileEmptyDrawAlternative = "弃牌堆为空，改为抽 1 张鱼牌"
        static let chooseDiscardCardToRecover = "选择要拿回的弃牌"
        static let discardPileEmptyDrawHint = "弃牌堆为空，可从牌堆抽 1 张"
        static let moveYoungOrSchool = "移动幼鱼或鱼群"
        static let moveYoung = "移动幼鱼"
        static let moveSchool = "移动鱼群"
        static let gainCoral = "获得珊瑚"
        static let gainOneCoral = "获得 1 个珊瑚"
        static let payOneEgg = "支付 1 个鱼卵"
        static let payOneYoung = "支付 1 个幼鱼"
        static let discardOneHandCard = "弃 1 张手牌"
        static let chooseCoralPayment = "选择珊瑚支付方式"
        static let chooseCoralResourceSource = "选择支付来源"
        static let chooseCoralDiscardCard = "选择要弃掉的手牌"
        static let noCoralPaymentResource = "没有可支付的资源"
        static let noCoralPaymentHandCard = "没有可弃掉的手牌"
        static let coralReefFull = "珊瑚礁已满"
        static let scatterSchool = "打散鱼群"
        static let scatterSchoolSource = "选择要打散的鱼群"
        static let scatterSchoolYoungTarget = "选择放置幼鱼的格子"
        static let scatterSchoolNoSchool = "无鱼群：放置 1 个幼鱼"
        static let scatterSchoolNoSource = "没有可打散的鱼群"
        static let scatterSchoolTargetAlreadyUsed = "已选择过这个格子"
        static func scatterSchoolProgressText(completedCount: Int, totalCount: Int) -> String {
            "放置幼鱼 \(completedCount) / \(totalCount)"
        }
        static let consumeFishFromHand = "吞噬手牌鱼"
        static let consumeFishConsumer = "选择吞噬者"
        static let consumeFishHandCard = "选择一张更短的手牌鱼"
        static let consumeFishNoConsumer = "没有可吞噬手牌鱼的海洋鱼"
        static let consumeFishNoHandCard = "没有可吞噬的手牌鱼"
        static let consumeFishMustBeShorter = "只能选择更短的鱼"
        static let playFishForFree = "免费打出手牌鱼"
        static let playFishForFreeHandCard = "选择要免费打出的鱼"
        static let playFishForFreeTarget = "选择免费出牌位置"
        static let playFishForFreeNoMatchingHandCard = "没有符合条件的手牌鱼"
        static let playFishForFreeFilterMismatch = "这张鱼不符合能力限制"
        static let placeEggOnMatchingFish = "匹配鱼放置鱼卵"
        static let playFishFromHand = "从手牌打出鱼"
        static let playFishFromHandHandCard = "选择要打出的鱼"
        static let playFishFromHandTarget = "选择出牌位置"
        static let playFishFromHandPayment = "支付费用并确认"
        static let playFishFromHandNoMatchingHandCard = "没有符合条件的手牌鱼"
        static let abilityUnsupported = "能力暂未接入"
        static let bottomBonus = "底部奖励"
        static let firstBottomBonus = "首次到底奖励"
        static let bottomBonusClaimedThisWeek = "本周已领取"
        static let bottomBonusAvailableThisWeek = "本周尚未领取"
        static let gainOneEgg = "获得 1 个鱼卵"
        static let triggeringFirstBottomBonus = "正在触发：首次到底奖励"
        static let chooseMoveSource = "选择移动来源"
        static let chooseMoveTarget = "选择移动目标"
        static let noMovableYoungOrSchool = "没有可移动的幼鱼或鱼群"
        static let noPendingChoiceTargets = "没有可用目标"
        static let unsupportedSkippableChoice = "暂未接入，可跳过"
        static let resolveCurrentRewardFirst = "请先处理当前奖励选择。"
        static let resolveCurrentDiveRewardFirst = "请先处理当前潜水奖励"
        static let diversUsedThisWeek = "本周潜水员已用完"
        static let chooseMainAction = "请选择出牌或潜水"
        static let passTurnNotAllowed = "不能空过回合，请选择出牌或潜水。"
        static let chooseTarget = "选择目标"
        static let drawFish = "抽鱼牌"
        static let chooseOption = "选择选项"
        static let pendingChoiceNotFound = "找不到待处理选择。"
        static let pendingChoiceNotOwned = "只有该选择所属玩家可以处理。"
        static let pendingChoiceRequired = "该选择不能跳过。"
        static let pendingChoiceResolutionInvalid = "该选择的处理方式暂未支持。"
        static let fishDrawPileEmpty = "鱼牌牌堆为空，暂时无法抽牌。"
        static let noActivePlayer = "暂无行动玩家。"
        static let noActiveRoom = "暂无活动房间。"
        static let noActiveHand = "当前行动玩家没有可显示的手牌。"
        static let noOceanSlots = "当前行动玩家没有可显示的海域格子。"
        static let selectCard = "选择鱼牌"
        static let selectSlot = "选择格子"
        static let selected = "已选择"
        static let occupied = "已占用"
        static let empty = "空格"
        static let forageFish = "印刷小鱼"
        static let cardFaceEmptySlot = "空海域"
        static let cardFaceUnknownFishImage = "鱼图待接入"
        static let cardFaceUnknownCard = "未知鱼牌"
        static let cardFacePointsSuffix = "分"
        static let cardFaceNoScientificName = "暂无学名"
        static let cardFaceNoTags = "无标签"
        static let cardFaceTags = "标签"
        static let cardFaceAbility = "能力"
        static let cardFaceAbilityTextMissing = "能力文本待接入"
        static let cardFaceLocalAssetMissing = "本地素材缺失"
        static let cardFaceNoAbility = "无能力"
        static let abilityTriggerWhenPlayed = "打出时"
        static let abilityTriggerIfActivated = "发动时"
        static let abilityTriggerGameEnd = "游戏结束"
        static let abilityTriggerUnknown = "能力"
        static let resources = "资源"
        static let noResources = "无资源"
        static let discardPayment = "弃牌费用"
        static let chooseDiscardCards = "选择要弃置的手牌"
        static let resourcePayment = "资源费用"
        static let chooseEggSources = "选择鱼卵来源"
        static let chooseYoungSources = "选择幼鱼来源"
        static let anyResourceSourceHint = "可从任意已有资源的格子选择来源。"
        static let eggPaymentIncomplete = "请选择足够数量的鱼卵来源。"
        static let youngPaymentIncomplete = "请选择足够数量的幼鱼来源。"
        static let playFishPayment = "出牌支付"
        static let playFishPaymentCard = "打出"
        static let playFishPaymentTarget = "目标"
        static let noTargetSelected = "未选择目标"
        static let confirmPlayFish = "确认出牌"
        static let cancelPlayFish = "取消出牌"
        static let discardPaymentSelectable = "可弃置"
        static let discardPaymentSelected = "将弃置"
        static let discardPaymentInsufficient = "手牌不足以支付费用"
        static let resourcePaymentProgress = "资源支付进度"
        static let resourcePaymentAlreadyComplete = "已选足够"
        static let resourceTokenNotRequired = "当前不需要"
        static let resourceTokenUnsupportedPayment = "暂不支持支付"
        static let resourceTokenIllegalMultipleEggs = "鱼卵数量异常"
        static let resourceTokenIllegalMultipleSchools = "鱼群数量异常"
        static let resourceTokenIllegalYoungWithoutSchool = "幼鱼应形成鱼群"
        static let paymentSelectionMarker = "×"
        static let sourceSelectedCount = "已选"
        static let sourceAvailableCount = "可用"
        static let playable = "可打出"
        static let notPlayable = "暂不可打出"
        static let insufficientPaymentSources = "费用来源不足"
        static let noPlayableSlot = "没有可用格子"
        static let playFish = "出牌"
        static let costUnsupportedInUI = "该费用类型暂未接入界面。"
        static let discardPaymentIncomplete = "请选择正确数量的弃牌。"
        static let playFishSucceeded = "出牌成功。"
        static let cancelPlayFishSelection = "取消出牌选择"
        static let finishOrCancelPlayFish = "正在出牌，请先完成或取消当前出牌。"
        static let selectedFishCard = "当前选择鱼牌"
        static let fishCardName = "鱼牌名称"
        static let score = "分数"
        static let length = "长度"
        static let allowedZones = "可放置区域"
        static let requiredDiveSite = "限定潜水点"
        static let costs = "费用"
        static let abilitySummary = "能力摘要"
        static let unsupportedItems = "暂未接入项目"
        static let noLimit = "不限"
        static let centimeters = "厘米"
        static let unknownCard = "未知卡牌"
        static let noCost = "无费用"
        static let cardScoreUnsupported = "暂未接入"
        static let cardLengthUnsupported = "暂未接入"
        static let slotAvailable = "可放置"
        static let slotOccupied = "已占用"
        static let slotZoneMismatch = "区域不符"
        static let slotDiveSiteMismatch = "潜水点不符"
        static let slotSelectFishFirst = "先选择鱼牌"
        static let mustCoverShorterFish = "这张鱼必须覆盖一条更短的鱼"
        static let cannotCoverLongerOrSameFish = "不能覆盖更长或同长度的鱼"
        static let canCoverShorterFish = "可以覆盖较短的鱼"
        static let reefFishMustBeSunlit = "这张鱼只能打在阳光层"
        static let coralReefMissing = "该潜水点没有珊瑚礁"
        static let coralInsufficient = "珊瑚不足"
        static func coralRequirementText(count: Int) -> String {
            "需要至少 \(count) 个珊瑚"
        }
        static let dragToPlayHere = "拖到这里打出"
        static let slotCannotPlayHere = "该位置不能打出"
        static let payCostsFirst = "请先支付费用"
        static let dragPlayTargetSelected = "拖拽出牌已选择目标"
        static let unsupportedRequirementInUI = "暂不支持该条件"
        static let unsupportedAbilityInUI = "能力暂未接入"
        static let topRow = "顶行"
        static let bottomRow = "底行"
        static let active = "行动中"
        static let connected = "已连接"
        static let disconnected = "未连接"

        static func weeklyAchievementTitle(week: Int, playerName: String) -> String {
            "第 \(week) 周 · \(playerName)"
        }

        static func weeklyAchievementResultText(
            kind: AchievementKind,
            quantity: Int,
            points: Int
        ) -> String {
            "\(AppStrings.achievementKindName(kind)) \(quantity) \(AppStrings.achievementQuantityUnit(kind))，得 \(points) 分"
        }

        static func weeklyAchievementEventPlayerSummary(
            playerName: String,
            points: Int
        ) -> String {
            "\(playerName) 成就得 \(points) 分"
        }

        static func weekEndedEventText(
            endedWeek: Int,
            nextWeek: Int?,
            isGameEndTriggered: Bool,
            achievementSummary: String?
        ) -> String {
            if let achievementSummary, !achievementSummary.isEmpty {
                if let nextWeek {
                    return "第 \(endedWeek) 周结束：\(achievementSummary)，进入第 \(nextWeek) 周"
                }
                return "第 \(endedWeek) 周结束：\(achievementSummary)"
            }
            if let nextWeek {
                return "第 \(endedWeek) 周结束，进入第 \(nextWeek) 周"
            }
            if isGameEndTriggered {
                return "第 \(endedWeek) 周结束，游戏结束待结算"
            }
            return "第 \(endedWeek) 周结束"
        }

        static func finalScoreWinnerText(playerNames: [String], isTie: Bool) -> String {
            let label = isTie ? finalScoreTie : finalScoreWinner
            return "\(label)：\(playerNames.joined(separator: "、"))"
        }

        static func finalScorePlayerColorText(_ colorName: String?) -> String {
            guard let colorName else {
                return "\(playerColor)：未选择"
            }
            return "\(playerColor)：\(colorName)"
        }

        static func finalScorePointsText(title: String, points: Int) -> String {
            "\(title) +\(points)"
        }

        static func finalScoreTotalText(points: Int) -> String {
            "\(finalScoreFinalPoints) \(points) 分"
        }

        static func gameEndedEventText(winnerNames: [String]) -> String {
            guard !winnerNames.isEmpty else {
                return "游戏结束，最终计分已完成"
            }
            return "游戏结束，获胜玩家：\(winnerNames.joined(separator: "、"))"
        }

        static func resourcePaymentProgressText(
            resourceName: String,
            selectedCount: Int,
            requiredCount: Int
        ) -> String {
            "\(resourceName)：已选择 \(selectedCount) / \(requiredCount)"
        }

        static func discardPaymentProgressText(selectedCount: Int, requiredCount: Int) -> String {
            "手牌：已选择 \(selectedCount) / \(requiredCount)"
        }

        static func discardPileCountText(_ count: Int) -> String {
            "弃牌 \(count)"
        }

        static func discardPileDetailCountText(_ count: Int) -> String {
            "共 \(count) 张"
        }

        static func triggeringFishAbility(cardName: String) -> String {
            "\(triggeringFishAbilityPrefix)：\(cardName)"
        }

        static func compoundAbilityProgressText(title: String, completedCount: Int, totalCount: Int) -> String {
            "\(title) \(completedCount) / \(totalCount)"
        }

        static func topBarWeekText(_ week: Int) -> String {
            week > 0 ? "第 \(week) 周" : "第 - 周"
        }

        static func topBarActivePlayerText(name: String, colorName: String?) -> String {
            guard let colorName else {
                return "当前：\(name)"
            }
            return "当前：\(name)（\(colorName)）"
        }

        static func topBarDiverText(available: Int, total: Int) -> String {
            "潜水员 \(available) / \(total)"
        }

        static func topBarResourceSummaryText(eggs: Int, young: Int, schools: Int) -> String {
            "鱼卵 \(eggs) · 幼鱼 \(young) · 鱼群 \(schools)"
        }

        static func topBarPlayerCountText(_ count: Int) -> String {
            "\(count) 人"
        }

        static func weeklyGoalBoxTitle(_ index: Int) -> String {
            index == 4 ? "第 4 周" : "第 \(index) 周"
        }

        static func currentProjectedScoreText(quantity: Int) -> String {
            "当前预计：\(quantity)"
        }

        static func weeklyGoalScoreText(points: Int) -> String {
            "\(points) 分"
        }

        static func weeklyGoalProjectedScoreText(quantity: Int) -> String {
            "预计 \(quantity)"
        }

        static func fishPlayedActionSummary(playerName: String, cardName: String) -> String {
            "\(playerName) 打出：\(cardName)"
        }

        static func diverMovedActionSummary(playerName: String, diveSiteName: String) -> String {
            "\(playerName) 潜水：\(diveSiteName)"
        }

        static func rewardResolvedActionSummary(playerName: String) -> String {
            "\(playerName) 处理奖励"
        }

        static func rewardDrawFishActionSummary(playerName: String) -> String {
            "\(playerName) 抽取鱼牌"
        }

        static func rewardPlaceEggActionSummary(playerName: String) -> String {
            "\(playerName) 放置鱼卵"
        }

        static func rewardHatchEggActionSummary(playerName: String) -> String {
            "\(playerName) 孵化鱼卵"
        }

        static func rewardMoveResourceActionSummary(playerName: String) -> String {
            "\(playerName) 移动幼鱼 / 鱼群"
        }

        static func rewardScatterSchoolActionSummary(playerName: String) -> String {
            "\(playerName) 打散了一个鱼群"
        }

        static func rewardScatterSchoolYoungActionSummary(playerName: String) -> String {
            "\(playerName) 放置了 1 个幼鱼"
        }

        static func rewardConsumeFishFromHandActionSummary(
            playerName: String,
            consumerName: String,
            consumedName: String
        ) -> String {
            "\(playerName) 的 \(consumerName) 吞噬了手牌中的 \(consumedName)"
        }

        static func rewardPlayFishForFreeActionSummary(playerName: String, cardName: String) -> String {
            "\(playerName) 免费打出了 \(cardName)"
        }

        static func rewardGainCoralActionSummary(playerName: String, diveSiteName: String) -> String {
            "\(playerName) 在\(diveSiteName)获得 1 个珊瑚"
        }

        static func rewardSkipCoralActionSummary(playerName: String) -> String {
            "\(playerName) 跳过珊瑚礁奖励"
        }

        static func weekEndedActionSummary(week: Int) -> String {
            "第 \(week) 周结束"
        }

        static let gameEndedActionSummary = "游戏结束，进入结算"
    }

    static func achievementKindName(_ kind: AchievementKind) -> String {
        switch kind {
        case .eggsAndYoung:
            return "鱼卵/幼鱼"
        case .rowsOfFish:
            return "鱼的行"
        case .schools:
            return "鱼群"
        case .coralCount:
            return "珊瑚"
        case .discardPileCards:
            return "弃牌"
        case .sunlitFish:
            return "阳光带鱼牌"
        }
    }

    static func achievementQuantityUnit(_ kind: AchievementKind) -> String {
        switch kind {
        case .eggsAndYoung,
             .schools,
             .coralCount,
             .discardPileCards,
             .sunlitFish:
            return "个"
        case .rowsOfFish:
            return "行"
        }
    }

    static func oceanZoneName(_ zone: OceanZone) -> String {
        switch zone {
        case .sunlit:
            return "阳光层"
        case .twilight:
            return "暮光层"
        case .midnight:
            return "深海层"
        }
    }

    static func diveSiteColorName(_ color: DiveSiteColor) -> String {
        switch color {
        case .blue:
            return "蓝色"
        case .purple:
            return "紫色"
        case .green:
            return "绿色"
        }
    }

    static func oceanDiveSiteName(_ site: DiveSite) -> String {
        switch site {
        case .blue:
            return "蓝色潜水点"
        case .purple:
            return "紫色潜水点"
        case .green:
            return "绿色潜水点"
        }
    }

    static func oceanRowLabel(rowIndex: Int) -> String {
        switch rowIndex {
        case 0:
            return "阳光层 1 / 顶行"
        case 1:
            return "阳光层 2"
        case 2:
            return "阳光层 3"
        case 3:
            return "暮光层"
        case 4:
            return "深海层 1"
        case 5:
            return "深海层 2 / 底行"
        default:
            return "未知行"
        }
    }

    static func diveActionSiteName(_ site: DiveActionSite) -> String {
        switch site {
        case .blue:
            return "蓝色潜水点"
        case .purple:
            return "紫色潜水点"
        case .green:
            return "绿色潜水点"
        default:
            return site.rawValue
        }
    }

    static func pendingChoiceKindName(_ kind: PendingChoiceKind) -> String {
        switch kind {
        case .drawFish:
            return "抽鱼牌"
        case .placeEgg:
            return "放置鱼卵"
        case .hatchEgg:
            return "孵化鱼卵"
        case .recoverFromDiscardOrDraw:
            return "从弃牌堆拿回 1 张牌"
        case .moveYoungOrSchool:
            return "移动幼鱼或鱼群"
        case .gainCoral:
            return "获得珊瑚"
        case .placeEggOnMatchingFish:
            return "匹配鱼放置鱼卵"
        case .scatterSchool:
            return "打散鱼群"
        case .consumeFishFromHand:
            return "吞噬手牌鱼"
        case .playFishForFree:
            return "免费打出手牌鱼"
        case .playFishFromHand:
            return "从手牌打出鱼"
        case .compoundAbility:
            return "鱼牌能力"
        case .bottomBonus:
            return "底部奖励"
        case .placeholder:
            return "占位选择"
        case .unsupported:
            return "暂未支持的选择"
        }
    }

    static func pendingChoiceSourceName(_ source: PendingChoiceSource) -> String {
        switch source {
        case let .diveBonus(site):
            return "\(diveActionSiteName(site))奖励"
        case let .coralReef(diveSite):
            return "\(oceanDiveSiteName(diveSite))珊瑚礁"
        case .fishAbility:
            return "鱼牌能力"
        case .endGameAbility:
            return "游戏结束能力"
        case .allPlayers:
            return "所有玩家效果"
        case .expansion:
            return "扩展规则"
        case .placeholder:
            return "占位来源"
        }
    }

    static func phaseName(_ phase: GamePhase) -> String {
        switch phase {
        case .lobby:
            return "大厅"
        case .setup:
            return "准备"
        case .playing:
            return "游戏中"
        case .awaitingChoice:
            return "等待选择"
        case .weekScoring:
            return "周结算"
        case .endGamePending:
            return "游戏结束能力"
        case .gameEnded:
            return "游戏结束"
        }
    }

    static func roomStatusName(_ status: RoomStatus) -> String {
        switch status {
        case .waiting:
            return "等待中"
        case .configuring:
            return "配置中"
        case .inProgress:
            return "游戏中"
        case .paused:
            return "已暂停"
        case .finished:
            return "已结束"
        case .closed:
            return "已关闭"
        }
    }

    static func roleName(_ role: RoomRole) -> String {
        switch role {
        case .host:
            return "房主"
        case .player:
            return "玩家"
        case .spectator:
            return "旁观者"
        }
    }

    static func colorName(_ color: PlayerColor) -> String {
        switch color {
        case .blue:
            return "蓝色"
        case .green:
            return "绿色"
        case .yellow:
            return "黄色"
        case .red:
            return "红色"
        case .purple:
            return "紫色"
        }
    }
}

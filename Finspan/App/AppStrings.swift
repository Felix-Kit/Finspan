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

    enum GameBoard {
        static let title = "游戏面板"
        static let turn = "回合"
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
        static let actionPanel = "出牌操作"
        static let divePanel = "潜水操作"
        static let chooseDiveSite = "选择潜水点"
        static let dive = "潜水"
        static let pendingChoicePanel = "待处理选择"
        static let noPendingChoices = "暂无待处理选择。"
        static let pendingChoicePlayer = "玩家"
        static let pendingChoiceSource = "来源"
        static let pendingChoiceStatus = "状态"
        static let pendingChoiceWaiting = "待处理"
        static let optionalChoice = "可跳过"
        static let requiredChoice = "必须处理"
        static let skipChoice = "跳过"
        static let drawOneFishCard = "抽 1 张鱼牌"
        static let chooseTargetUnsupported = "选择目标（暂未接入）"
        static let chooseTargetFromList = "请从目标列表中选择格子。"
        static let choosePlaceEggTarget = "选择放置鱼卵的格子"
        static let chooseHatchEggTarget = "选择要孵化的鱼卵"
        static let noPendingChoiceTargets = "没有可用目标"
        static let unsupportedSkippableChoice = "暂未接入，可跳过"
        static let resolveCurrentRewardFirst = "请先处理当前奖励选择。"
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
        static let sourceSelectedCount = "已选"
        static let sourceAvailableCount = "可用"
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
        static let unsupportedRequirementInUI = "暂不支持该条件"
        static let unsupportedAbilityInUI = "能力暂未接入"
        static let topRow = "顶行"
        static let bottomRow = "底行"
        static let active = "行动中"
        static let connected = "已连接"
        static let disconnected = "未连接"
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
            return "游戏结束待结算"
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

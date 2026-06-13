import Combine
import Foundation

struct GameBoardCardViewData: Identifiable, Equatable {
    var id: CardID { cardId }
    let cardId: CardID
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isDisabledByUI: Bool
}

enum HandCardHighlightStyle: Equatable {
    case selected
    case playable
    case unavailable
}

enum FishCardFaceKind: Equatable {
    case empty
    case forageFish
    case fishCard
    case placeholder
}

struct FishCardFaceIconViewState: Equatable {
    let assetName: String
    let fallbackText: String
    let accessibilityText: String
}

enum FishCardAbilitySegment: Equatable {
    case text(String)
    case icon(FishCardFaceIconViewState)

    var isIcon: Bool {
        if case .icon = self {
            return true
        }
        return false
    }
}

enum FishCardAbilityPanelStyle: String, Equatable {
    case none
    case tanBrush
    case yellowBrush
}

enum FishCardAbilityTokenParser {
    static let supportedTokenNames: Set<String> = [
        "AllPlayers",
        "AnyCoral",
        "ArrowDown",
        "Bioluminescent",
        "BlueCoral",
        "Camouflage",
        "Card",
        "ConsumeFish",
        "ConsumeFish1",
        "ConsumeFish2",
        "ConsumeFish3",
        "Discard",
        "DrawCard",
        "Electric",
        "Estuary",
        "FishEgg",
        "FishFromHand",
        "FishFromHandConsume",
        "FishHatch",
        "FishLengthLarge",
        "FishLengthMedium",
        "FishLengthSmall",
        "FlipperBlue",
        "FlipperGreen",
        "FlipperPurple",
        "FreePlayFishFromHand",
        "GreenCoral",
        "PlayFishBottomRow",
        "Predator",
        "PurpleCoral",
        "School",
        "SchoolFeederMove",
        "SchoolFish",
        "Sun",
        "UnSchoolFish",
        "Venomous",
        "Wave",
        "YoungFish"
    ]

    static func parse(_ text: String) -> [FishCardAbilitySegment] {
        guard !text.isEmpty else {
            return []
        }

        var segments: [FishCardAbilitySegment] = []
        var currentIndex = text.startIndex

        while let open = nextTokenStart(in: text, from: currentIndex),
              let close = matchingTokenEnd(in: text, from: open) {
            appendText(String(text[currentIndex..<open]), to: &segments)

            let token = String(text[text.index(after: open)..<close])
            if let icon = icon(for: token) {
                segments.append(.icon(icon))
            } else {
                segments.append(.icon(unknownIcon(for: token)))
            }
            currentIndex = text.index(after: close)
        }

        appendText(String(text[currentIndex...]), to: &segments)
        return segments
    }

    private static func nextTokenStart(in text: String, from index: String.Index) -> String.Index? {
        text[index...].firstIndex { $0 == "[" || $0 == "{" }
    }

    private static func matchingTokenEnd(in text: String, from open: String.Index) -> String.Index? {
        let closeCharacter: Character = text[open] == "[" ? "]" : "}"
        return text[open...].firstIndex(of: closeCharacter)
    }

    private static func appendText(_ text: String, to segments: inout [FishCardAbilitySegment]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        segments.append(.text(trimmed))
    }

    private static func icon(for token: String) -> FishCardFaceIconViewState? {
        switch token {
        case "AllPlayers":
            return FishCardFaceIconViewState(assetName: "AllPlayers", fallbackText: "全员", accessibilityText: "所有玩家")
        case "AnyCoral":
            return FishCardFaceIconViewState(assetName: "AnyCoral", fallbackText: "任意珊瑚", accessibilityText: "任意珊瑚")
        case "ArrowDown":
            return FishCardFaceIconViewState(assetName: "ArrowDown", fallbackText: "向下", accessibilityText: "向下")
        case "Bioluminescent":
            return FishCardFaceIconViewState(assetName: "Bioluminescent", fallbackText: "光", accessibilityText: "生物发光")
        case "BlueCoral":
            return FishCardFaceIconViewState(assetName: "BlueCoral", fallbackText: "蓝珊瑚", accessibilityText: "蓝色珊瑚")
        case "Camouflage":
            return FishCardFaceIconViewState(assetName: "Camouflage", fallbackText: "隐", accessibilityText: "伪装")
        case "ConsumeFish", "ConsumeFish1":
            return FishCardFaceIconViewState(assetName: "ConsumeFish1", fallbackText: "吞", accessibilityText: "覆盖鱼")
        case "ConsumeFish2":
            return FishCardFaceIconViewState(assetName: "ConsumeFish2", fallbackText: "吞2", accessibilityText: "覆盖两条鱼")
        case "ConsumeFish3":
            return FishCardFaceIconViewState(assetName: "ConsumeFish3", fallbackText: "吞3", accessibilityText: "覆盖三条鱼")
        case "Discard":
            return FishCardFaceIconViewState(assetName: "Discard", fallbackText: "弃", accessibilityText: "弃牌")
        case "DrawCard":
            return FishCardFaceIconViewState(assetName: "DrawCard", fallbackText: "抽牌", accessibilityText: "抽牌")
        case "Electric":
            return FishCardFaceIconViewState(assetName: "Electric", fallbackText: "电", accessibilityText: "放电")
        case "Estuary":
            return FishCardFaceIconViewState(assetName: "Estuary", fallbackText: "河口", accessibilityText: "河口")
        case "FishEgg":
            return FishCardFaceIconViewState(assetName: "FishEgg", fallbackText: "卵", accessibilityText: "鱼卵")
        case "FishFromHand", "Card":
            return FishCardFaceIconViewState(assetName: "FishFromHand", fallbackText: "手牌", accessibilityText: "从手牌打出鱼")
        case "FishFromHandConsume":
            return FishCardFaceIconViewState(assetName: "FishFromHandConsume", fallbackText: "吞手牌", accessibilityText: "从手牌覆盖鱼")
        case "FishHatch":
            return FishCardFaceIconViewState(assetName: "FishHatch", fallbackText: "孵", accessibilityText: "孵化")
        case "FishLengthLarge":
            return FishCardFaceIconViewState(assetName: "FishLengthLarge", fallbackText: "大", accessibilityText: "大型鱼")
        case "FishLengthMedium":
            return FishCardFaceIconViewState(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼")
        case "FishLengthSmall":
            return FishCardFaceIconViewState(assetName: "FishLengthSmall", fallbackText: "小", accessibilityText: "小型鱼")
        case "FlipperBlue":
            return FishCardFaceIconViewState(assetName: "FlipperBlue", fallbackText: "蓝", accessibilityText: "蓝色潜水点")
        case "FlipperGreen":
            return FishCardFaceIconViewState(assetName: "FlipperGreen", fallbackText: "绿", accessibilityText: "绿色潜水点")
        case "FlipperPurple":
            return FishCardFaceIconViewState(assetName: "FlipperPurple", fallbackText: "紫", accessibilityText: "紫色潜水点")
        case "FreePlayFishFromHand":
            return FishCardFaceIconViewState(assetName: "FreePlayFishFromHand", fallbackText: "免费出鱼", accessibilityText: "免费从手牌打出鱼")
        case "GreenCoral":
            return FishCardFaceIconViewState(assetName: "GreenCoral", fallbackText: "绿珊瑚", accessibilityText: "绿色珊瑚")
        case "PlayFishBottomRow":
            return FishCardFaceIconViewState(assetName: "PlayFishBottomRow", fallbackText: "底行出鱼", accessibilityText: "底行出鱼")
        case "Predator":
            return FishCardFaceIconViewState(assetName: "Predator", fallbackText: "捕", accessibilityText: "捕食者")
        case "PurpleCoral":
            return FishCardFaceIconViewState(assetName: "PurpleCoral", fallbackText: "紫珊瑚", accessibilityText: "紫色珊瑚")
        case "School", "SchoolFish":
            return FishCardFaceIconViewState(assetName: "SchoolFish", fallbackText: "群", accessibilityText: "鱼群")
        case "SchoolFeederMove":
            return FishCardFaceIconViewState(assetName: "SchoolFeederMove", fallbackText: "移群", accessibilityText: "移动鱼群")
        case "Sun":
            return FishCardFaceIconViewState(assetName: "Sun", fallbackText: "阳", accessibilityText: "阳光层")
        case "UnSchoolFish":
            return FishCardFaceIconViewState(assetName: "UnSchoolFish", fallbackText: "散群", accessibilityText: "移除鱼群")
        case "Venomous":
            return FishCardFaceIconViewState(assetName: "Venomous", fallbackText: "毒", accessibilityText: "有毒")
        case "Wave":
            return FishCardFaceIconViewState(assetName: "Wave", fallbackText: "分", accessibilityText: "分数")
        case "YoungFish":
            return FishCardFaceIconViewState(assetName: "YoungFish", fallbackText: "幼", accessibilityText: "幼鱼")
        default:
            return nil
        }
    }

    private static func unknownIcon(for token: String) -> FishCardFaceIconViewState {
        FishCardFaceIconViewState(
            assetName: "UnknownToken",
            fallbackText: "?",
            accessibilityText: "未知图标 \(token)"
        )
    }
}

struct FishCardFaceViewState: Equatable {
    let kind: FishCardFaceKind
    let cardId: CardID?
    let displayName: String
    let scientificName: String?
    let printedPointsText: String
    let lengthText: String
    let costText: String
    let allowedZonesText: String
    let requiredDiveSiteColor: DiveSiteColor?
    let requiredDiveSiteText: String
    let tagsText: String
    let abilityTriggerText: String?
    let abilityText: String
    let costIcons: [FishCardFaceIconViewState]
    let zoneIcons: [FishCardFaceIconViewState]
    let tagIcons: [FishCardFaceIconViewState]
    let sizeClassIcon: FishCardFaceIconViewState
    let abilitySegments: [FishCardAbilitySegment]
    let backgroundAssetPrefix: String
    let abilityStripAssetPrefix: String?
    let abilityPanelStyle: FishCardAbilityPanelStyle
    let localFishImagePrefix: String?
    let aspectRatio: Double
    let isPlaceholder: Bool
}

struct GameHudControlViewState: Equatable {
    let settingsButtonText: String
    let logButtonText: String
    let canShowLog: Bool
    let placement: GameHudControlPlacement
}

enum GameHudControlPlacement: String, Equatable {
    case topLeft
}

struct HandCardViewState: Identifiable, Equatable {
    var id: CardID { cardId }

    static let fixedCardWidth: Double = CardRenderMetrics.handCardWidth
    static let fixedCardHeight: Double = CardRenderMetrics.handCardHeight
    static let fixedScale: Double = 1

    let cardId: CardID
    let displayName: String
    let shortName: String
    let printedPoints: Int
    let lengthText: String
    let costSummaryText: String
    let placementSummaryText: String
    let requiredDiveSiteText: String
    let abilitySummaryText: String
    let cardFace: FishCardFaceViewState
    let isSelected: Bool
    let isMainSelectedCard: Bool
    let isPlayable: Bool
    let isDiscardPaymentSelectable: Bool
    let isSelectedForDiscardPayment: Bool
    let unavailableReasonText: String?
    let highlightStyle: HandCardHighlightStyle
    let compactDisplayText: String
    let overlayMarkerText: String?
    let stackIndex: Int
    let isPulledOutFromStack: Bool
    let stackOffsetX: Double
    let stackOffsetY: Double
    let stackZIndex: Double
    let visibleHeightRatio: Double
    let cardWidth: Double
    let cardHeight: Double
    let scale: Double
}

struct HandViewState: Equatable {
    let cards: [HandCardViewState]
    let selectedCard: HandCardViewState?
    let isStackedPresentation: Bool
    let pulledOutCardId: CardID?
    let canSelectCards: Bool
    let canSelectMainCard: Bool
    let canSelectDiscardPayment: Bool
    let blockingMessage: String?
}

struct GameTopBarViewState: Equatable {
    let weekText: String
    let activePlayerText: String
    let diverText: String
    let resourceSummaryText: String
    let playerCountText: String
    let canShowLog: Bool
    let logButtonText: String
}

struct GameHudViewState: Equatable {
    let leftControls: GameHudControlViewState
    let playerHud: TopPlayerHudViewState
    let weeklyGoalHud: WeeklyGoalHudViewState
    let canShowLog: Bool
    let logButtonText: String
    let settingsButtonText: String
}

struct GameBoardSettingsMenuViewState: Equatable {
    let title: String
    let temporarilyExitGameAndReturnHomeText: String
    let dissolveCurrentGameAndReturnHomeText: String
    let dissolveConfirmationTitle: String
    let dissolveConfirmationMessage: String
    let cancelText: String
}

struct GameBoardToastViewState: Identifiable, Equatable {
    let id: EventID
    let text: String
}

struct TopPlayerHudViewState: Equatable {
    let players: [PlayerAvatarViewState]
    let activePlayerId: PlayerID?
    let lastActionSummaryText: String?
    let playerCountText: String
    let selectedViewedPlayerId: PlayerID?
    let opponentBoardPreviewMessage: String?
}

struct PlayerAvatarViewState: Identifiable, Equatable {
    var id: PlayerID { playerId }

    let playerId: PlayerID
    let displayName: String
    let colorName: String?
    let avatarText: String
    let isActive: Bool
    let isSelectedForPreview: Bool
}

struct SidePlayerInfoViewState: Equatable {
    let playerName: String
    let avatarText: String
    let diverSummaryText: String
    let eggCount: Int
    let youngCount: Int
    let schoolCount: Int
}

enum RightActionPanelActionKind: String, Equatable {
    case none
    case playFishPayment
    case pendingChoice
    case rewardSelection
    case moveResource
    case unsupported
}

struct RightActionPanelViewState: Equatable {
    let title: String
    let summaryLines: [String]
    let primaryButtonTitle: String?
    let isPrimaryButtonEnabled: Bool
    let secondaryButtonTitle: String?
    let isSecondaryButtonVisible: Bool
    let warningText: String?
    let actionKind: RightActionPanelActionKind
    let pendingChoiceId: PendingChoiceID?
    let primaryPendingChoiceAction: PendingChoiceAction?
}

enum RightSidePanelPresentation: String, Equatable {
    case compact
    case expanded
}

struct RightSidePanelViewState: Equatable {
    let presentation: RightSidePanelPresentation
    let compactTitle: String
    let compactSubtitle: String
}

struct GameEndAbilityPhaseViewState: Equatable {
    let title: String
    let summaryText: String
    let emptyText: String
    let finishButtonTitle: String
    let canFinish: Bool
    let abilityRows: [GameEndAbilityRowViewState]
}

struct GameEndAbilityRowViewState: Identifiable, Equatable {
    var id: String { source.id }

    let source: GameEndAbilitySource
    let fishName: String
    let abilitySummary: String
    let statusText: String
    let isActivated: Bool
    let isSupported: Bool
    let canActivate: Bool
}

struct WeeklyGoalHudViewState: Equatable {
    let boxes: [WeeklyGoalBoxViewState]
    let selectedDetailWeek: Int?
    let isDetailPresented: Bool
}

struct WeeklyGoalBoxViewState: Identifiable, Equatable {
    var id: Int { index }

    let index: Int
    let title: String
    let iconText: String
    let shortDescription: String
    let isCurrent: Bool
    let isGameEndBox: Bool
}

struct WeeklyGoalDetailViewState: Equatable {
    let title: String
    let weeklyScoreItems: [WeeklyGoalDetailItemViewState]
    let gameEndInfo: GameEndInfoViewState
    let noteText: String
}

struct WeeklyGoalDetailItemViewState: Identifiable, Equatable {
    var id: Int { index }

    let index: Int
    let title: String
    let iconText: String
    let description: String
    let scoringText: String
    let playerScores: [WeeklyGoalPlayerScoreViewState]
    let isCurrent: Bool
}

struct WeeklyGoalPlayerScoreViewState: Identifiable, Equatable {
    var id: PlayerID { playerId }

    let playerId: PlayerID
    let playerName: String
    let scoreText: String
}

struct GameEndInfoViewState: Equatable {
    let title: String
    let description: String
    let noteText: String
}

struct DiscardPaymentProgressViewState: Identifiable, Equatable {
    var id: String { "discard" }

    let selectedCount: Int
    let requiredCount: Int
    let progressText: String
    let isComplete: Bool
}

struct PlayFishPaymentViewState: Equatable {
    let cardTitle: String
    let targetText: String
    let isTargetSelected: Bool
    let discardProgress: DiscardPaymentProgressViewState?
    let resourceProgress: [ResourcePaymentProgressViewState]
    let canConfirm: Bool
    let blockingMessage: String?
}

struct DiscardPileViewState: Equatable {
    let playerId: PlayerID?
    let title: String
    let countText: String
    let badgeText: String
    let usesCardStackPreview: Bool
    let usesOverlayBadge: Bool
    let count: Int
    let topCards: [FishCardFaceViewState]
    let isEmpty: Bool
    let isDetailPresented: Bool
    let emptyText: String
}

struct DiscardPileDetailViewState: Equatable {
    let title: String
    let countText: String
    let cards: [FishCardFaceViewState]
    let emptyText: String
    let maxCardsPerRow: Int
    let presentationStyle: DiscardPileDetailPresentationStyle
    let isReadOnly: Bool
}

enum DiscardPileDetailPresentationStyle: String, Equatable {
    case fullScreenOverlay
}

struct OceanSlotViewData: Identifiable, Equatable {
    var id: String {
        "\(address.playerId)-\(address.diveSite.rawValue)-\(address.rowIndex)"
    }

    let address: OceanSlotAddress
    let title: String
    let subtitle: String
    let resourcesText: String
    let cardFace: FishCardFaceViewState
    let isOccupied: Bool
    let isSelected: Bool
    let isHighlightedByDiveQueue: Bool
    let highlightReasonText: String?
    let playFishPreview: PlayFishSlotPreview
    let resourceTokens: [SlotResourceTokenViewState]
    let aspectRatio: Double
    let isDropTarget: Bool
    let isValidDropTarget: Bool
    let dropTargetReasonText: String?
    let isHighlightedByRewardSelection: Bool
    let rewardSelectionReasonText: String?
}

struct SlotResourceTokenViewState: Identifiable, Equatable {
    var id: String { "\(kind.rawValue)-\(tokenIndex)" }

    let address: OceanSlotAddress
    let kind: ResourceKind
    let tokenIndex: Int
    let title: String
    let iconText: String
    let isSelectable: Bool
    let isSelectedForPayment: Bool
    let selectionMarkerText: String?
    let unavailableReasonText: String?
    let warningText: String?
}

struct OceanDiveSiteColumnViewData: Identifiable, Equatable {
    var id: String { diveSite.rawValue }

    let diveSite: DiveSite
    let title: String
    let coralReef: CoralReefViewState?
    let slots: [OceanSlotViewData]
    let zoneSections: [OceanZoneSectionViewData]
}

struct CoralReefViewState: Identifiable, Equatable {
    var id: String { diveSite.rawValue }

    let diveSite: DiveSite
    let iconAssetName: String
    let coralCount: Int
    let maxCoral: Int
    let completionBonus: Int
    let isEnabled: Bool
    let title: String
    let progressText: String
    let completionBonusText: String
}

struct OceanZoneSectionViewData: Identifiable, Equatable {
    var id: String { "\(diveSite.rawValue)-\(zone.rawValue)" }

    let diveSite: DiveSite
    let zone: OceanZone
    let title: String
    let slots: [OceanSlotViewData]
    let isHighlightedByDiveQueue: Bool
}

struct DiveSiteBottomAreaViewState: Identifiable, Equatable {
    var id: String { diveSite.rawValue }

    let diveSite: DiveActionSite
    let diveSiteTitle: String
    let bonusTitle: String
    let bonusKind: DiveBonusKind
    let bonusDetailText: String?
    let isFirstBottomThisWeekAvailable: Bool
    let isAlreadyReachedThisWeek: Bool
    let statusText: String
    let isHighlightedByDiveQueue: Bool
    let highlightReasonText: String?
}

struct SelectedFishCardViewData: Equatable {
    let title: String
    let scoreText: String
    let lengthText: String
    let allowedZonesText: String
    let requiredDiveSiteText: String
    let costsText: String
    let unsupportedText: String?
}

struct PlayFishSlotPreview: Equatable {
    let availability: PlayFishSlotAvailability
    let unavailableReason: PlayFishSlotUnavailableReason?
    let message: String

    var isSelectable: Bool {
        availability == .available
    }
}

enum PlayFishSlotAvailability: Equatable {
    case available
    case unavailable
}

enum PlayFishSlotUnavailableReason: Equatable {
    case noSelectedCard
    case occupied
    case mustCoverShorterFish
    case coverLengthTooShort
    case zoneMismatch
    case diveSiteMismatch
    case reefFishMustBeSunlit
    case coralReefMissing
    case coralInsufficient
    case unsupportedRequirement
}

struct ResourceSourceViewData: Identifiable, Equatable {
    var id: String {
        "\(address.playerId)-\(address.diveSite.rawValue)-\(address.rowIndex)-\(resourceKind.rawValue)"
    }

    let address: OceanSlotAddress
    let resourceKind: ResourceKind
    let title: String
    let availableCount: Int
    let selectedCount: Int
}

struct ResourcePaymentProgressViewState: Identifiable, Equatable {
    var id: String { kind.rawValue }

    let kind: ResourceKind
    let title: String
    let selectedCount: Int
    let requiredCount: Int
    let progressText: String
    let isComplete: Bool
}

private struct ResourcePaymentTokenKey: Hashable {
    let address: OceanSlotAddress
    let kind: ResourceKind
    let tokenIndex: Int
}

struct DiveActionSiteViewData: Identifiable, Equatable {
    var id: String { diveSite.rawValue }

    let diveSite: DiveActionSite
    let title: String
}

struct DiveActionButtonViewState: Identifiable, Equatable {
    var id: String { diveSite.rawValue }

    let diveSite: DiveActionSite
    let title: String
    let isEnabled: Bool
    let disabledReasonText: String?
}

struct DiveActionBarViewState: Equatable {
    let title: String
    let buttons: [DiveActionButtonViewState]
}

struct PendingChoiceViewData: Identifiable, Equatable {
    var id: PendingChoiceID { choiceId }

    let choiceId: PendingChoiceID
    let title: String
    let subtitle: String
    let sourceText: String
    let statusText: String
    let progressLines: [String]
    let targetPrompt: String?
    let noTargetsText: String?
    let targets: [PendingChoiceTargetViewData]
    let cardTargets: [PendingChoiceCardTargetViewData]
    let moveTargets: [PendingChoiceMoveTargetViewData]
    let canSkip: Bool
    let canResolve: Bool
    let actions: [PendingChoiceActionViewData]
}

struct PendingChoiceCardTargetViewData: Identifiable, Equatable {
    var id: String { "\(choiceId)-\(cardId)" }

    let choiceId: PendingChoiceID
    let cardId: CardID
    let title: String
    let subtitle: String
    let isEnabled: Bool
}

struct PendingChoiceMoveTargetViewData: Identifiable, Equatable {
    var id: String {
        "\(choiceId)-\(kind.rawValue)-\(source.diveSite.rawValue)-\(source.rowIndex)-\(target.diveSite.rawValue)-\(target.rowIndex)"
    }

    let choiceId: PendingChoiceID
    let source: OceanSlotAddress
    let target: OceanSlotAddress
    let kind: ResourceKind
    let title: String
    let subtitle: String
    let isEnabled: Bool
}

struct PendingChoiceTargetViewData: Identifiable, Equatable {
    var id: String {
        "\(choiceId)-\(address.playerId)-\(address.diveSite.rawValue)-\(address.rowIndex)"
    }

    let choiceId: PendingChoiceID
    let address: OceanSlotAddress
    let title: String
    let subtitle: String
    let resourcesText: String
    let isEnabled: Bool
}

struct PendingChoiceActionViewData: Identifiable, Equatable {
    var id: String { "\(choiceId)-\(effectNodeId ?? action.rawValue)" }

    let choiceId: PendingChoiceID
    let action: PendingChoiceAction
    let title: String
    let isEnabled: Bool
    var effectNodeId: EffectNodeId? = nil
}

struct WeeklyAchievementResultViewData: Identifiable, Equatable {
    var id: String {
        "\(week)-\(playerId)-\(kind.rawValue)"
    }

    let week: Int
    let playerId: PlayerID
    let kind: AchievementKind
    let title: String
    let subtitle: String
}

enum ScoreBarCategory: String, Codable, Equatable, Sendable {
    case weeklyAchievements
    case fishPrintedPoints
    case gameEndAbilityPoints
    case eggsAndYoung
    case schools
    case consumedFish
    case coral
    case completeReefBonus
}

enum ScoreBarColorStyle: String, Codable, Equatable, Sendable {
    case weeklyAchievements
    case fishPrintedPoints
    case gameEndAbilityPoints
    case eggsAndYoung
    case schools
    case consumedFish
    case coral
    case completeReefBonus
}

struct ScoreBarSegmentViewState: Identifiable, Codable, Equatable, Sendable {
    var id: String { category.rawValue }

    let category: ScoreBarCategory
    let title: String
    let points: Int
    let widthRatioRelativeToMaxTotal: Double
    let displayColorKey: ScoreBarColorStyle
}

struct ScoreLegendItemViewState: Identifiable, Codable, Equatable, Sendable {
    var id: String { displayColorKey.rawValue }

    let title: String
    let displayColorKey: ScoreBarColorStyle
}

struct FinalScorePlayerRowViewState: Identifiable, Codable, Equatable, Sendable {
    var id: PlayerID { playerId }

    let playerId: PlayerID
    let playerDisplayName: String
    let playerColorText: String
    let avatarText: String
    let totalPoints: Int
    let totalText: String
    let totalWidthRatioRelativeToMaxTotal: Double
    let isWinner: Bool
    let segments: [ScoreBarSegmentViewState]
}

struct FinalScoreViewState: Codable, Equatable, Sendable {
    let title: String
    let winnerText: String
    let maxTotalPoints: Int
    let playerRows: [FinalScorePlayerRowViewState]
    let legendItems: [ScoreLegendItemViewState]
}

struct RewardPoolViewState: Equatable {
    let isActive: Bool
    let titleText: String
    let sourceText: String?
    let rewards: [RewardTokenViewState]
    let blockingMessage: String?
    let selectedRewardTokenId: String?
    let instructionText: String
}

struct RewardTokenViewState: Identifiable, Equatable {
    let id: String
    let kind: RewardTokenKind
    let title: String
    let subtitle: String
    let iconText: String
    let symbolName: String?
    let countText: String?
    let isSelectable: Bool
    let isSelected: Bool
    let isCompleted: Bool
    let isUnsupported: Bool
    let unavailableReasonText: String?
}

enum RewardTokenKind: String, Equatable {
    case drawFish
    case recoverFromDiscardOrDraw
    case placeEgg
    case placeYoung
    case hatchEgg
    case moveYoung
    case moveSchool
    case moveYoungOrSchool
    case compoundPlaceEgg
    case compoundHatchEgg
    case skipOrEnd
    case gainCoral
    case scatterSchool
    case consumeFish
    case playFishForFree
    case playFishFromHand
    case unsupported
}

private enum RewardTokenAction: Equatable {
    case direct(choiceId: PendingChoiceID, resolution: PendingChoiceResolution)
    case chooseTarget(choiceId: PendingChoiceID, kind: PendingChoiceKind)
    case chooseMoveSource(choiceId: PendingChoiceID)
    case chooseCoralResource(choiceId: PendingChoiceID, tokenId: String, kind: ResourceKind)
    case chooseCoralHandCard(choiceId: PendingChoiceID, tokenId: String)
    case chooseScatterSchoolSource(choiceId: PendingChoiceID, tokenId: String)
    case chooseScatterSchoolYoungTarget(choiceId: PendingChoiceID, tokenId: String)
    case chooseConsumeFishConsumer(choiceId: PendingChoiceID, tokenId: String)
    case chooseConsumeFishHandCard(choiceId: PendingChoiceID, tokenId: String)
    case chooseFreePlayHandCard(choiceId: PendingChoiceID, tokenId: String)
    case chooseFreePlayTarget(choiceId: PendingChoiceID, tokenId: String, cardId: CardID)
    case choosePlayFishFromHandCard(choiceId: PendingChoiceID, tokenId: String)
    case choosePlayFishFromHandTarget(choiceId: PendingChoiceID, tokenId: String, cardId: CardID)
    case choosePlayFishFromHandPayment(choiceId: PendingChoiceID, tokenId: String, cardId: CardID, targetSlot: OceanSlotAddress)
    case unsupported
}

private enum RewardSelectionMode: Equatable {
    case target(choiceId: PendingChoiceID, tokenId: String, kind: PendingChoiceKind)
    case moveSource(choiceId: PendingChoiceID, tokenId: String)
    case moveTarget(choiceId: PendingChoiceID, tokenId: String, source: OceanSlotAddress, kind: ResourceKind)
    case coralResource(choiceId: PendingChoiceID, tokenId: String, kind: ResourceKind)
    case coralHandCard(choiceId: PendingChoiceID, tokenId: String)
    case scatterSchoolSource(choiceId: PendingChoiceID, tokenId: String)
    case scatterSchoolYoungTarget(choiceId: PendingChoiceID, tokenId: String)
    case consumeFishConsumer(choiceId: PendingChoiceID, tokenId: String)
    case consumeFishHandCard(choiceId: PendingChoiceID, tokenId: String)
    case freePlayHandCard(choiceId: PendingChoiceID, tokenId: String)
    case freePlayTarget(choiceId: PendingChoiceID, tokenId: String, cardId: CardID)
    case playFishFromHandCard(choiceId: PendingChoiceID, tokenId: String)
    case playFishFromHandTarget(choiceId: PendingChoiceID, tokenId: String, cardId: CardID)
    case playFishFromHandPayment(choiceId: PendingChoiceID, tokenId: String, cardId: CardID, targetSlot: OceanSlotAddress)
}

enum PendingChoiceAction: String, Equatable {
    case drawFish
    case drawFromDeck
    case chooseTarget
    case chooseDrawAbilityEffect
    case chooseRecoverAbilityEffect
    case choosePlaceEggAbilityEffect
    case choosePlaceYoungAbilityEffect
    case chooseHatchEggAbilityEffect
    case finishAbility
    case skip
}

private struct PendingEffectActionChoice: Equatable {
    var effectNodeId: EffectNodeId
    var action: PendingChoiceAction
    var title: String
}

@MainActor
final class GameBoardViewModel: ObservableObject {
    @Published private(set) var state: GameState = .empty
    @Published private(set) var players: [RoomPlayer] = []
    @Published private(set) var eventLog: [GameEvent] = []
    @Published private(set) var errorMessage: String?
    @Published var selectedCardId: CardID?
    @Published var selectedTargetSlot: OceanSlotAddress?
    @Published var selectedDiscardCardIds: Set<CardID> = []
    @Published var selectedEggSources: [OceanSlotAddress] = []
    @Published var selectedYoungSources: [OceanSlotAddress] = []
    @Published private var selectedResourcePaymentTokens: Set<ResourcePaymentTokenKey> = []
    @Published private(set) var draggingHandCardId: CardID?
    @Published private(set) var dragHoverSlotAddress: OceanSlotAddress?
    @Published private(set) var selectedRewardTokenId: String?
    @Published private var rewardSelectionMode: RewardSelectionMode?
    @Published private(set) var selectedViewedPlayerId: PlayerID?
    @Published private(set) var selectedWeeklyGoalDetailWeek: Int?
    @Published private(set) var isEventLogPresented = false
    @Published private(set) var isDiscardPileDetailPresented = false
    @Published private(set) var hudToastViewState: GameBoardToastViewState?

    private let roomService: any RoomService
    private let cardCatalogProvider: () -> any CardCatalog
    private let abilityResolver: AbilityResolver
    private var commandCounter = 0
    private var hudToastDismissWorkItem: DispatchWorkItem?
    private var lastShownHudToastSequence: EventID?
    private var didShowInitialHudToast = false
    private var cardCatalog: any CardCatalog {
        cardCatalogProvider()
    }
    private var cardIdentityResolver: CardIdentityResolver {
        cardCatalog.identityResolver()
    }
    private var cardsById: [CardID: Card] {
        cardIdentityResolver.cardsByLookupId
    }

    var currentWeekText: String {
        state.currentWeek > 0 ? "\(state.currentWeek)" : "-"
    }

    var currentTurnText: String {
        state.phase == .playing ? "\(state.turnsCompletedThisWeek + 1) / 6" : "-"
    }

    var activePlayerName: String {
        guard let activePlayerId = state.activePlayerId else {
            return "-"
        }
        return players.first(where: { $0.playerId == activePlayerId })?.displayName ?? activePlayerId
    }

    var topBarViewState: GameTopBarViewState {
        let totals = activePlayerResourceTotals
        return GameTopBarViewState(
            weekText: AppStrings.GameBoard.topBarWeekText(state.currentWeek),
            activePlayerText: AppStrings.GameBoard.topBarActivePlayerText(
                name: activePlayerName,
                colorName: activePlayerColorName
            ),
            diverText: AppStrings.GameBoard.topBarDiverText(
                available: activePlayerState?.availableDivers ?? 0,
                total: 6
            ),
            resourceSummaryText: AppStrings.GameBoard.topBarResourceSummaryText(
                eggs: totals.eggs,
                young: totals.young,
                schools: totals.schools
            ),
            playerCountText: AppStrings.GameBoard.topBarPlayerCountText(players.count),
            canShowLog: true,
            logButtonText: AppStrings.GameBoard.logButton
        )
    }

    var gameHudViewState: GameHudViewState {
        GameHudViewState(
            leftControls: GameHudControlViewState(
                settingsButtonText: AppStrings.GameBoard.settings,
                logButtonText: AppStrings.GameBoard.logButton,
                canShowLog: true,
                placement: .topLeft
            ),
            playerHud: topPlayerHudViewState,
            weeklyGoalHud: weeklyGoalHudViewState,
            canShowLog: true,
            logButtonText: AppStrings.GameBoard.logButton,
            settingsButtonText: AppStrings.GameBoard.settings
        )
    }

    var settingsMenuViewState: GameBoardSettingsMenuViewState {
        GameBoardSettingsMenuViewState(
            title: AppStrings.GameBoard.settings,
            temporarilyExitGameAndReturnHomeText: AppStrings.GameBoard.temporarilyExitGameAndReturnHome,
            dissolveCurrentGameAndReturnHomeText: AppStrings.GameBoard.dissolveCurrentGameAndReturnHome,
            dissolveConfirmationTitle: AppStrings.GameBoard.dissolveCurrentGameConfirmTitle,
            dissolveConfirmationMessage: AppStrings.GameBoard.dissolveCurrentGameConfirmMessage,
            cancelText: AppStrings.GameBoard.cancel
        )
    }

    var topPlayerHudViewState: TopPlayerHudViewState {
        TopPlayerHudViewState(
            players: players.map(playerAvatarViewState),
            activePlayerId: state.activePlayerId,
            lastActionSummaryText: lastActionSummaryText,
            playerCountText: AppStrings.GameBoard.topBarPlayerCountText(players.count),
            selectedViewedPlayerId: selectedViewedPlayerId,
            opponentBoardPreviewMessage: opponentBoardPreviewMessage
        )
    }

    var weeklyGoalHudViewState: WeeklyGoalHudViewState {
        WeeklyGoalHudViewState(
            boxes: (1...4).map(weeklyGoalBoxViewState),
            selectedDetailWeek: selectedWeeklyGoalDetailWeek,
            isDetailPresented: selectedWeeklyGoalDetailWeek != nil
        )
    }

    var weeklyGoalDetailViewState: WeeklyGoalDetailViewState? {
        guard selectedWeeklyGoalDetailWeek != nil else {
            return nil
        }
        return WeeklyGoalDetailViewState(
            title: AppStrings.GameBoard.weeklyGoalDetailTitle,
            weeklyScoreItems: (1...3).map(weeklyGoalDetailItem),
            gameEndInfo: GameEndInfoViewState(
                title: AppStrings.GameBoard.gameEndGoalTitle,
                description: AppStrings.GameBoard.gameEndGoalDescription,
                noteText: AppStrings.GameBoard.gameEndGoalNote
            ),
            noteText: AppStrings.GameBoard.finalScoreHiddenHint
        )
    }

    var sidePlayerInfoViewState: SidePlayerInfoViewState {
        let totals = activePlayerResourceTotals
        return SidePlayerInfoViewState(
            playerName: activePlayerName,
            avatarText: avatarText(for: state.activePlayerId),
            diverSummaryText: AppStrings.GameBoard.topBarDiverText(
                available: activePlayerState?.availableDivers ?? 0,
                total: 6
            ),
            eggCount: totals.eggs,
            youngCount: totals.young,
            schoolCount: totals.schools
        )
    }

    var rightActionPanelViewState: RightActionPanelViewState {
        if let payment = paymentProgressViewState {
            return RightActionPanelViewState(
                title: AppStrings.GameBoard.playFishPayment,
                summaryLines: playFishActionSummaryLines(payment),
                primaryButtonTitle: AppStrings.GameBoard.confirmPlayFish,
                isPrimaryButtonEnabled: payment.canConfirm,
                secondaryButtonTitle: AppStrings.GameBoard.cancelPlayFish,
                isSecondaryButtonVisible: true,
                warningText: payment.blockingMessage,
                actionKind: .playFishPayment,
                pendingChoiceId: nil,
                primaryPendingChoiceAction: nil
            )
        }

        if let choice = pendingChoices.first {
            let action = choice.actions.first { $0.action == .skip && $0.isEnabled }
                ?? choice.actions.first { $0.isEnabled }
            return RightActionPanelViewState(
                title: AppStrings.GameBoard.pendingChoicePanel,
                summaryLines: pendingChoiceActionSummaryLines(choice),
                primaryButtonTitle: action?.title,
                isPrimaryButtonEnabled: action?.isEnabled ?? false,
                secondaryButtonTitle: nil,
                isSecondaryButtonVisible: false,
                warningText: choice.canResolve ? nil : AppStrings.GameBoard.resolveCurrentRewardFirst,
                actionKind: rightActionKind(for: choice),
                pendingChoiceId: choice.choiceId,
                primaryPendingChoiceAction: action?.action
            )
        }

        if state.phase == .endGamePending {
            return RightActionPanelViewState(
                title: AppStrings.GameBoard.gameEndAbilityPhaseTitle,
                summaryLines: [AppStrings.GameBoard.gameEndAbilityPhaseSummary],
                primaryButtonTitle: AppStrings.GameBoard.finishGameEndAbilities,
                isPrimaryButtonEnabled: state.pendingChoices.isEmpty,
                secondaryButtonTitle: nil,
                isSecondaryButtonVisible: false,
                warningText: nil,
                actionKind: .unsupported,
                pendingChoiceId: nil,
                primaryPendingChoiceAction: nil
            )
        }

        return RightActionPanelViewState(
            title: AppStrings.GameBoard.currentAction,
            summaryLines: [AppStrings.GameBoard.chooseMainAction],
            primaryButtonTitle: nil,
            isPrimaryButtonEnabled: false,
            secondaryButtonTitle: nil,
            isSecondaryButtonVisible: false,
            warningText: nil,
            actionKind: .none,
            pendingChoiceId: nil,
            primaryPendingChoiceAction: nil
        )
    }

    var rightSidePanelViewState: RightSidePanelViewState {
        let rewardPool = rewardPoolViewState
        let action = rightActionPanelViewState
        let shouldExpand = rewardPool.isActive
            || !rewardPool.rewards.isEmpty
            || action.actionKind != .none
            || action.primaryButtonTitle != nil
            || action.isSecondaryButtonVisible
            || action.warningText != nil
            || gameEndAbilityPhaseViewState != nil

        return RightSidePanelViewState(
            presentation: shouldExpand ? .expanded : .compact,
            compactTitle: AppStrings.GameBoard.compactRightPanelTitle,
            compactSubtitle: AppStrings.GameBoard.compactRightPanelEmpty
        )
    }

    var lastActionSummaryText: String? {
        guard let event = eventLog.reversed().first(where: isImportantActionEvent) else {
            return AppStrings.GameBoard.gameStartedSummary
        }
        return actionSummary(for: event)
    }

    var opponentBoardPreviewMessage: String? {
        guard let selectedViewedPlayerId,
              selectedViewedPlayerId != state.activePlayerId
        else {
            return nil
        }
        return AppStrings.GameBoard.opponentBoardPreviewUnavailable
    }

    private var activePlayerColorName: String? {
        guard let activePlayerId = state.activePlayerId,
              let color = players.first(where: { $0.playerId == activePlayerId })?.color
        else {
            return nil
        }
        return AppStrings.colorName(color)
    }

    private var activePlayerResourceTotals: (eggs: Int, young: Int, schools: Int) {
        guard let activePlayerState else {
            return (0, 0, 0)
        }
        return activePlayerState.ocean.slots.reduce(into: (eggs: 0, young: 0, schools: 0)) { totals, slot in
            for resource in slot.resources {
                switch resource.kind {
                case .egg:
                    totals.eggs += resource.amount
                case .young:
                    totals.young += resource.amount
                case .school:
                    totals.schools += resource.amount
                default:
                    break
                }
            }
        }
    }

    private func playerAvatarViewState(_ player: RoomPlayer) -> PlayerAvatarViewState {
        PlayerAvatarViewState(
            playerId: player.playerId,
            displayName: player.displayName,
            colorName: player.color.map(AppStrings.colorName),
            avatarText: avatarText(for: player.playerId),
            isActive: player.playerId == state.activePlayerId,
            isSelectedForPreview: player.playerId == selectedViewedPlayerId
        )
    }

    private func avatarText(for playerId: PlayerID?) -> String {
        guard let playerId,
              let index = players.firstIndex(where: { $0.playerId == playerId })
        else {
            return "?"
        }
        return "\(index + 1)"
    }

    private func weeklyGoalBoxViewState(_ index: Int) -> WeeklyGoalBoxViewState {
        WeeklyGoalBoxViewState(
            index: index,
            title: AppStrings.GameBoard.weeklyGoalBoxTitle(index),
            iconText: weeklyGoalIconText(index),
            shortDescription: weeklyGoalDescription(index),
            isCurrent: min(max(state.currentWeek, 1), 4) == index,
            isGameEndBox: index == 4
        )
    }

    private func weeklyGoalDetailItem(_ week: Int) -> WeeklyGoalDetailItemViewState {
        WeeklyGoalDetailItemViewState(
            index: week,
            title: AppStrings.GameBoard.weeklyGoalBoxTitle(week),
            iconText: weeklyGoalIconText(week),
            description: weeklyGoalDescription(week),
            scoringText: weeklyGoalScoringText(week),
            playerScores: players.map { player in
                WeeklyGoalPlayerScoreViewState(
                    playerId: player.playerId,
                    playerName: player.displayName,
                    scoreText: weeklyGoalScoreText(week: week, playerId: player.playerId)
                )
            },
            isCurrent: state.currentWeek == week
        )
    }

    private func weeklyGoalIconText(_ index: Int) -> String {
        guard let kind = weeklyGoalDefinition(for: index)?.kind else {
            return index == 4 ? "★" : "?"
        }
        switch kind {
        case .eggsAndYoung:
            return "🥚"
        case .rowsOfFish:
            return "▦"
        case .schools:
            return "●"
        case .coralCount:
            return "◌"
        case .discardPileCards:
            return "▤"
        case .sunlitFish:
            return "☀"
        }
    }

    private func weeklyGoalDescription(_ index: Int) -> String {
        if let goal = weeklyGoalDefinition(for: index) {
            return weeklyGoalDescription(for: goal.kind)
        }
        if index == 4 {
            return AppStrings.GameBoard.gameEndGoalShortDescription
        }
        return "?"
    }

    private func weeklyGoalDescription(for kind: AchievementKind) -> String {
        switch kind {
        case .eggsAndYoung:
            return AppStrings.GameBoard.weekOneGoalDescription
        case .rowsOfFish:
            return AppStrings.GameBoard.weekTwoGoalDescription
        case .schools:
            return AppStrings.GameBoard.weekThreeGoalDescription
        case .coralCount:
            return AppStrings.GameBoard.coralCountGoalDescription
        case .discardPileCards:
            return AppStrings.GameBoard.discardPileCardsGoalDescription
        case .sunlitFish:
            return AppStrings.GameBoard.sunlitFishGoalDescription
        }
    }

    private func weeklyGoalDefinition(for week: Int) -> WeeklyGoalDefinition? {
        let goals = state.weeklyGoals ?? WeeklyGoalCatalog.sideAGoals
        return goals.first { $0.week == week }
    }

    private func weeklyGoalQuantity(week: Int, playerState: PlayerGameState) -> Int {
        guard let kind = weeklyGoalDefinition(for: week)?.kind else {
            return 0
        }
        return weeklyGoalQuantity(kind: kind, playerState: playerState)
    }

    private func weeklyGoalQuantity(kind: AchievementKind, playerState: PlayerGameState) -> Int {
        switch kind {
        case .eggsAndYoung:
            return playerState.ocean.slots.reduce(0) { total, slot in
                total
                    + (slot.resources.first(where: { $0.kind == .egg })?.amount ?? 0)
                    + (slot.resources.first(where: { $0.kind == .young })?.amount ?? 0)
            }
        case .rowsOfFish:
            return SampleOceanLayout.rowIndices.filter { rowIndex in
                DiveSite.allCases.allSatisfy { diveSite in
                    playerState.ocean.slots.contains {
                        $0.address.diveSite == diveSite
                            && $0.address.rowIndex == rowIndex
                            && $0.content.hasFish
                    }
                }
            }.count
        case .schools:
            return playerState.ocean.slots.reduce(0) { total, slot in
                total + (slot.resources.first(where: { $0.kind == .school })?.amount ?? 0)
            }
        case .coralCount:
            return playerState.ocean.coralReefs.reduce(0) { total, reef in
                total + reef.coralCount
            }
        case .discardPileCards:
            return playerState.discardPile.count
        case .sunlitFish:
            return playerState.ocean.slots.filter { slot in
                slot.address.zone == .sunlit && slot.content.hasFish
            }.count
        }
    }

    private func weeklyGoalScoringText(_ week: Int) -> String {
        if state.currentWeek <= week,
           let activePlayerState = state.playerGameStates[state.activePlayerId ?? ""] {
            return AppStrings.GameBoard.currentProjectedScoreText(
                quantity: weeklyGoalQuantity(week: week, playerState: activePlayerState)
            )
        }
        return AppStrings.GameBoard.settledScoreText
    }

    private func weeklyGoalScoreText(week: Int, playerId: PlayerID) -> String {
        if let result = state.weeklyAchievementResults.first(where: { $0.week == week && $0.playerId == playerId }) {
            return AppStrings.GameBoard.weeklyGoalScoreText(points: result.points)
        }
        guard week == state.currentWeek,
              let playerState = state.playerGameStates[playerId]
        else {
            return AppStrings.GameBoard.weeklyGoalNotScoredText
        }
        return AppStrings.GameBoard.weeklyGoalProjectedScoreText(
            quantity: weeklyGoalQuantity(week: week, playerState: playerState)
        )
    }


    private func playFishActionSummaryLines(_ payment: PlayFishPaymentViewState) -> [String] {
        var lines = [
            "\(AppStrings.GameBoard.playFishPaymentCard)：\(payment.cardTitle)",
            "\(AppStrings.GameBoard.playFishPaymentTarget)：\(payment.targetText)"
        ]
        if let discardProgress = payment.discardProgress {
            lines.append(discardProgress.progressText)
        }
        lines.append(contentsOf: payment.resourceProgress.map(\.progressText))
        return lines
    }

    private func pendingChoiceActionSummaryLines(_ choice: PendingChoiceViewData) -> [String] {
        var lines = [choice.title, choice.subtitle]
        lines.append(contentsOf: choice.progressLines)
        if let prompt = choice.targetPrompt {
            lines.append(prompt)
        }
        return lines
    }

    private func rightActionKind(for choice: PendingChoiceViewData) -> RightActionPanelActionKind {
        if selectedRewardTokenId != nil {
            switch rewardSelectionMode {
            case .moveSource, .moveTarget:
                return .moveResource
            case .target,
                 .coralResource,
                 .coralHandCard,
                 .scatterSchoolSource,
                 .scatterSchoolYoungTarget,
                 .consumeFishConsumer,
                 .consumeFishHandCard,
                 .freePlayHandCard,
                 .freePlayTarget,
                 .playFishFromHandCard,
                 .playFishFromHandTarget,
                 .playFishFromHandPayment:
                return .rewardSelection
            case nil:
                break
            }
        }
        if choice.actions.contains(where: { $0.action == .skip }) {
            return .pendingChoice
        }
        return choice.canResolve ? .pendingChoice : .unsupported
    }

    private func isImportantActionEvent(_ event: GameEvent) -> Bool {
        switch event.payload {
        case .fishPlayed,
             .diverMoved,
             .pendingChoiceResolved,
             .weekEnded,
             .gameEnded:
            return true
        default:
            return false
        }
    }

    private func updateHudToast() {
        if let event = eventLog.reversed().first(where: isImportantActionEvent) {
            guard lastShownHudToastSequence != event.sequenceNumber else {
                return
            }
            showHudToast(text: actionSummary(for: event), sequence: event.sequenceNumber)
            didShowInitialHudToast = true
            return
        }

        guard !didShowInitialHudToast else {
            return
        }
        showHudToast(text: AppStrings.GameBoard.gameStartedSummary, sequence: 0)
        didShowInitialHudToast = true
    }

    private func showHudToast(text: String, sequence: EventID) {
        hudToastDismissWorkItem?.cancel()
        lastShownHudToastSequence = sequence
        hudToastViewState = GameBoardToastViewState(id: sequence, text: text)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.lastShownHudToastSequence == sequence
            else {
                return
            }
            self.hudToastViewState = nil
        }
        hudToastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func actionSummary(for event: GameEvent) -> String {
        switch event.payload {
        case let .fishPlayed(payload):
            return AppStrings.GameBoard.fishPlayedActionSummary(
                playerName: displayName(for: payload.playerId),
                cardName: cardTitle(payload.cardId)
            )
        case let .diverMoved(payload):
            return AppStrings.GameBoard.diverMovedActionSummary(
                playerName: displayName(for: payload.playerId),
                diveSiteName: AppStrings.diveActionSiteName(payload.diveSite)
            )
        case let .pendingChoiceResolved(payload):
            return pendingChoiceResolvedActionSummary(payload)
        case let .weekEnded(payload):
            return AppStrings.GameBoard.weekEndedActionSummary(week: payload.endedWeek)
        case .gameEnded:
            return AppStrings.GameBoard.gameEndedActionSummary
        default:
            return AppStrings.GameBoard.gameStartedSummary
        }
    }

    private func pendingChoiceResolvedActionSummary(_ payload: PendingChoiceResolvedEvent) -> String {
        let playerName = displayName(for: payload.playerId)
        switch payload.resolution {
        case .draw, .drawFromDeck, .recoverCard:
            return AppStrings.GameBoard.rewardDrawFishActionSummary(playerName: playerName)
        case .chooseTarget:
            if payload.appliedEffects.contains(where: {
                if case .placeEgg = $0 { return true }
                return false
            }) {
                return AppStrings.GameBoard.rewardPlaceEggActionSummary(playerName: playerName)
            }
            if payload.appliedEffects.contains(where: {
                if case .hatchEgg = $0 { return true }
                return false
            }) {
                return AppStrings.GameBoard.rewardHatchEggActionSummary(playerName: playerName)
            }
            if payload.appliedEffects.contains(where: {
                if case .placeYoung = $0 { return true }
                return false
            }) {
                return AppStrings.GameBoard.rewardResolvedActionSummary(playerName: playerName)
            }
            return AppStrings.GameBoard.rewardResolvedActionSummary(playerName: playerName)
        case .moveResource:
            return AppStrings.GameBoard.rewardMoveResourceActionSummary(playerName: playerName)
        case .chooseScatterSchoolSource:
            return AppStrings.GameBoard.rewardScatterSchoolActionSummary(playerName: playerName)
        case .placeScatterSchoolYoung:
            return AppStrings.GameBoard.rewardScatterSchoolYoungActionSummary(playerName: playerName)
        case .chooseConsumeFishConsumer:
            return AppStrings.GameBoard.consumeFishConsumer
        case .consumeFishFromHand:
            if let effect = payload.appliedEffects.first(where: {
                if case .fishConsumedFromHand = $0 { return true }
                return false
            }),
               case let .fishConsumedFromHand(_, consumerSlot, consumedCardId) = effect {
                return AppStrings.GameBoard.rewardConsumeFishFromHandActionSummary(
                    playerName: playerName,
                    consumerName: consumerFishName(at: consumerSlot),
                    consumedName: cardTitle(consumedCardId)
                )
            }
            return AppStrings.GameBoard.rewardResolvedActionSummary(playerName: playerName)
        case .chooseFreePlayFish:
            return AppStrings.GameBoard.playFishForFreeHandCard
        case .playFishForFree:
            if let effect = payload.appliedEffects.first(where: {
                if case .fishPlayedForFree = $0 { return true }
                return false
            }),
               case let .fishPlayedForFree(_, cardId, _) = effect {
                return AppStrings.GameBoard.rewardPlayFishForFreeActionSummary(
                    playerName: playerName,
                    cardName: cardTitle(cardId)
                )
            }
            return AppStrings.GameBoard.rewardResolvedActionSummary(playerName: playerName)
        case .choosePlayFishFromHand:
            return AppStrings.GameBoard.playFishFromHandHandCard
        case .choosePlayFishFromHandTarget:
            return AppStrings.GameBoard.playFishFromHandTarget
        case .playFishFromHand:
            if let effect = payload.appliedEffects.first(where: {
                if case .fishPlayedFromHand = $0 { return true }
                return false
            }),
               case let .fishPlayedFromHand(_, cardId, _, _) = effect {
                return AppStrings.GameBoard.fishPlayedActionSummary(
                    playerName: playerName,
                    cardName: cardTitle(cardId)
                )
            }
            return AppStrings.GameBoard.rewardResolvedActionSummary(playerName: playerName)
        case .gainCoralWithEgg,
             .gainCoralWithYoung,
             .gainCoralByDiscard,
             .gainCoralFromAbility:
            if let effect = payload.appliedEffects.first(where: {
                switch $0 {
                case .gainCoral,
                     .gainCoralFromAbility:
                    return true
                default:
                    return false
                }
            }),
               let diveSite = coralDiveSite(from: effect) {
                return AppStrings.GameBoard.rewardGainCoralActionSummary(
                    playerName: playerName,
                    diveSiteName: AppStrings.oceanDiveSiteName(diveSite)
                )
            }
            return AppStrings.GameBoard.rewardResolvedActionSummary(playerName: playerName)
        default:
            if payload.appliedEffects.contains(where: {
                if case .skipCoral = $0 { return true }
                return false
            }) {
                return AppStrings.GameBoard.rewardSkipCoralActionSummary(playerName: playerName)
            }
            return AppStrings.GameBoard.rewardResolvedActionSummary(playerName: playerName)
        }
    }

    private func consumerFishName(at address: OceanSlotAddress) -> String {
        guard let playerState = state.playerGameStates[address.playerId],
              let slot = playerState.ocean.slots.first(where: { $0.address == address }),
              case let .fishCard(cardId) = slot.content
        else {
            return AppStrings.GameBoard.unknownCard
        }
        return cardTitle(cardId)
    }

    private func coralDiveSite(from effect: PendingChoiceAppliedEffect) -> DiveSite? {
        switch effect {
        case let .gainCoral(_, diveSite, _),
             let .gainCoralFromAbility(_, diveSite, _):
            return diveSite
        default:
            return nil
        }
    }

    var canDive: Bool {
        state.phase == .playing
            && !isSelectingPlayFish
            && !hasBlockingPendingChoices
            && state.activeDiveQueue == nil
            && (activePlayerState?.availableDivers ?? 0) > 0
    }

    var diverAvailabilityWarning: String? {
        guard !hasBlockingPendingChoices,
              state.phase == .playing,
              let activePlayerState,
              activePlayerState.availableDivers <= 0
        else {
            return nil
        }
        return AppStrings.GameBoard.diversUsedThisWeek
    }

    var mainActionPrompt: String? {
        guard state.phase == .playing else {
            return nil
        }
        if hasBlockingPendingChoices {
            return AppStrings.GameBoard.resolveCurrentRewardFirst
        }
        if let diverAvailabilityWarning {
            return diverAvailabilityWarning
        }
        return AppStrings.GameBoard.chooseMainAction
    }

    var isSelectingPlayFish: Bool {
        selectedCardId != nil
    }

    var hasBlockingPendingChoices: Bool {
        guard let activePlayerId = state.activePlayerId else {
            return false
        }
        return state.pendingChoices.values.contains { $0.playerId == activePlayerId }
    }

    var diveActionSites: [DiveActionSiteViewData] {
        [.blue, .purple, .green].map { site in
            DiveActionSiteViewData(
                diveSite: site,
                title: AppStrings.diveActionSiteName(site)
            )
        }
    }

    var diveActionBarViewState: DiveActionBarViewState {
        let disabledReason = diveDisabledReason
        return DiveActionBarViewState(
            title: AppStrings.GameBoard.divePanel,
            buttons: [.blue, .purple, .green].map { site in
                DiveActionButtonViewState(
                    diveSite: site,
                    title: AppStrings.diveActionSiteName(site),
                    isEnabled: disabledReason == nil,
                    disabledReasonText: disabledReason
                )
            }
        )
    }

    private var diveDisabledReason: String? {
        guard state.phase == .playing else {
            return AppStrings.GameBoard.chooseMainAction
        }
        if hasBlockingPendingChoices {
            return AppStrings.GameBoard.resolveCurrentRewardFirst
        }
        if state.activeDiveQueue != nil {
            return AppStrings.GameBoard.resolveCurrentDiveRewardFirst
        }
        if isSelectingPlayFish {
            return AppStrings.GameBoard.finishOrCancelPlayFish
        }
        guard activePlayerState != nil else {
            return AppStrings.GameBoard.noActivePlayer
        }
        if (activePlayerState?.availableDivers ?? 0) <= 0 {
            return AppStrings.GameBoard.diversUsedThisWeek
        }
        return nil
    }

    var pendingChoices: [PendingChoiceViewData] {
        state.pendingChoices.values
            .sorted {
                if $0.createdAtSequence == $1.createdAtSequence {
                    return $0.choiceId < $1.choiceId
                }
                return $0.createdAtSequence < $1.createdAtSequence
            }
            .map { choice in
                PendingChoiceViewData(
                    choiceId: choice.choiceId,
                    title: pendingChoiceTitle(choice),
                    subtitle: pendingChoiceSubtitle(choice),
                    sourceText: AppStrings.pendingChoiceSourceName(choice.source),
                    statusText: AppStrings.GameBoard.pendingChoiceWaiting,
                    progressLines: pendingEffectSetProgressLines(for: choice) + compoundAbilityProgressLines(for: choice),
                    targetPrompt: pendingChoiceTargetPrompt(for: choice),
                    noTargetsText: noPendingChoiceTargetsText(for: choice),
                    targets: pendingChoiceTargets(for: choice),
                    cardTargets: pendingChoiceCardTargets(for: choice),
                    moveTargets: pendingChoiceMoveTargets(for: choice),
                    canSkip: choice.isOptional,
                    canResolve: canResolvePendingChoice(choice),
                    actions: pendingChoiceActionButtons(for: choice)
                )
            }
    }

    var gameEndAbilityPhaseViewState: GameEndAbilityPhaseViewState? {
        guard state.phase == .endGamePending else {
            return nil
        }
        let rows = gameEndAbilityRows()
        return GameEndAbilityPhaseViewState(
            title: AppStrings.GameBoard.gameEndAbilityPhaseTitle,
            summaryText: AppStrings.GameBoard.gameEndAbilityPhaseSummary,
            emptyText: AppStrings.GameBoard.gameEndAbilityPhaseEmpty,
            finishButtonTitle: AppStrings.GameBoard.finishGameEndAbilities,
            canFinish: state.pendingChoices.isEmpty,
            abilityRows: rows
        )
    }

    private var activeRewardChoice: PendingChoice? {
        state.pendingChoices.values
            .sorted {
                if $0.createdAtSequence == $1.createdAtSequence {
                    return $0.choiceId < $1.choiceId
                }
                return $0.createdAtSequence < $1.createdAtSequence
            }
            .first { $0.playerId == state.activePlayerId || state.activePlayerId == nil }
    }

    var weeklyAchievementResults: [WeeklyAchievementResultViewData] {
        state.weeklyAchievementResults
            .sorted { left, right in
                if left.week == right.week {
                    return playerSortIndex(left.playerId) < playerSortIndex(right.playerId)
                }
                return left.week < right.week
            }
            .map { result in
                let playerName = displayName(for: result.playerId)
                return WeeklyAchievementResultViewData(
                    week: result.week,
                    playerId: result.playerId,
                    kind: result.kind,
                    title: AppStrings.GameBoard.weeklyAchievementTitle(
                        week: result.week,
                        playerName: playerName
                    ),
                    subtitle: AppStrings.GameBoard.weeklyAchievementResultText(
                        kind: result.kind,
                        quantity: result.quantity,
                        points: result.points
                    )
                )
            }
    }

    var finalScoreViewState: FinalScoreViewState? {
        guard let finalScoreResult = state.finalScoreResult else {
            return nil
        }
        let maxTotalPoints = max(finalScoreResult.results.map(\.totalPoints).max() ?? 0, 0)
        let ratioDivisor = max(maxTotalPoints, 1)
        let winnerNames = finalScoreResult.winnerPlayerIds.map(displayName)
        let shouldShowCoralScores = shouldShowCoralScoreSegments(for: finalScoreResult)
        let playerRows = finalScoreResult.results.map { result in
            let playerName = displayName(for: result.playerId)
            let playerColor = players.first(where: { $0.playerId == result.playerId })?.color
            return FinalScorePlayerRowViewState(
                playerId: result.playerId,
                playerDisplayName: playerName,
                playerColorText: AppStrings.GameBoard.finalScorePlayerColorText(
                    playerColor.map(AppStrings.colorName)
                ),
                avatarText: String(playerName.prefix(1)),
                totalPoints: result.totalPoints,
                totalText: AppStrings.GameBoard.finalScoreTotalText(points: result.totalPoints),
                totalWidthRatioRelativeToMaxTotal: scoreBarWidthRatio(
                    points: result.totalPoints,
                    maximumTotal: ratioDivisor
                ),
                isWinner: finalScoreResult.winnerPlayerIds.contains(result.playerId),
                segments: finalScoreSegments(
                    for: result,
                    maximumTotal: ratioDivisor,
                    shouldShowCoralScores: shouldShowCoralScores
                )
            )
        }

        return FinalScoreViewState(
            title: AppStrings.GameBoard.finalScoreTitle,
            winnerText: AppStrings.GameBoard.finalScoreWinnerText(
                playerNames: winnerNames,
                isTie: finalScoreResult.isTie
            ),
            maxTotalPoints: maxTotalPoints,
            playerRows: playerRows,
            legendItems: finalScoreLegendItems(shouldShowCoralScores: shouldShowCoralScores)
        )
    }

    var activePlayerState: PlayerGameState? {
        if let activePlayerId = state.activePlayerId {
            return state.playerGameStates[activePlayerId]
        }
        if let choice = state.pendingChoices.values.sorted(by: { $0.createdAtSequence < $1.createdAtSequence }).first {
            return state.playerGameStates[choice.playerId]
        }
        return nil
    }

    var handCards: [GameBoardCardViewData] {
        guard let activePlayerState else {
            return []
        }
        return activePlayerState.hand.map { cardId in
            let card = cardsById[cardId]
            return GameBoardCardViewData(
                cardId: cardId,
                title: cardTitle(cardId),
                subtitle: cardSubtitle(card),
                isSelected: selectedCardId == cardId,
                isDisabledByUI: cardHasUnsupportedCostInUI(card)
            )
        }
    }

    var discardPileViewState: DiscardPileViewState {
        let cardFaces = discardPileCardFaces
        return DiscardPileViewState(
            playerId: state.activePlayerId,
            title: AppStrings.GameBoard.discardPile,
            countText: AppStrings.GameBoard.discardPileCountText(cardFaces.count),
            badgeText: "\(cardFaces.count)",
            usesCardStackPreview: true,
            usesOverlayBadge: true,
            count: cardFaces.count,
            topCards: Array(cardFaces.prefix(3)),
            isEmpty: cardFaces.isEmpty,
            isDetailPresented: isDiscardPileDetailPresented,
            emptyText: AppStrings.GameBoard.discardPileEmpty
        )
    }

    var discardPileDetailViewState: DiscardPileDetailViewState? {
        guard isDiscardPileDetailPresented else {
            return nil
        }
        let cardFaces = discardPileCardFaces
        return DiscardPileDetailViewState(
            title: AppStrings.GameBoard.discardPile,
            countText: AppStrings.GameBoard.discardPileDetailCountText(cardFaces.count),
            cards: cardFaces,
            emptyText: AppStrings.GameBoard.discardPileEmpty,
            maxCardsPerRow: 4,
            presentationStyle: .fullScreenOverlay,
            isReadOnly: true
        )
    }

    private var discardPileCardFaces: [FishCardFaceViewState] {
        activePlayerState?.discardPile
            .reversed()
            .map(fishCardFaceViewState(cardId:)) ?? []
    }

    var handViewState: HandViewState {
        guard let activePlayerState else {
            return HandViewState(
                cards: [],
                selectedCard: nil,
                isStackedPresentation: true,
                pulledOutCardId: nil,
                canSelectCards: false,
                canSelectMainCard: false,
                canSelectDiscardPayment: false,
                blockingMessage: AppStrings.GameBoard.noActivePlayer
            )
        }

        let canSelectCards = canSelectHandCards
        let cards = activePlayerState.hand.enumerated().map { index, cardId in
            handCardViewState(cardId: cardId, stackIndex: index, canSelectCards: canSelectCards)
        }
        return HandViewState(
            cards: cards,
            selectedCard: cards.first { $0.isSelected },
            isStackedPresentation: true,
            pulledOutCardId: selectedCardId,
            canSelectCards: canSelectCards,
            canSelectMainCard: canSelectCards,
            canSelectDiscardPayment: canSelectDiscardPaymentCards,
            blockingMessage: handBlockingMessage
        )
    }

    var paymentProgressViewState: PlayFishPaymentViewState? {
        guard let selectedCard else {
            return nil
        }

        return PlayFishPaymentViewState(
            cardTitle: cardTitle(selectedCard.id),
            targetText: selectedTargetSlot.map(slotLocationText) ?? AppStrings.GameBoard.noTargetSelected,
            isTargetSelected: selectedTargetSlotIsAvailable,
            discardProgress: discardPaymentProgressViewState(for: selectedCard),
            resourceProgress: resourcePaymentProgress,
            canConfirm: canSubmitPlayFish,
            blockingMessage: handBlockingMessage
        )
    }

    var oceanSlots: [OceanSlotViewData] {
        guard let activePlayerState else {
            return []
        }
        return activePlayerState.ocean.slots
            .sorted { left, right in
                if left.address.diveSite.rawValue == right.address.diveSite.rawValue {
                    return left.address.rowIndex < right.address.rowIndex
                }
                return diveSiteSortIndex(left.address.diveSite) < diveSiteSortIndex(right.address.diveSite)
            }
            .map(oceanSlotViewData)
    }

    var oceanColumns: [OceanDiveSiteColumnViewData] {
        DiveSite.allCases.map { diveSite in
            let columnSlots = oceanSlots.filter { $0.address.diveSite == diveSite }
            return OceanDiveSiteColumnViewData(
                diveSite: diveSite,
                title: AppStrings.oceanDiveSiteName(diveSite),
                coralReef: coralReefViewState(for: diveSite),
                slots: columnSlots,
                zoneSections: OceanZone.allCases.map { zone in
                    OceanZoneSectionViewData(
                        diveSite: diveSite,
                        zone: zone,
                        title: AppStrings.oceanZoneName(zone),
                        slots: columnSlots.filter { $0.address.zone == zone },
                        isHighlightedByDiveQueue: columnSlots.contains {
                            $0.address.zone == zone && $0.isHighlightedByDiveQueue
                        }
                    )
                }
            )
        }
    }

    var rewardPoolViewState: RewardPoolViewState {
        guard let choice = activeRewardChoice else {
            return RewardPoolViewState(
                isActive: false,
                titleText: AppStrings.GameBoard.currentRewards,
                sourceText: nil,
                rewards: [],
                blockingMessage: nil,
                selectedRewardTokenId: selectedRewardTokenId,
                instructionText: AppStrings.GameBoard.noCurrentRewards
            )
        }

        let entries = rewardTokenEntries(for: choice)
        return RewardPoolViewState(
            isActive: true,
            titleText: AppStrings.GameBoard.currentRewards,
            sourceText: rewardSourceText(for: choice),
            rewards: entries.map(\.token),
            blockingMessage: canResolvePendingChoice(choice) ? nil : AppStrings.GameBoard.resolveCurrentRewardFirst,
            selectedRewardTokenId: selectedRewardTokenId,
            instructionText: rewardInstructionText(for: choice)
        )
    }

    var bottomAreas: [DiveSiteBottomAreaViewState] {
        [.blue, .purple, .green].map(bottomAreaViewState)
    }

    var highlightedBottomBonusDiveSite: DiveActionSite? {
        guard let queue = state.activeDiveQueue,
              queue.currentStep?.source == .bottomBonus
        else {
            return nil
        }
        return queue.diveSite
    }

    var selectedFishCardDetails: SelectedFishCardViewData? {
        guard let selectedCard else {
            return nil
        }

        let unsupportedItems = selectedCardUnsupportedItems(selectedCard)
        return SelectedFishCardViewData(
            title: cardTitle(selectedCard.id),
            scoreText: "\(selectedCard.printedPoints)",
            lengthText: cardLengthText(selectedCard),
            allowedZonesText: selectedCard.allowedZones.map(AppStrings.oceanZoneName).joined(separator: "，"),
            requiredDiveSiteText: selectedCard.requiredDiveSiteColor.map(AppStrings.diveSiteColorName) ?? AppStrings.GameBoard.noLimit,
            costsText: selectedCard.costs.isEmpty ? AppStrings.GameBoard.noCost : selectedCard.costs.map(costText).joined(separator: "，"),
            unsupportedText: unsupportedItems.isEmpty ? nil : unsupportedItems.joined(separator: "，")
        )
    }

    var selectedCardPaymentPrompt: String? {
        guard let card = selectedCard else {
            return nil
        }
        if cardHasUnsupportedCostInUI(card) {
            return AppStrings.GameBoard.costUnsupportedInUI
        }
        let prompts = [
            countPrompt(AppStrings.GameBoard.discardPayment, discardCostCount(for: card)),
            countPrompt(AppStrings.GameBoard.chooseEggSources, resourceCostCount(.egg, for: card)),
            countPrompt(AppStrings.GameBoard.chooseYoungSources, resourceCostCount(.young, for: card))
        ].compactMap { $0 }

        if !prompts.isEmpty {
            return prompts.joined(separator: "，")
        }
        return nil
    }

    var resourcePaymentProgress: [ResourcePaymentProgressViewState] {
        resourcePaymentKinds.compactMap { kind in
            let requiredCount = resourceCostCount(kind, for: selectedCard)
            guard requiredCount > 0 else {
                return nil
            }
            let selectedCount = selectedSources(for: kind).count
            return ResourcePaymentProgressViewState(
                kind: kind,
                title: resourceName(kind),
                selectedCount: selectedCount,
                requiredCount: requiredCount,
                progressText: AppStrings.GameBoard.resourcePaymentProgressText(
                    resourceName: resourceName(kind),
                    selectedCount: selectedCount,
                    requiredCount: requiredCount
                ),
                isComplete: selectedCount == requiredCount
            )
        }
    }

    var discardPaymentOptions: [GameBoardCardViewData] {
        guard let selectedCardId,
              let activePlayerState,
              discardCostCount(for: selectedCard) != nil
        else {
            return []
        }

        return activePlayerState.hand
            .filter { $0 != selectedCardId }
            .map { cardId in
                let card = cardsById[cardId]
                return GameBoardCardViewData(
                    cardId: cardId,
                    title: cardTitle(cardId),
                    subtitle: cardSubtitle(card),
                    isSelected: selectedDiscardCardIds.contains(cardId),
                    isDisabledByUI: false
                )
            }
    }

    var eggSourceOptions: [ResourceSourceViewData] {
        resourceSourceOptions(for: .egg)
    }

    var youngSourceOptions: [ResourceSourceViewData] {
        resourceSourceOptions(for: .young)
    }

    var canSubmitPlayFish: Bool {
        guard selectedCard != nil,
              selectedTargetSlotIsAvailable,
              state.activeDiveQueue == nil,
              !selectedCardHasUnsupportedUICost
        else {
            return false
        }
        if gameEndPlayFishFromHandPaymentChoice != nil {
            return hasCompleteDiscardPayment && hasCompleteResourcePayment
        }
        guard state.phase == .playing,
              !hasBlockingPendingChoices,
              (activePlayerState?.availableDivers ?? 0) > 0
        else {
            return false
        }
        return hasCompleteDiscardPayment && hasCompleteResourcePayment
    }

    var selectedCardHasUnsupportedUICost: Bool {
        cardHasUnsupportedCostInUI(selectedCard)
    }

    private var selectedCard: Card? {
        selectedCardId.flatMap { cardsById[$0] }
    }

    private var gameEndPlayFishFromHandPaymentChoice: PendingChoice? {
        state.pendingChoices.values.first { choice in
            choice.kind == .playFishFromHand
                && choice.expectedInput == .playFishFromHandPayment
                && choice.playFishFromHandProgress?.selectedCardId == selectedCardId
                && choice.playFishFromHandProgress?.targetSlot == selectedTargetSlot
        }
    }

    private var canSelectHandCards: Bool {
        if isSelectingCoralDiscardCard
            || isSelectingConsumeFishHandCard
            || isSelectingFreePlayHandCard
            || isSelectingPlayFishFromHandCard
            || gameEndPlayFishFromHandPaymentChoice != nil {
            return true
        }
        return state.phase == .playing
            && activePlayerState != nil
            && !hasBlockingPendingChoices
            && state.activeDiveQueue == nil
    }

    private var isSelectingCoralDiscardCard: Bool {
        if case .coralHandCard = rewardSelectionMode {
            return true
        }
        return false
    }

    private var isSelectingConsumeFishHandCard: Bool {
        if case .consumeFishHandCard = rewardSelectionMode {
            return true
        }
        return false
    }

    private var isSelectingFreePlayHandCard: Bool {
        if case .freePlayHandCard = rewardSelectionMode {
            return true
        }
        return false
    }

    private var isSelectingPlayFishFromHandCard: Bool {
        if case .playFishFromHandCard = rewardSelectionMode {
            return true
        }
        return false
    }

    private var canSelectDiscardPaymentCards: Bool {
        guard canSelectHandCards,
              selectedCardId != nil,
              discardCostCount(for: selectedCard) != nil
        else {
            return false
        }
        return true
    }

    private var handBlockingMessage: String? {
        if isSelectingCoralDiscardCard
            || isSelectingConsumeFishHandCard
            || isSelectingFreePlayHandCard
            || isSelectingPlayFishFromHandCard
            || gameEndPlayFishFromHandPaymentChoice != nil {
            return nil
        }
        if hasBlockingPendingChoices {
            return AppStrings.GameBoard.resolveCurrentRewardFirst
        }
        if state.activeDiveQueue != nil {
            return AppStrings.GameBoard.resolveCurrentDiveRewardFirst
        }
        if state.phase != .playing {
            return AppStrings.GameBoard.chooseMainAction
        }
        if activePlayerState == nil {
            return AppStrings.GameBoard.noActivePlayer
        }
        return nil
    }

    private func canSelectDiscardPaymentCard(_ cardId: CardID) -> Bool {
        guard canSelectDiscardPaymentCards,
              let selectedCardId,
              cardId != selectedCardId,
              activePlayerState?.hand.contains(cardId) == true
        else {
            return false
        }
        return true
    }

    private func discardPaymentProgressViewState(for card: Card) -> DiscardPaymentProgressViewState? {
        guard let requiredCount = discardCostCount(for: card), requiredCount > 0 else {
            return nil
        }
        let selectedCount = selectedDiscardCardIds.count
        return DiscardPaymentProgressViewState(
            selectedCount: selectedCount,
            requiredCount: requiredCount,
            progressText: AppStrings.GameBoard.discardPaymentProgressText(
                selectedCount: selectedCount,
                requiredCount: requiredCount
            ),
            isComplete: selectedCount == requiredCount
        )
    }

    private var displayResourceKinds: [ResourceKind] {
        [.egg, .young, .school]
    }

    private var resourcePaymentKinds: [ResourceKind] {
        [.egg, .young]
    }

    private var handStackOverlapOffsetX: Double {
        74
    }

    private var handStackRestingOffsetY: Double {
        46
    }

    private var handStackPulledOutOffsetY: Double {
        -18
    }

    private static var fixedHandCardWidth: Double {
        HandCardViewState.fixedCardWidth
    }

    private static var fixedHandCardHeight: Double {
        HandCardViewState.fixedCardHeight
    }

    private static var fixedHandCardScale: Double {
        HandCardViewState.fixedScale
    }

    private var slotAspectRatio: Double {
        CardRenderMetrics.cardAspectRatio
    }

    private var selectedTargetSlotIsAvailable: Bool {
        guard let selectedTargetSlot,
              let activePlayerState,
              let slot = activePlayerState.ocean.slots.first(where: { $0.address == selectedTargetSlot })
        else {
            return false
        }
        if let choice = gameEndPlayFishFromHandPaymentChoice,
           let card = selectedCard {
            return playFishFromHandTargetIsLegal(slot, card: card, for: choice)
        }
        return playFishSlotPreview(for: slot).isSelectable
    }

    private var hasCompleteDiscardPayment: Bool {
        guard let discardCount = discardCostCount(for: selectedCard) else {
            return true
        }
        return selectedDiscardCardIds.count == discardCount
    }

    private var hasCompleteResourcePayment: Bool {
        selectedEggSources.count == resourceCostCount(.egg, for: selectedCard)
            && selectedYoungSources.count == resourceCostCount(.young, for: selectedCard)
    }

    convenience init(roomService: any RoomService) {
        let factory = CardCatalogFactory()
        self.init(
            roomService: roomService,
            cardCatalogProvider: {
                guard let mode = (roomService as? GameDataModeConfiguring)?.gameDataMode else {
                    return EmptyCardCatalog()
                }
                let enabledExpansions = roomService.gameRoom?.gameConfig.enabledExpansions ?? []
                return (try? factory.makeCatalog(for: mode, enabledExpansions: enabledExpansions)) ?? EmptyCardCatalog()
            }
        )
    }

    convenience init(
        roomService: any RoomService,
        cardCatalog: any CardCatalog,
        abilityResolver: AbilityResolver = AbilityResolver()
    ) {
        self.init(
            roomService: roomService,
            cardCatalogProvider: { cardCatalog },
            abilityResolver: abilityResolver
        )
    }

    init(
        roomService: any RoomService,
        cardCatalogProvider: @escaping () -> any CardCatalog,
        abilityResolver: AbilityResolver = AbilityResolver()
    ) {
        self.roomService = roomService
        self.cardCatalogProvider = cardCatalogProvider
        self.abilityResolver = abilityResolver
        refresh()
    }

    func refresh() {
        if invalidateRoomForUnresolvableCardsIfNeeded() {
            state = roomService.gameState
            players = roomService.gameRoom?.players ?? []
            eventLog = roomService.eventLog
            removeInvalidSelections()
            updateHudToast()
            return
        }
        state = roomService.gameState
        players = roomService.gameRoom?.players ?? []
        eventLog = roomService.eventLog
        removeInvalidSelections()
        updateHudToast()
    }

    func selectHandCard(_ cardId: CardID) {
        if case let .coralHandCard(choiceId, _) = rewardSelectionMode {
            guard let choice = state.pendingChoices[choiceId],
                  state.playerGameStates[choice.playerId]?.hand.contains(cardId) == true
            else {
                errorMessage = AppStrings.GameBoard.unknownCard
                return
            }
            resolvePendingChoice(choiceId, resolution: .gainCoralByDiscard(cardId: cardId))
            return
        }
        if case let .consumeFishHandCard(choiceId, _) = rewardSelectionMode {
            guard let choice = state.pendingChoices[choiceId],
                  consumeFishHandCardIsLegal(cardId, for: choice)
            else {
                errorMessage = AppStrings.GameBoard.consumeFishMustBeShorter
                return
            }
            resolvePendingChoice(choiceId, resolution: .consumeFishFromHand(cardId))
            return
        }
        if case let .freePlayHandCard(choiceId, _) = rewardSelectionMode {
            guard let choice = state.pendingChoices[choiceId],
                  freePlayHandCardIsLegal(cardId, for: choice)
            else {
                errorMessage = AppStrings.GameBoard.playFishForFreeFilterMismatch
                return
            }
            resolvePendingChoice(choiceId, resolution: .chooseFreePlayFish(cardId))
            return
        }
        if case let .playFishFromHandCard(choiceId, _) = rewardSelectionMode {
            guard let choice = state.pendingChoices[choiceId],
                  playFishFromHandCardIsLegal(cardId, for: choice)
            else {
                errorMessage = AppStrings.GameBoard.playFishForFreeFilterMismatch
                return
            }
            selectedCardId = cardId
            selectedTargetSlot = nil
            selectedDiscardCardIds = []
            clearResourcePaymentSelection()
            self.rewardSelectionMode = nil
            resolvePendingChoice(choiceId, resolution: .choosePlayFishFromHand(cardId))
            return
        }
        guard canSelectHandCards else {
            errorMessage = handBlockingMessage
            return
        }
        guard activePlayerState?.hand.contains(cardId) == true else {
            errorMessage = AppStrings.GameBoard.unknownCard
            return
        }
        if selectedCardId == cardId {
            clearPlayFishSelection()
            errorMessage = nil
            return
        }
        if selectedCardId != nil, canSelectDiscardPaymentCard(cardId) {
            toggleDiscardPaymentCard(cardId)
            return
        }
        selectedCardId = cardId
        selectedTargetSlot = nil
        selectedDiscardCardIds = []
        clearResourcePaymentSelection()
        errorMessage = nil
    }

    @discardableResult
    func beginDraggingHandCard(_ cardId: CardID) -> Bool {
        guard canSelectHandCards else {
            errorMessage = handBlockingMessage
            return false
        }
        guard activePlayerState?.hand.contains(cardId) == true else {
            errorMessage = AppStrings.GameBoard.unknownCard
            return false
        }
        selectedCardId = cardId
        selectedTargetSlot = nil
        selectedDiscardCardIds = []
        clearResourcePaymentSelection()
        draggingHandCardId = cardId
        dragHoverSlotAddress = nil
        errorMessage = nil
        return true
    }

    func updateDragTarget(_ address: OceanSlotAddress?) {
        guard draggingHandCardId != nil else {
            dragHoverSlotAddress = nil
            return
        }
        dragHoverSlotAddress = address
        guard let address,
              let activePlayerState,
              let slot = activePlayerState.ocean.slots.first(where: { $0.address == address })
        else {
            return
        }
        if !playFishSlotPreview(for: slot).isSelectable {
            errorMessage = playFishSlotPreview(for: slot).message
        }
    }

    @discardableResult
    func dropHandCard(_ cardId: CardID? = nil, targetAddress: OceanSlotAddress) -> Bool {
        guard let draggingCardId = cardId ?? draggingHandCardId else {
            return false
        }
        if draggingHandCardId == nil {
            guard beginDraggingHandCard(draggingCardId) else {
                return false
            }
        } else if selectedCardId != draggingCardId {
            guard beginDraggingHandCard(draggingCardId) else {
                return false
            }
        }
        guard let activePlayerState,
              let slot = activePlayerState.ocean.slots.first(where: { $0.address == targetAddress })
        else {
            errorMessage = AppStrings.GameBoard.slotCannotPlayHere
            return false
        }

        let preview = playFishSlotPreview(for: slot)
        guard preview.isSelectable else {
            selectedTargetSlot = nil
            draggingHandCardId = nil
            dragHoverSlotAddress = nil
            errorMessage = preview.message
            return false
        }

        selectedTargetSlot = targetAddress
        draggingHandCardId = nil
        dragHoverSlotAddress = nil
        errorMessage = hasCompleteResourcePayment && hasCompleteDiscardPayment
            ? AppStrings.GameBoard.dragPlayTargetSelected
            : AppStrings.GameBoard.payCostsFirst
        return true
    }

    func cancelHandCardDrag() {
        draggingHandCardId = nil
        dragHoverSlotAddress = nil
    }

    func selectCard(_ cardId: CardID) {
        selectHandCard(cardId)
    }

    func selectTargetSlot(_ address: OceanSlotAddress) {
        if handleRewardSlotTap(address) {
            return
        }
        guard let activePlayerState,
              let slot = activePlayerState.ocean.slots.first(where: { $0.address == address }),
              playFishSlotPreview(for: slot).isSelectable
        else {
            if let activePlayerState,
               let slot = activePlayerState.ocean.slots.first(where: { $0.address == address }) {
                errorMessage = playFishSlotPreview(for: slot).message
            }
            return
        }
        selectedTargetSlot = address
        errorMessage = nil
    }

    func selectRewardToken(_ tokenId: String) {
        guard let choice = activeRewardChoice,
              let entry = rewardTokenEntries(for: choice).first(where: { $0.token.id == tokenId })
        else {
            errorMessage = AppStrings.GameBoard.pendingChoiceNotFound
            return
        }
        guard entry.token.isSelectable else {
            errorMessage = entry.token.unavailableReasonText ?? AppStrings.GameBoard.abilityUnsupported
            return
        }

        selectedRewardTokenId = tokenId
        switch entry.action {
        case let .direct(choiceId, resolution):
            self.rewardSelectionMode = nil
            resolvePendingChoice(choiceId, resolution: resolution)
        case let .chooseTarget(choiceId, kind):
            rewardSelectionMode = .target(choiceId: choiceId, tokenId: tokenId, kind: kind)
            errorMessage = AppStrings.GameBoard.chooseLeftTarget
        case let .chooseMoveSource(choiceId):
            rewardSelectionMode = .moveSource(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.chooseSource
        case let .chooseCoralResource(choiceId, tokenId, kind):
            rewardSelectionMode = .coralResource(choiceId: choiceId, tokenId: tokenId, kind: kind)
            errorMessage = AppStrings.GameBoard.chooseCoralResourceSource
        case let .chooseCoralHandCard(choiceId, tokenId):
            rewardSelectionMode = .coralHandCard(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.chooseCoralDiscardCard
        case let .chooseScatterSchoolSource(choiceId, tokenId):
            rewardSelectionMode = .scatterSchoolSource(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.scatterSchoolSource
        case let .chooseScatterSchoolYoungTarget(choiceId, tokenId):
            rewardSelectionMode = .scatterSchoolYoungTarget(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.scatterSchoolYoungTarget
        case let .chooseConsumeFishConsumer(choiceId, tokenId):
            rewardSelectionMode = .consumeFishConsumer(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.consumeFishConsumer
        case let .chooseConsumeFishHandCard(choiceId, tokenId):
            rewardSelectionMode = .consumeFishHandCard(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.consumeFishHandCard
        case let .chooseFreePlayHandCard(choiceId, tokenId):
            rewardSelectionMode = .freePlayHandCard(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.playFishForFreeHandCard
        case let .chooseFreePlayTarget(choiceId, tokenId, cardId):
            rewardSelectionMode = .freePlayTarget(choiceId: choiceId, tokenId: tokenId, cardId: cardId)
            errorMessage = AppStrings.GameBoard.playFishForFreeTarget
        case let .choosePlayFishFromHandCard(choiceId, tokenId):
            rewardSelectionMode = .playFishFromHandCard(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.playFishFromHandHandCard
        case let .choosePlayFishFromHandTarget(choiceId, tokenId, cardId):
            rewardSelectionMode = .playFishFromHandTarget(choiceId: choiceId, tokenId: tokenId, cardId: cardId)
            errorMessage = AppStrings.GameBoard.playFishFromHandTarget
        case let .choosePlayFishFromHandPayment(choiceId, tokenId, cardId, targetSlot):
            rewardSelectionMode = .playFishFromHandPayment(
                choiceId: choiceId,
                tokenId: tokenId,
                cardId: cardId,
                targetSlot: targetSlot
            )
            selectedCardId = cardId
            selectedTargetSlot = targetSlot
            selectedDiscardCardIds = []
            clearResourcePaymentSelection()
            errorMessage = AppStrings.GameBoard.playFishFromHandPayment
        case .unsupported:
            rewardSelectionMode = nil
            errorMessage = AppStrings.GameBoard.abilityUnsupported
        }
    }

    @discardableResult
    private func handleRewardSlotTap(_ address: OceanSlotAddress) -> Bool {
        guard let rewardSelectionMode else {
            return false
        }

        switch rewardSelectionMode {
        case let .target(choiceId, _, kind):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let slot = playerState.ocean.slots.first(where: { $0.address == address }),
                  pendingChoiceTargetIsLegal(slot, for: choice),
                  choice.kind == kind
            else {
                errorMessage = AppStrings.GameBoard.chooseLeftTarget
                return true
            }
            resolvePendingChoice(choiceId, resolution: .chooseTarget(address))
            return true
        case let .moveSource(choiceId, tokenId):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let source = playerState.ocean.slots.first(where: { $0.address == address }),
                  let kind = preferredMoveResourceKind(in: source)
            else {
                errorMessage = AppStrings.GameBoard.chooseSource
                return true
            }
            self.rewardSelectionMode = .moveTarget(
                choiceId: choiceId,
                tokenId: tokenId,
                source: address,
                kind: kind
            )
            errorMessage = AppStrings.GameBoard.chooseTarget
            return true
        case let .moveTarget(choiceId, _, sourceAddress, kind):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let source = playerState.ocean.slots.first(where: { $0.address == sourceAddress }),
                  let target = playerState.ocean.slots.first(where: { $0.address == address }),
                  moveTargetIsLegal(target, from: source, kind: kind)
            else {
                errorMessage = AppStrings.GameBoard.chooseTarget
                return true
            }
            resolvePendingChoice(
                choiceId,
                resolution: .moveResource(source: sourceAddress, target: address, kind: kind)
            )
            return true
        case let .coralResource(choiceId, _, kind):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let source = playerState.ocean.slots.first(where: { $0.address == address }),
                  resourceAmount(kind, in: source) > 0
            else {
                errorMessage = AppStrings.GameBoard.chooseCoralResourceSource
                return true
            }
            switch kind {
            case .egg:
                resolvePendingChoice(choiceId, resolution: .gainCoralWithEgg(source: address))
            case .young:
                resolvePendingChoice(choiceId, resolution: .gainCoralWithYoung(source: address))
            default:
                errorMessage = AppStrings.GameBoard.chooseCoralResourceSource
            }
            return true
        case .coralHandCard:
            errorMessage = AppStrings.GameBoard.chooseCoralDiscardCard
            return true
        case let .scatterSchoolSource(choiceId, _):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let source = playerState.ocean.slots.first(where: { $0.address == address }),
                  source.address.playerId == choice.playerId,
                  resourceAmount(.school, in: source) > 0
            else {
                errorMessage = AppStrings.GameBoard.scatterSchoolSource
                return true
            }
            resolvePendingChoice(choiceId, resolution: .chooseScatterSchoolSource(address))
            return true
        case let .scatterSchoolYoungTarget(choiceId, _):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let target = playerState.ocean.slots.first(where: { $0.address == address }),
                  scatterSchoolYoungTargetIsLegal(target, for: choice, playerState: playerState)
            else {
                errorMessage = AppStrings.GameBoard.scatterSchoolYoungTarget
                return true
            }
            resolvePendingChoice(choiceId, resolution: .placeScatterSchoolYoung(address))
            return true
        case let .consumeFishConsumer(choiceId, _):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let consumerSlot = playerState.ocean.slots.first(where: { $0.address == address }),
                  consumeFishConsumerIsLegal(consumerSlot, for: choice)
            else {
                errorMessage = AppStrings.GameBoard.consumeFishConsumer
                return true
            }
            resolvePendingChoice(choiceId, resolution: .chooseConsumeFishConsumer(address))
            return true
        case .consumeFishHandCard:
            errorMessage = AppStrings.GameBoard.consumeFishHandCard
            return true
        case .freePlayHandCard:
            errorMessage = AppStrings.GameBoard.playFishForFreeHandCard
            return true
        case let .freePlayTarget(choiceId, _, cardId):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let target = playerState.ocean.slots.first(where: { $0.address == address }),
                  let card = cardsById[cardId]
            else {
                errorMessage = AppStrings.GameBoard.playFishForFreeTarget
                return true
            }
            let preview = playFishSlotPreview(for: target, card: card)
            guard preview.isSelectable else {
                errorMessage = preview.message
                return true
            }
            resolvePendingChoice(choiceId, resolution: .playFishForFree(cardId: cardId, targetSlot: address))
            return true
        case .playFishFromHandCard:
            errorMessage = AppStrings.GameBoard.playFishFromHandHandCard
            return true
        case let .playFishFromHandTarget(choiceId, _, cardId):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let target = playerState.ocean.slots.first(where: { $0.address == address }),
                  let card = cardsById[cardId],
                  playFishFromHandTargetIsLegal(target, card: card, for: choice)
            else {
                errorMessage = AppStrings.GameBoard.playFishFromHandTarget
                return true
            }
            selectedCardId = cardId
            selectedTargetSlot = address
            selectedDiscardCardIds = []
            clearResourcePaymentSelection()
            self.rewardSelectionMode = nil
            resolvePendingChoice(choiceId, resolution: .choosePlayFishFromHandTarget(address))
            return true
        case .playFishFromHandPayment:
            errorMessage = AppStrings.GameBoard.playFishFromHandPayment
            return true
        }
    }

    func cancelPlayFishSelection() {
        clearPlayFishSelection()
        errorMessage = nil
    }

    func selectPlayerAvatar(_ playerId: PlayerID) {
        selectedViewedPlayerId = playerId
        if playerId != state.activePlayerId {
            errorMessage = AppStrings.GameBoard.opponentBoardPreviewUnavailable
        } else {
            errorMessage = nil
        }
    }

    func selectWeeklyGoalBox(_ index: Int) {
        selectedWeeklyGoalDetailWeek = index
    }

    func dismissWeeklyGoalDetail() {
        selectedWeeklyGoalDetailWeek = nil
    }

    func showEventLog() {
        isEventLogPresented = true
    }

    func hideEventLog() {
        isEventLogPresented = false
    }

    func showDiscardPile() {
        isDiscardPileDetailPresented = true
    }

    func hideDiscardPile() {
        isDiscardPileDetailPresented = false
    }

    func performRightActionPrimary() {
        let viewState = rightActionPanelViewState
        switch viewState.actionKind {
        case .playFishPayment:
            if gameEndPlayFishFromHandPaymentChoice != nil {
                submitGameEndPlayFishFromHand()
            } else {
                submitPlayFish()
            }
        case .pendingChoice,
             .rewardSelection,
             .moveResource:
            guard let choiceId = viewState.pendingChoiceId,
                  let action = viewState.primaryPendingChoiceAction
            else {
                errorMessage = viewState.warningText ?? AppStrings.GameBoard.chooseRewardToken
                return
            }
            performPendingChoiceAction(action, for: choiceId)
        case .unsupported where state.phase == .endGamePending:
            finishGameEndAbilities()
        case .unsupported:
            errorMessage = viewState.warningText ?? AppStrings.GameBoard.chooseRewardToken
        case .none:
            errorMessage = AppStrings.GameBoard.chooseMainAction
        }
    }

    func performRightActionSecondary() {
        let viewState = rightActionPanelViewState
        guard viewState.actionKind == .playFishPayment else {
            return
        }
        cancelPlayFishSelection()
    }

    func toggleDiscardPaymentCard(_ cardId: CardID) {
        guard canSelectDiscardPaymentCard(cardId),
              let discardCount = discardCostCount(for: selectedCard)
        else {
            return
        }
        if selectedDiscardCardIds.contains(cardId) {
            selectedDiscardCardIds.remove(cardId)
        } else {
            guard selectedDiscardCardIds.count < discardCount else {
                return
            }
            selectedDiscardCardIds.insert(cardId)
        }
        errorMessage = nil
    }

    func toggleEggSource(_ address: OceanSlotAddress) {
        cycleResourceSource(address, kind: .egg)
    }

    func toggleYoungSource(_ address: OceanSlotAddress) {
        cycleResourceSource(address, kind: .young)
    }

    func toggleResourcePayment(address: OceanSlotAddress, kind: ResourceKind, tokenIndex: Int) {
        guard !hasBlockingPendingChoices else {
            return
        }
        guard state.activeDiveQueue == nil else {
            return
        }
        guard isSelectingPlayFish else {
            return
        }
        guard let activePlayerState else {
            return
        }
        let tokenCount = resourceTokenCount(kind, at: address, in: activePlayerState)
        guard tokenIndex >= 0, tokenIndex < tokenCount else {
            return
        }
        let requiredCount = resourceCostCount(kind, for: selectedCard)
        guard resourcePaymentKinds.contains(kind), requiredCount > 0 else {
            return
        }

        let key = ResourcePaymentTokenKey(address: address, kind: kind, tokenIndex: tokenIndex)
        if selectedResourcePaymentTokens.contains(key) {
            selectedResourcePaymentTokens.remove(key)
        } else {
            guard selectedResourcePaymentTokens.filter({ $0.kind == kind }).count < requiredCount else {
                return
            }
            selectedResourcePaymentTokens.insert(key)
        }
        syncSelectedResourceSourcesFromTokens()
        errorMessage = nil
    }

    func toggleResourcePayment(address: OceanSlotAddress, kind: ResourceKind) {
        toggleResourcePayment(address: address, kind: kind, tokenIndex: 0)
    }

    func submitPlayFish() {
        guard !hasBlockingPendingChoices else {
            errorMessage = AppStrings.GameBoard.resolveCurrentRewardFirst
            return
        }
        guard state.activeDiveQueue == nil else {
            errorMessage = AppStrings.GameBoard.resolveCurrentDiveRewardFirst
            return
        }
        guard let activePlayerId = state.activePlayerId else {
            errorMessage = AppStrings.GameBoard.noActivePlayer
            return
        }
        guard (activePlayerState?.availableDivers ?? 0) > 0 else {
            errorMessage = AppStrings.GameBoard.diversUsedThisWeek
            return
        }
        guard let roomId = state.roomId ?? roomService.gameRoom?.roomId else {
            errorMessage = AppStrings.GameBoard.noActiveRoom
            return
        }
        guard let selectedCardId, let selectedTargetSlot else {
            errorMessage = "\(AppStrings.GameBoard.selectCard)，\(AppStrings.GameBoard.selectSlot)。"
            return
        }
        guard selectedTargetSlotIsAvailable else {
            errorMessage = AppStrings.GameBoard.selectSlot
            return
        }
        guard !selectedCardHasUnsupportedUICost else {
            errorMessage = AppStrings.GameBoard.costUnsupportedInUI
            return
        }
        guard hasCompleteDiscardPayment else {
            errorMessage = AppStrings.GameBoard.discardPaymentIncomplete
            return
        }
        guard selectedEggSources.count == resourceCostCount(.egg, for: selectedCard) else {
            errorMessage = AppStrings.GameBoard.eggPaymentIncomplete
            return
        }
        guard selectedYoungSources.count == resourceCostCount(.young, for: selectedCard) else {
            errorMessage = AppStrings.GameBoard.youngPaymentIncomplete
            return
        }

        do {
            _ = try roomService.submit(
                PlayerCommand(
                    commandId: nextCommandId(),
                    playerId: activePlayerId,
                    roomId: roomId,
                    payload: .playFish(
                        PlayFishCommand(
                            cardId: selectedCardId,
                            targetSlot: selectedTargetSlot,
                            payment: PlayFishPayment(
                                discardedCardIds: Array(selectedDiscardCardIds).sorted(),
                                eggSources: selectedEggSources,
                                youngSources: selectedYoungSources
                            )
                        )
                    )
                )
            )
            clearPlayFishSelection()
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = localizedErrorMessage(for: error)
            refresh()
        }
    }

    private func submitGameEndPlayFishFromHand() {
        guard let choice = gameEndPlayFishFromHandPaymentChoice,
              let selectedCardId,
              let selectedTargetSlot
        else {
            errorMessage = AppStrings.GameBoard.playFishFromHandPayment
            return
        }
        guard selectedTargetSlotIsAvailable else {
            errorMessage = AppStrings.GameBoard.selectSlot
            return
        }
        guard !selectedCardHasUnsupportedUICost else {
            errorMessage = AppStrings.GameBoard.costUnsupportedInUI
            return
        }
        guard hasCompleteDiscardPayment else {
            errorMessage = AppStrings.GameBoard.discardPaymentIncomplete
            return
        }
        guard selectedEggSources.count == resourceCostCount(.egg, for: selectedCard) else {
            errorMessage = AppStrings.GameBoard.eggPaymentIncomplete
            return
        }
        guard selectedYoungSources.count == resourceCostCount(.young, for: selectedCard) else {
            errorMessage = AppStrings.GameBoard.youngPaymentIncomplete
            return
        }

        resolvePendingChoice(
            choice.choiceId,
            resolution: .playFishFromHand(
                cardId: selectedCardId,
                targetSlot: selectedTargetSlot,
                payment: PlayFishPayment(
                    discardedCardIds: Array(selectedDiscardCardIds).sorted(),
                    eggSources: selectedEggSources,
                    youngSources: selectedYoungSources
                )
            )
        )
    }

    func submitDive(to diveSite: DiveActionSite) {
        guard !hasBlockingPendingChoices else {
            errorMessage = AppStrings.GameBoard.resolveCurrentRewardFirst
            return
        }
        guard !isSelectingPlayFish else {
            errorMessage = AppStrings.GameBoard.finishOrCancelPlayFish
            return
        }
        guard let activePlayerId = state.activePlayerId else {
            errorMessage = AppStrings.GameBoard.noActivePlayer
            return
        }
        guard (activePlayerState?.availableDivers ?? 0) > 0 else {
            errorMessage = AppStrings.GameBoard.diversUsedThisWeek
            return
        }
        guard let roomId = state.roomId ?? roomService.gameRoom?.roomId else {
            errorMessage = AppStrings.GameBoard.noActiveRoom
            return
        }

        do {
            _ = try roomService.submit(
                PlayerCommand(
                    commandId: nextCommandId(),
                    playerId: activePlayerId,
                    roomId: roomId,
                    payload: .dive(DiveCommand(diveSite: diveSite))
                )
            )
            errorMessage = nil
            selectedRewardTokenId = nil
            rewardSelectionMode = nil
            refresh()
        } catch {
            errorMessage = localizedErrorMessage(for: error)
            refresh()
        }
    }

    func skipPendingChoice(_ choiceId: PendingChoiceID) {
        resolvePendingChoice(choiceId, resolution: .skip)
    }

    func activateGameEndAbility(_ source: GameEndAbilitySource) {
        guard let roomId = state.roomId ?? roomService.gameRoom?.roomId else {
            errorMessage = AppStrings.GameBoard.noActiveRoom
            return
        }
        do {
            _ = try roomService.submit(
                PlayerCommand(
                    commandId: nextCommandId(),
                    playerId: source.playerId,
                    roomId: roomId,
                    payload: .activateGameEndAbility(ActivateGameEndAbilityCommand(source: source))
                )
            )
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = localizedErrorMessage(for: error)
            refresh()
        }
    }

    func finishGameEndAbilities() {
        guard let roomId = state.roomId ?? roomService.gameRoom?.roomId else {
            errorMessage = AppStrings.GameBoard.noActiveRoom
            return
        }
        let playerId = players.first?.playerId ?? state.players.first?.id ?? state.playerGameStates.keys.sorted().first ?? ""
        do {
            _ = try roomService.submit(
                PlayerCommand(
                    commandId: nextCommandId(),
                    playerId: playerId,
                    roomId: roomId,
                    payload: .finishGameEndAbilities(FinishGameEndAbilitiesCommand())
                )
            )
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = localizedErrorMessage(for: error)
            refresh()
        }
    }

    func performPendingChoiceAction(_ action: PendingChoiceAction, for choiceId: PendingChoiceID) {
        switch action {
        case .drawFish:
            let count = state.pendingChoices[choiceId].map(drawCount(for:)) ?? 1
            resolvePendingChoice(choiceId, resolution: .draw(count: count))
        case .drawFromDeck:
            resolvePendingChoice(choiceId, resolution: .drawFromDeck)
        case .skip:
            resolvePendingChoice(choiceId, resolution: .skip)
        case .chooseTarget:
            errorMessage = AppStrings.GameBoard.chooseTargetFromList
        case .chooseDrawAbilityEffect:
            resolvePendingChoice(choiceId, resolution: .chooseAbilityEffect(.drawFish(count: 1)))
        case .chooseRecoverAbilityEffect:
            resolvePendingChoice(choiceId, resolution: .chooseAbilityEffect(.recoverFromDiscardOrDraw(count: 1)))
        case .choosePlaceEggAbilityEffect:
            resolvePendingChoice(choiceId, resolution: .chooseAbilityEffect(.placeEgg(count: 1)))
        case .choosePlaceYoungAbilityEffect:
            resolvePendingChoice(choiceId, resolution: .chooseAbilityEffect(.placeYoung(count: 1)))
        case .chooseHatchEggAbilityEffect:
            resolvePendingChoice(choiceId, resolution: .chooseAbilityEffect(.hatchEgg(count: 1)))
        case .finishAbility:
            resolvePendingChoice(choiceId, resolution: .finishAbility)
        }
    }

    func resolvePendingChoice(_ choiceId: PendingChoiceID, target: OceanSlotAddress) {
        resolvePendingChoice(choiceId, resolution: .chooseTarget(target))
    }

    func resolvePendingChoice(_ choiceId: PendingChoiceID, recoverCardId: CardID) {
        resolvePendingChoice(choiceId, resolution: .recoverCard(recoverCardId))
    }

    func resolvePendingChoice(
        _ choiceId: PendingChoiceID,
        moveSource: OceanSlotAddress,
        target: OceanSlotAddress,
        kind: ResourceKind
    ) {
        resolvePendingChoice(
            choiceId,
            resolution: .moveResource(source: moveSource, target: target, kind: kind)
        )
    }

    private func resolvePendingChoice(_ choiceId: PendingChoiceID, resolution: PendingChoiceResolution) {
        guard let choice = state.pendingChoices[choiceId] else {
            errorMessage = AppStrings.GameBoard.pendingChoiceNotFound
            return
        }
        guard let roomId = state.roomId ?? roomService.gameRoom?.roomId else {
            errorMessage = AppStrings.GameBoard.noActiveRoom
            return
        }

        do {
            _ = try roomService.submit(
                PlayerCommand(
                    commandId: nextCommandId(),
                    playerId: choice.playerId,
                    roomId: roomId,
                    payload: .resolvePendingChoice(
                        ResolvePendingChoiceCommand(
                            choiceId: choiceId,
                            resolution: resolution
                        )
                    )
                )
            )
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = localizedErrorMessage(for: error)
            refresh()
        }
    }

    func eventSummary(_ event: GameEvent) -> String {
        let payload: String
        switch event.payload {
        case .roomCreated:
            payload = "房间已创建"
        case let .playerJoined(event):
            payload = "玩家加入：\(event.player.displayName)"
        case let .playerLeft(event):
            payload = "玩家离开：\(event.playerId)"
        case let .playerReadyChanged(event):
            payload = "准备状态：\(event.playerId) \(event.isReady ? "已准备" : "未准备")"
        case let .seatChanged(event):
            payload = "座位：\(event.playerId) \(event.seatIndex.rawValue)"
        case let .colorChanged(event):
            payload = "颜色：\(event.playerId) \(AppStrings.colorName(event.color))"
        case let .gameStarted(event):
            payload = "游戏开始：\(event.startingPlayerId)"
        case let .setupCompleted(event):
            payload = "设置完成：\(event.setup.playerStates.count) 名玩家"
        case let .fishPlayed(event):
            payload = "出牌：\(event.playerId) \(cardTitle(event.cardId))"
        case let .diverMoved(event):
            payload = "潜水：\(event.playerId) \(AppStrings.diveActionSiteName(event.diveSite))"
        case let .pendingChoiceCreated(choice):
            payload = "待处理选择：\(choice.playerId) \(AppStrings.pendingChoiceKindName(choice.kind))"
        case let .pendingChoiceResolved(event):
            payload = "选择已处理：\(event.playerId) \(pendingChoiceResolutionName(event.resolution))"
        case let .abilityOptionChosen(event):
            payload = "能力选择：\(event.playerId) \(event.optionId)"
        case let .turnAdvanced(event):
            payload = "行动推进：\(event.playerId) → \(event.nextPlayerId ?? "-")"
        case let .turnEnded(event):
            payload = "回合结束：\(event.playerId)"
        case let .weekEnded(event):
            let achievementSummary = event.achievementResults
                .map { result in
                    AppStrings.GameBoard.weeklyAchievementEventPlayerSummary(
                        playerName: displayName(for: result.playerId),
                        points: result.points
                    )
                }
                .joined(separator: "，")
            payload = AppStrings.GameBoard.weekEndedEventText(
                endedWeek: event.endedWeek,
                nextWeek: event.nextWeek,
                isGameEndTriggered: event.isGameEndTriggered,
                achievementSummary: achievementSummary.isEmpty ? nil : achievementSummary
            )
        case let .gameEndAbilityActivated(event):
            payload = "游戏结束能力已处理：\(displayName(for: event.source.playerId)) \(cardTitle(event.source.cardId))"
        case let .gameEnded(event):
            payload = AppStrings.GameBoard.gameEndedEventText(
                winnerNames: event.finalScoreResult.winnerPlayerIds.map(displayName)
            )
        case let .snapshotCreated(event):
            payload = "快照：\(event.snapshotSequenceNumber)"
        }

        return "#\(event.sequenceNumber) \(payload)"
    }

    private func removeInvalidSelections() {
        guard let activePlayerState else {
            clearPlayFishSelection()
            return
        }

        if let selectedCardId,
           !activePlayerState.hand.contains(selectedCardId) {
            self.selectedCardId = nil
            draggingHandCardId = nil
            selectedDiscardCardIds = []
            clearResourcePaymentSelection()
        }

        selectedDiscardCardIds = selectedDiscardCardIds.filter {
            activePlayerState.hand.contains($0) && $0 != selectedCardId
        }
        if let discardCount = discardCostCount(for: selectedCard),
           selectedDiscardCardIds.count > discardCount {
            selectedDiscardCardIds = Set(selectedDiscardCardIds.sorted().prefix(discardCount))
        }
        selectedResourcePaymentTokens = selectedResourcePaymentTokens.filter { key in
            resourceTokenCount(key.kind, at: key.address, in: activePlayerState) > key.tokenIndex
                && resourceCostCount(key.kind, for: selectedCard) > 0
        }
        trimSelectedResourcePaymentTokensToRequiredCounts()
        syncSelectedResourceSourcesFromTokens()

        if let selectedTargetSlot,
           !activePlayerState.ocean.slots.contains(where: { $0.address == selectedTargetSlot && playFishSlotPreview(for: $0).isSelectable }) {
            self.selectedTargetSlot = nil
        }
    }

    private func clearPlayFishSelection() {
        selectedCardId = nil
        selectedTargetSlot = nil
        draggingHandCardId = nil
        dragHoverSlotAddress = nil
        selectedDiscardCardIds = []
        clearResourcePaymentSelection()
    }

    private func cardTitle(_ cardId: CardID) -> String {
        if let cardName = cardsById[cardId]?.name {
            return cardName
        }
        if cardId.hasPrefix("starter-fish-") {
            return "起始鱼牌 \(cardId.replacingOccurrences(of: "starter-fish-", with: ""))"
        }
        if cardId.hasPrefix("fish-") {
            return "鱼牌 \(cardId.replacingOccurrences(of: "fish-", with: ""))"
        }
        return "鱼牌 \(cardId)"
    }

    private func cardSubtitle(_ card: Card?) -> String {
        guard let card else {
            return AppStrings.GameBoard.unknownCard
        }
        guard !card.costs.isEmpty else {
            return AppStrings.GameBoard.noCost
        }
        return card.costs.map(costText).joined(separator: "，")
    }

    private func handCardViewState(
        cardId: CardID,
        stackIndex: Int,
        canSelectCards: Bool
    ) -> HandCardViewState {
        let card = cardsById[cardId]
        let displayName = cardTitle(cardId)
        let costSummary = cardCostSummaryText(card)
        let placementSummary = cardPlacementSummaryText(card)
        let requiredDiveSite = cardRequiredDiveSiteText(card)
        let unavailableReason = handCardUnavailableReason(card, canSelectCards: canSelectCards)
        let isMainSelectedCard = selectedCardId == cardId
        let isSelectedForDiscardPayment = selectedDiscardCardIds.contains(cardId)
        let isDiscardPaymentSelectable = canSelectDiscardPaymentCard(cardId)
        let isSelected = isMainSelectedCard
        let isPlayable = canSelectCards && unavailableReason == nil
        let isPulledOutFromStack = isMainSelectedCard
        let highlightStyle: HandCardHighlightStyle
        if isMainSelectedCard {
            highlightStyle = .selected
        } else if isPlayable {
            highlightStyle = .playable
        } else {
            highlightStyle = .unavailable
        }

        return HandCardViewState(
            cardId: cardId,
            displayName: displayName,
            shortName: displayName,
            printedPoints: card?.printedPoints ?? 0,
            lengthText: card.map(cardLengthText) ?? AppStrings.GameBoard.cardLengthUnsupported,
            costSummaryText: costSummary,
            placementSummaryText: placementSummary,
            requiredDiveSiteText: requiredDiveSite,
            abilitySummaryText: cardAbilitySummaryText(card),
            cardFace: fishCardFaceViewState(cardId: cardId),
            isSelected: isSelected,
            isMainSelectedCard: isMainSelectedCard,
            isPlayable: isPlayable,
            isDiscardPaymentSelectable: isDiscardPaymentSelectable,
            isSelectedForDiscardPayment: isSelectedForDiscardPayment,
            unavailableReasonText: unavailableReason,
            highlightStyle: highlightStyle,
            compactDisplayText: "\(costSummary) · \(displayName) · \(placementSummary)",
            overlayMarkerText: isSelectedForDiscardPayment ? AppStrings.GameBoard.paymentSelectionMarker : nil,
            stackIndex: stackIndex,
            isPulledOutFromStack: isPulledOutFromStack,
            stackOffsetX: Double(stackIndex) * handStackOverlapOffsetX,
            stackOffsetY: isPulledOutFromStack ? handStackPulledOutOffsetY : handStackRestingOffsetY,
            stackZIndex: isPulledOutFromStack ? 1_000 : Double(stackIndex),
            visibleHeightRatio: isPulledOutFromStack ? 1 : 0.68,
            cardWidth: Self.fixedHandCardWidth,
            cardHeight: Self.fixedHandCardHeight,
            scale: Self.fixedHandCardScale
        )
    }

    private func cardCostSummaryText(_ card: Card?) -> String {
        guard let card else {
            return AppStrings.GameBoard.unknownCard
        }
        return card.costs.isEmpty ? AppStrings.GameBoard.noCost : card.costs.map(costText).joined(separator: "，")
    }

    private func cardLengthText(_ card: Card) -> String {
        "\(card.lengthCm) \(AppStrings.GameBoard.centimeters)"
    }

    private func cardPlacementSummaryText(_ card: Card?) -> String {
        guard let card else {
            return AppStrings.GameBoard.unknownCard
        }
        guard !card.allowedZones.isEmpty else {
            return AppStrings.GameBoard.noLimit
        }
        return card.allowedZones.map(AppStrings.oceanZoneName).joined(separator: "，")
    }

    private func cardRequiredDiveSiteText(_ card: Card?) -> String {
        guard let card else {
            return AppStrings.GameBoard.unknownCard
        }
        return card.requiredDiveSiteColor.map(AppStrings.diveSiteColorName) ?? AppStrings.GameBoard.noLimit
    }

    private func cardAbilitySummaryText(_ card: Card?) -> String {
        guard let card else {
            return AppStrings.GameBoard.unknownCard
        }
        let abilityTexts = abilityResolver.abilityDefinitions(for: card)
            .map(abilityDisplayText)
            .filter { !$0.isEmpty }
        if !abilityTexts.isEmpty {
            return abilityTexts.joined(separator: "；")
        }
        return AppStrings.GameBoard.unsupportedAbilityInUI
    }

    private func fishCardFaceViewState(cardId: CardID) -> FishCardFaceViewState {
        guard let card = resolvedCard(for: cardId) else {
            return FishCardFaceViewState(
                kind: .placeholder,
                cardId: cardId,
                displayName: AppStrings.GameBoard.cardFaceUnknownCard,
                scientificName: nil,
                printedPointsText: AppStrings.GameBoard.cardScoreUnsupported,
                lengthText: AppStrings.GameBoard.cardLengthUnsupported,
                costText: AppStrings.GameBoard.unknownCard,
                allowedZonesText: AppStrings.GameBoard.unknownCard,
                requiredDiveSiteColor: nil,
                requiredDiveSiteText: AppStrings.GameBoard.unknownCard,
                tagsText: AppStrings.GameBoard.cardFaceNoTags,
                abilityTriggerText: nil,
                abilityText: AppStrings.GameBoard.abilityUnsupported,
                costIcons: [cardIcon(assetName: "NoCost", fallbackText: "-", accessibilityText: AppStrings.GameBoard.noCost)],
                zoneIcons: [],
                tagIcons: [],
                sizeClassIcon: cardIcon(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼"),
                abilitySegments: FishCardAbilityTokenParser.parse(AppStrings.GameBoard.abilityUnsupported),
                backgroundAssetPrefix: cardBackgroundAssetPrefix(for: nil),
                abilityStripAssetPrefix: nil,
                abilityPanelStyle: .none,
                localFishImagePrefix: nil,
                aspectRatio: CardRenderMetrics.cardAspectRatio,
                isPlaceholder: true
            )
        }

        let abilityText = card.abilityText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayAbilityText = abilityText?.isEmpty == false
            ? abilityText!
            : cardAbilitySummaryText(card)
        return FishCardFaceViewState(
            kind: .fishCard,
            cardId: cardId,
            displayName: card.name,
            scientificName: card.scientificName,
            printedPointsText: "\(card.printedPoints)\(AppStrings.GameBoard.cardFacePointsSuffix)",
            lengthText: cardLengthText(card),
            costText: cardCostSummaryText(card),
            allowedZonesText: cardPlacementSummaryText(card),
            requiredDiveSiteColor: card.requiredDiveSiteColor,
            requiredDiveSiteText: cardRequiredDiveSiteText(card),
            tagsText: cardTagsText(card.tags),
            abilityTriggerText: cardAbilityTriggerText(card),
            abilityText: displayAbilityText,
            costIcons: cardCostIcons(card),
            zoneIcons: cardZoneIcons(card),
            tagIcons: cardTagIcons(card.tags),
            sizeClassIcon: cardSizeClassIcon(card),
            abilitySegments: FishCardAbilityTokenParser.parse(displayAbilityText),
            backgroundAssetPrefix: cardBackgroundAssetPrefix(for: card.requiredDiveSiteColor),
            abilityStripAssetPrefix: abilityStripAssetPrefix(for: card),
            abilityPanelStyle: abilityPanelStyle(for: card),
            localFishImagePrefix: card.visualAssetName ?? inferredFishImagePrefix(cardId: card.id),
            aspectRatio: CardRenderMetrics.cardAspectRatio,
            isPlaceholder: false
        )
    }

    private func resolvedCard(for cardId: CardID) -> Card? {
        cardIdentityResolver.card(for: cardId)
    }

    private func invalidateRoomForUnresolvableCardsIfNeeded() -> Bool {
        guard roomService.gameState.phase != .lobby && roomService.gameState.phase != .setup else {
            return false
        }

        let unresolvedCardIds = roomService.gameState.unresolvedCardIds(using: cardIdentityResolver)
        guard !unresolvedCardIds.isEmpty else {
            return false
        }

        let reason = AppStrings.Lobby.incompatibleLocalRoom
        if let invalidLocalRoomHandler = roomService as? InvalidLocalRoomHandling {
            invalidLocalRoomHandler.invalidateLocalRoomSession(reason: reason)
        } else {
            roomService.resetLocalRoomSession()
        }
        errorMessage = reason
        return true
    }

    private func fishCardFaceViewState(content: OceanSlotContent) -> FishCardFaceViewState {
        switch content {
        case .empty:
            return FishCardFaceViewState(
                kind: .empty,
                cardId: nil,
                displayName: AppStrings.GameBoard.cardFaceEmptySlot,
                scientificName: nil,
                printedPointsText: "",
                lengthText: "",
                costText: AppStrings.GameBoard.noCost,
                allowedZonesText: AppStrings.GameBoard.noLimit,
                requiredDiveSiteColor: nil,
                requiredDiveSiteText: AppStrings.GameBoard.noLimit,
                tagsText: AppStrings.GameBoard.cardFaceNoTags,
                abilityTriggerText: nil,
                abilityText: AppStrings.GameBoard.cardFaceNoAbility,
                costIcons: [cardIcon(assetName: "NoCost", fallbackText: "-", accessibilityText: AppStrings.GameBoard.noCost)],
                zoneIcons: [],
                tagIcons: [],
                sizeClassIcon: cardIcon(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼"),
                abilitySegments: FishCardAbilityTokenParser.parse(AppStrings.GameBoard.cardFaceNoAbility),
                backgroundAssetPrefix: cardBackgroundAssetPrefix(for: nil),
                abilityStripAssetPrefix: nil,
                abilityPanelStyle: .none,
                localFishImagePrefix: nil,
                aspectRatio: CardRenderMetrics.cardAspectRatio,
                isPlaceholder: true
            )
        case let .forageFish(fish):
            return FishCardFaceViewState(
                kind: .forageFish,
                cardId: nil,
                displayName: fish.name,
                scientificName: nil,
                printedPointsText: "0\(AppStrings.GameBoard.cardFacePointsSuffix)",
                lengthText: "\(fish.lengthCm) \(AppStrings.GameBoard.centimeters)",
                costText: AppStrings.GameBoard.noCost,
                allowedZonesText: AppStrings.GameBoard.noLimit,
                requiredDiveSiteColor: nil,
                requiredDiveSiteText: AppStrings.GameBoard.noLimit,
                tagsText: AppStrings.GameBoard.forageFish,
                abilityTriggerText: nil,
                abilityText: AppStrings.GameBoard.cardFaceNoAbility,
                costIcons: [cardIcon(assetName: "NoCost", fallbackText: "-", accessibilityText: AppStrings.GameBoard.noCost)],
                zoneIcons: [],
                tagIcons: [],
                sizeClassIcon: cardSizeClassIcon(lengthCm: fish.lengthCm),
                abilitySegments: FishCardAbilityTokenParser.parse(AppStrings.GameBoard.cardFaceNoAbility),
                backgroundAssetPrefix: cardBackgroundAssetPrefix(for: nil),
                abilityStripAssetPrefix: nil,
                abilityPanelStyle: .none,
                localFishImagePrefix: nil,
                aspectRatio: CardRenderMetrics.cardAspectRatio,
                isPlaceholder: false
            )
        case let .fishCard(cardId):
            return fishCardFaceViewState(cardId: cardId)
        }
    }

    private func cardBackgroundAssetPrefix(for color: DiveSiteColor?) -> String {
        switch color {
        case .blue:
            return "blue"
        case .purple:
            return "purple"
        case .green:
            return "green"
        case nil:
            return "base"
        }
    }

    private func abilityStripAssetPrefix(for card: Card) -> String? {
        guard let trigger = cardAbilityTriggerText(card) else {
            return nil
        }
        if trigger == AppStrings.GameBoard.abilityTriggerIfActivated {
            return "IfActivated"
        }
        if trigger == AppStrings.GameBoard.abilityTriggerGameEnd {
            return "GameEnd"
        }
        return nil
    }

    private func abilityPanelStyle(for card: Card) -> FishCardAbilityPanelStyle {
        guard let trigger = cardAbilityTriggerText(card) else {
            return .none
        }
        if trigger == AppStrings.GameBoard.abilityTriggerIfActivated {
            return .tanBrush
        }
        if trigger == AppStrings.GameBoard.abilityTriggerGameEnd {
            return .yellowBrush
        }
        return .none
    }

    private func cardCostIcons(_ card: Card) -> [FishCardFaceIconViewState] {
        let icons = card.costs.flatMap { cost -> [FishCardFaceIconViewState] in
            switch cost {
            case let .discardCards(count):
                return repeatedIcon(
                    assetName: "FishFromHand",
                    fallbackText: "手牌",
                    accessibilityText: AppStrings.GameBoard.discardPayment,
                    count: count
                )
            case let .resource(kind, count):
                return repeatedIcon(for: kind, count: count)
            case let .coverShorterFish(count):
                return repeatedIcon(
                    assetName: "ConsumeFish1",
                    fallbackText: "吞",
                    accessibilityText: AppStrings.GameBoard.canCoverShorterFish,
                    count: count
                )
            }
        }
        if icons.isEmpty {
            return [cardIcon(assetName: "NoCost", fallbackText: "-", accessibilityText: AppStrings.GameBoard.noCost)]
        }
        return icons
    }

    private func repeatedIcon(for kind: ResourceKind, count: Int) -> [FishCardFaceIconViewState] {
        if kind == .egg {
            return repeatedIcon(assetName: "FishEgg", fallbackText: "卵", accessibilityText: resourceName(kind), count: count)
        }
        if kind == .young {
            return repeatedIcon(assetName: "YoungFish", fallbackText: "幼", accessibilityText: resourceName(kind), count: count)
        }
        if kind == .school {
            return repeatedIcon(assetName: "SchoolFish", fallbackText: "群", accessibilityText: resourceName(kind), count: count)
        }
        return repeatedIcon(assetName: "NoCost", fallbackText: resourceName(kind), accessibilityText: resourceName(kind), count: count)
    }

    private func repeatedIcon(
        assetName: String,
        fallbackText: String,
        accessibilityText: String,
        count: Int
    ) -> [FishCardFaceIconViewState] {
        guard count > 0 else {
            return []
        }
        return Array(repeating: cardIcon(assetName: assetName, fallbackText: fallbackText, accessibilityText: accessibilityText), count: count)
    }

    private func cardZoneIcons(_ card: Card) -> [FishCardFaceIconViewState] {
        card.allowedZones.map { zone in
            switch zone {
            case .sunlit:
                return cardIcon(assetName: "Sun", fallbackText: "阳", accessibilityText: AppStrings.oceanZoneName(zone))
            case .twilight:
                return cardIcon(assetName: "Dusk", fallbackText: "暮", accessibilityText: AppStrings.oceanZoneName(zone))
            case .midnight:
                return cardIcon(assetName: "Night", fallbackText: "深", accessibilityText: AppStrings.oceanZoneName(zone))
            }
        }
    }

    private func cardTagIcons(_ tags: [CardTag]) -> [FishCardFaceIconViewState] {
        tags.flatMap { tag -> [FishCardFaceIconViewState] in
            let icon = cardTagIcon(tag)
            return Array(repeating: icon, count: max(tag.count, 1))
        }
    }

    private func cardTagIcon(_ tag: CardTag) -> FishCardFaceIconViewState {
        switch tag.kind {
        case "predator":
            return cardIcon(assetName: "Predator", fallbackText: "捕", accessibilityText: cardTagName(tag.kind))
        case "bioluminescent":
            return cardIcon(assetName: "Bioluminescent", fallbackText: "光", accessibilityText: cardTagName(tag.kind))
        case "camouflage":
            return cardIcon(assetName: "Camouflage", fallbackText: "隐", accessibilityText: cardTagName(tag.kind))
        case "electric":
            return cardIcon(assetName: "Electric", fallbackText: "电", accessibilityText: cardTagName(tag.kind))
        case "venomous":
            return cardIcon(assetName: "Venomous", fallbackText: "毒", accessibilityText: cardTagName(tag.kind))
        default:
            return cardIcon(assetName: "NoCost", fallbackText: cardTagName(tag.kind), accessibilityText: cardTagName(tag.kind))
        }
    }

    private func cardIcon(
        assetName: String,
        fallbackText: String,
        accessibilityText: String
    ) -> FishCardFaceIconViewState {
        FishCardFaceIconViewState(
            assetName: assetName,
            fallbackText: fallbackText,
            accessibilityText: accessibilityText
        )
    }

    private func cardSizeClassIcon(_ card: Card) -> FishCardFaceIconViewState {
        cardSizeClassIcon(lengthCm: card.lengthCm)
    }

    private func cardSizeClassIcon(lengthCm: Int) -> FishCardFaceIconViewState {
        switch inferredSizeClass(lengthCm: lengthCm) {
        case "smallDraft":
            return cardIcon(assetName: "FishLengthSmall", fallbackText: "小", accessibilityText: "小型鱼")
        case "largeDraft":
            return cardIcon(assetName: "FishLengthLarge", fallbackText: "大", accessibilityText: "大型鱼")
        case "mediumDraft":
            return cardIcon(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼")
        default:
            return cardIcon(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼")
        }
    }

    private func inferredSizeClass(lengthCm: Int) -> String {
        if lengthCm < 50 {
            return "smallDraft"
        }
        if lengthCm < 150 {
            return "mediumDraft"
        }
        return "largeDraft"
    }

    private func cardTagsText(_ tags: [CardTag]) -> String {
        guard !tags.isEmpty else {
            return AppStrings.GameBoard.cardFaceNoTags
        }
        return tags
            .map { "\($0.count) \(cardTagName($0.kind))" }
            .joined(separator: "，")
    }

    private func cardTagName(_ kind: String) -> String {
        switch kind {
        case "predator":
            return "捕食者"
        case "bioluminescent":
            return "生物发光"
        case "camouflage":
            return "伪装"
        case "electric":
            return "放电"
        case "venomous":
            return "有毒"
        case "schooling":
            return "成群"
        case "reef":
            return "珊瑚礁"
        case "shark":
            return "鲨鱼"
        case "plankton":
            return "浮游生物"
        default:
            return kind
        }
    }

    private func cardAbilityTriggerText(_ card: Card) -> String? {
        let definitions = abilityResolver.abilityDefinitions(for: card)
        if let supportedTrigger = definitions.first(where: { !abilityIsUnsupported($0) })?.trigger {
            return abilityTriggerText(supportedTrigger)
        }
        return card.abilityIds.compactMap(inferredAbilityTriggerText).first
    }

    private func inferredAbilityTriggerText(_ abilityId: AbilityID) -> String? {
        let lowercased = abilityId.lowercased()
        if lowercased.contains("whenplayed") || lowercased.contains("when_played") {
            return AppStrings.GameBoard.abilityTriggerWhenPlayed
        }
        if lowercased.contains("gameend") || lowercased.contains("game_end") {
            return AppStrings.GameBoard.abilityTriggerGameEnd
        }
        if lowercased.contains("ifactivated") || lowercased.contains("if_activated") {
            return AppStrings.GameBoard.abilityTriggerIfActivated
        }
        return nil
    }

    private func abilityTriggerText(_ trigger: AbilityTrigger) -> String {
        switch trigger {
        case .whenPlayed:
            return AppStrings.GameBoard.abilityTriggerWhenPlayed
        case .ifActivated:
            return AppStrings.GameBoard.abilityTriggerIfActivated
        case .gameEnd:
            return AppStrings.GameBoard.abilityTriggerGameEnd
        }
    }

    private func inferredFishImagePrefix(cardId: CardID) -> String? {
        let numberText: String?
        if let trailing = cardId.split(separator: ".").last {
            numberText = String(trailing)
        } else {
            numberText = nil
        }

        guard let numberText,
              let sourceId = Int(numberText)
        else {
            return nil
        }
        return "\(sourceId)"
    }

    private func handCardUnavailableReason(_ card: Card?, canSelectCards: Bool) -> String? {
        if let blockingMessage = handBlockingMessage {
            return blockingMessage
        }
        guard canSelectCards else {
            return AppStrings.GameBoard.notPlayable
        }
        guard let card else {
            return AppStrings.GameBoard.unknownCard
        }
        if case let .consumeFishHandCard(choiceId, _) = rewardSelectionMode {
            guard let choice = state.pendingChoices[choiceId] else {
                return AppStrings.GameBoard.consumeFishHandCard
            }
            return consumeFishHandCardIsLegal(card.id, for: choice)
                ? nil
                : AppStrings.GameBoard.consumeFishMustBeShorter
        }
        if case let .freePlayHandCard(choiceId, _) = rewardSelectionMode {
            guard let choice = state.pendingChoices[choiceId] else {
                return AppStrings.GameBoard.playFishForFreeHandCard
            }
            return freePlayHandCardIsLegal(card.id, for: choice)
                ? nil
                : AppStrings.GameBoard.playFishForFreeFilterMismatch
        }
        if case let .playFishFromHandCard(choiceId, _) = rewardSelectionMode {
            guard let choice = state.pendingChoices[choiceId] else {
                return AppStrings.GameBoard.playFishFromHandHandCard
            }
            return playFishFromHandCardIsLegal(card.id, for: choice)
                ? nil
                : AppStrings.GameBoard.playFishForFreeFilterMismatch
        }
        if cardHasUnsupportedRequirementInUI(card) {
            return AppStrings.GameBoard.unsupportedRequirementInUI
        }
        if cardHasUnsupportedCostInUI(card) {
            return AppStrings.GameBoard.costUnsupportedInUI
        }
        if !hasEnoughDiscardPaymentCandidates(for: card) {
            return AppStrings.GameBoard.discardPaymentInsufficient
        }
        if !hasEnoughResourcePaymentCandidates(for: card) {
            return AppStrings.GameBoard.insufficientPaymentSources
        }
        if !hasAvailableTargetSlot(for: card) {
            return AppStrings.GameBoard.noPlayableSlot
        }
        return nil
    }

    private func hasAvailableTargetSlot(for card: Card) -> Bool {
        guard let activePlayerState else {
            return false
        }
        return activePlayerState.ocean.slots.contains { slot in
            playFishSlotPreview(for: slot, card: card).isSelectable
        }
    }

    private func hasEnoughDiscardPaymentCandidates(for card: Card) -> Bool {
        guard let discardCount = discardCostCount(for: card) else {
            return true
        }
        return max((activePlayerState?.hand.count ?? 0) - 1, 0) >= discardCount
    }

    private func hasEnoughResourcePaymentCandidates(for card: Card) -> Bool {
        resourcePaymentKinds.allSatisfy { kind in
            resourceTokenCapacity(for: kind) >= resourceCostCount(kind, for: card)
        }
    }

    private func resourceTokenCapacity(for kind: ResourceKind) -> Int {
        guard let activePlayerState else {
            return 0
        }
        return activePlayerState.ocean.slots.reduce(0) { partialResult, slot in
            partialResult + resourceTokenCount(kind, in: slot)
        }
    }

    private func playFishSlotPreview(for slot: OceanSlot) -> PlayFishSlotPreview {
        playFishSlotPreview(for: slot, card: selectedCard)
    }

    private func playFishSlotPreview(for slot: OceanSlot, card: Card?) -> PlayFishSlotPreview {
        guard let card else {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .noSelectedCard,
                message: AppStrings.GameBoard.slotSelectFishFirst
            )
        }

        if cardHasUnsupportedRequirementInUI(card) {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .unsupportedRequirement,
                message: AppStrings.GameBoard.unsupportedRequirementInUI
            )
        }

        if cardHasCoralRequirement(card), slot.address.zone != .sunlit {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .reefFishMustBeSunlit,
                message: AppStrings.GameBoard.reefFishMustBeSunlit
            )
        }

        guard card.allowedZones.contains(slot.address.zone) else {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .zoneMismatch,
                message: AppStrings.GameBoard.slotZoneMismatch
            )
        }

        if let requiredDiveSiteColor = card.requiredDiveSiteColor,
           slot.diveSiteColor != requiredDiveSiteColor {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .diveSiteMismatch,
                message: AppStrings.GameBoard.slotDiveSiteMismatch
            )
        }

        if let coralPreview = coralRequirementPreview(for: card, targetSlot: slot) {
            return coralPreview
        }

        if let existingLength = visibleFishLength(in: slot.content) {
            if card.lengthCm <= existingLength {
                return PlayFishSlotPreview(
                    availability: .unavailable,
                    unavailableReason: .coverLengthTooShort,
                    message: AppStrings.GameBoard.cannotCoverLongerOrSameFish
                )
            }
        } else if card.requiresCoveringShorterFish {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .mustCoverShorterFish,
                message: AppStrings.GameBoard.mustCoverShorterFish
            )
        }

        return PlayFishSlotPreview(
            availability: .available,
            unavailableReason: nil,
            message: slot.content == .empty ? AppStrings.GameBoard.slotAvailable : AppStrings.GameBoard.canCoverShorterFish
        )
    }

    private func visibleFishLength(in content: OceanSlotContent) -> Int? {
        switch content {
        case .empty:
            return nil
        case let .forageFish(fish):
            return fish.lengthCm
        case let .fishCard(cardId):
            return cardsById[cardId]?.lengthCm
        }
    }

    private func coralRequirementPreview(for card: Card, targetSlot slot: OceanSlot) -> PlayFishSlotPreview? {
        for requirement in card.requirements.compactMap(\.coralRequirement) {
            if requirement.diveSite != .any,
               requirement.diveSite.rawValue != slot.address.diveSite.rawValue {
                return PlayFishSlotPreview(
                    availability: .unavailable,
                    unavailableReason: .diveSiteMismatch,
                    message: AppStrings.GameBoard.slotDiveSiteMismatch
                )
            }
            guard let reef = activePlayerState?.ocean.coralReefs.first(where: { $0.diveSite == slot.address.diveSite }) else {
                return PlayFishSlotPreview(
                    availability: .unavailable,
                    unavailableReason: .coralReefMissing,
                    message: AppStrings.GameBoard.coralReefMissing
                )
            }
            guard reef.coralCount >= requirement.count else {
                return PlayFishSlotPreview(
                    availability: .unavailable,
                    unavailableReason: .coralInsufficient,
                    message: AppStrings.GameBoard.coralInsufficient
                )
            }
        }
        return nil
    }

    private func cardHasCoralRequirement(_ card: Card) -> Bool {
        card.requirements.contains { $0.coralRequirement != nil }
    }

    private func slotContentText(_ content: OceanSlotContent) -> String {
        switch content {
        case .empty:
            return AppStrings.GameBoard.empty
        case let .forageFish(fish):
            return "\(AppStrings.GameBoard.forageFish)：\(fish.name)"
        case let .fishCard(cardId):
            return "\(AppStrings.GameBoard.occupied)：\(cardTitle(cardId))"
        }
    }

    private func costText(_ cost: Cost) -> String {
        switch cost {
        case let .discardCards(count):
            return "弃 \(count) 张牌"
        case let .resource(kind, count):
            return "\(resourceName(kind)) \(count)"
        case let .coverShorterFish(count):
            return "覆盖短鱼 \(count)"
        }
    }

    private func resourceName(_ kind: ResourceKind) -> String {
        if kind == .egg {
            return "鱼卵"
        }
        if kind == .young {
            return "幼鱼"
        }
        if kind == .school {
            return "鱼群"
        }
        return kind.rawValue
    }

    private func resourceIconText(_ kind: ResourceKind) -> String {
        if kind == .egg {
            return "卵"
        }
        if kind == .young {
            return "幼"
        }
        if kind == .school {
            return "群"
        }
        return "?"
    }

    private func pendingChoiceSubtitle(_ choice: PendingChoice) -> String {
        let playerName = players.first(where: { $0.playerId == choice.playerId })?.displayName ?? choice.playerId
        let optionalText = choice.isOptional ? AppStrings.GameBoard.optionalChoice : AppStrings.GameBoard.requiredChoice
        var parts = [
            "\(AppStrings.GameBoard.pendingChoicePlayer)：\(playerName)",
            "\(AppStrings.GameBoard.pendingChoiceSource)：\(AppStrings.pendingChoiceSourceName(choice.source))",
            "\(AppStrings.GameBoard.pendingChoiceStatus)：\(AppStrings.GameBoard.pendingChoiceWaiting)",
            optionalText
        ]
        if let progress = choice.allPlayersProgress {
            let remainingNames = progress.remainingPlayerIds.map { playerId in
                players.first(where: { $0.playerId == playerId })?.displayName ?? playerId
            }
            let remainingText = remainingNames.isEmpty
                ? ""
                : "，\(AppStrings.GameBoard.allPlayersRemaining)：\(remainingNames.joined(separator: "、"))"
            parts.append("\(AppStrings.GameBoard.allPlayersChoice)：当前为 \(playerName) 处理\(remainingText)")
        }
        if let progress = choice.conditionalBonusProgress {
            let stepText = progress.phase == .base
                ? AppStrings.GameBoard.conditionalBonusBaseStep
                : AppStrings.GameBoard.conditionalBonusBonusStep
            let requirementText = AppStrings.GameBoard.coloredCoralRequirement(
                coralColorName(progress.requirement.coralColor),
                count: progress.requirement.count
            )
            parts.append("\(stepText)：\(requirementText)")
        }
        return parts.joined(separator: "，")
    }

    private func coralColorName(_ diveSite: DiveSite) -> String {
        switch diveSite {
        case .blue:
            return "蓝色"
        case .purple:
            return "紫色"
        case .green:
            return "绿色"
        }
    }

    private func pendingChoiceTitle(_ choice: PendingChoice) -> String {
        guard case let .fishAbility(cardId) = choice.source else {
            return AppStrings.pendingChoiceKindName(choice.kind)
        }
        return AppStrings.GameBoard.triggeringFishAbility(cardName: cardTitle(cardId))
    }

    private func compoundAbilityProgressLines(for choice: PendingChoice) -> [String] {
        guard let progress = choice.compoundAbilityProgress else {
            return []
        }
        return [
            abilityProgressLine(
                title: AppStrings.GameBoard.placeEggAbilityAction,
                kind: .placeEgg(count: 1),
                progress: progress
            ),
            abilityProgressLine(
                title: AppStrings.GameBoard.placeYoungAbilityAction,
                kind: .placeYoung(count: 1),
                progress: progress
            ),
            abilityProgressLine(
                title: AppStrings.GameBoard.hatchEggAbilityAction,
                kind: .hatchEgg(count: 1),
                progress: progress
            ),
            abilityProgressLine(
                title: AppStrings.GameBoard.scatterSchool,
                kind: .scatterSchool(count: 1),
                progress: progress
            ),
            abilityProgressLine(
                title: AppStrings.GameBoard.consumeFishFromHand,
                kind: .consumeFishFromHand(count: 1),
                progress: progress
            ),
            abilityProgressLine(
                title: AppStrings.GameBoard.playFishForFree,
                kind: .playFishForFree(filter: .any, placement: .any, sourceCondition: .none, count: 1),
                progress: progress
            )
        ].compactMap { $0 }
    }

    private func pendingEffectSetProgressLines(for choice: PendingChoice) -> [String] {
        let effectSet = choice.v2PendingEffectSet
        guard !effectSet.available.isEmpty || !effectSet.completed.isEmpty || !effectSet.skipped.isEmpty else {
            return []
        }
        var lines: [String] = []
        if let targetPlayerId = effectSet.targetPlayerId,
           choice.allPlayersProgress != nil {
            lines.append("\(AppStrings.GameBoard.pendingChoicePlayer)：\(displayName(for: targetPlayerId))")
        }
        lines.append(contentsOf: [
            "\(AppStrings.GameBoard.abilityEngineV2Available)：\(effectSet.available.count)",
            "\(AppStrings.GameBoard.abilityEngineV2Completed)：\(effectSet.completed.count)",
            "\(AppStrings.GameBoard.abilityEngineV2Skipped)：\(effectSet.skipped.count)"
        ])
        return lines
    }

    private func abilityProgressLine(
        title: String,
        kind: AbilityEffectUnit,
        progress: CompoundAbilityProgress
    ) -> String? {
        let completed = abilityEffectCount(kind, in: progress.completedEffects)
        let remaining = abilityEffectCount(kind, in: progress.remainingEffects)
        let total = completed + remaining
        guard total > 0 else {
            return nil
        }
        return AppStrings.GameBoard.compoundAbilityProgressText(
            title: title,
            completedCount: completed,
            totalCount: total
        )
    }

    private func abilityEffectCount(_ kind: AbilityEffectUnit, in effects: [AbilityEffectUnit]) -> Int {
        effects
            .filter { abilityEffectKey($0) == abilityEffectKey(kind) }
            .map(abilityEffectCount)
            .reduce(0, +)
    }

    private func abilityEffectCount(_ effect: AbilityEffectUnit) -> Int {
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

    private func selectableCompoundEffects(for choice: PendingChoice) -> [AbilityEffectUnit] {
        guard let progress = choice.compoundAbilityProgress else {
            return []
        }
        let legalEffects = progress.remainingEffects
            .map(normalizedSingleEffect)
            .filter { compoundEffectIsCurrentlySelectable($0, choice: choice, progress: progress) }

        guard !progress.canResolveInAnyOrder else {
            return legalEffects
        }
        return legalEffects.first.map { [$0] } ?? []
    }

    private func normalizedSingleEffect(_ effect: AbilityEffectUnit) -> AbilityEffectUnit {
        switch effect {
        case .drawFish:
            return .drawFish(count: 1)
        case .placeEgg:
            return .placeEgg(count: 1)
        case .placeYoung:
            return .placeYoung(count: 1)
        case .hatchEgg:
            return .hatchEgg(count: 1)
        case .moveYoungOrSchool:
            return .moveYoungOrSchool(count: 1)
        case .recoverFromDiscardOrDraw:
            return .recoverFromDiscardOrDraw(count: 1)
        case let .gameEndScore(condition, points):
            return .gameEndScore(condition: condition, points: points)
        case let .placeEggOnMatchingFish(filter, mode):
            return .placeEggOnMatchingFish(filter: filter, mode: mode)
        case let .playFishFromHand(filter, placement, costMode):
            return .playFishFromHand(filter: filter, placement: placement, costMode: costMode)
        case let .gainCoral(selector, _):
            return .gainCoral(selector: selector, count: 1)
        case .scatterSchool:
            return .scatterSchool(count: 1)
        case .consumeFishFromHand:
            return .consumeFishFromHand(count: 1)
        case let .playFishForFree(filter, placement, sourceCondition, _):
            return .playFishForFree(
                filter: filter,
                placement: placement,
                sourceCondition: sourceCondition,
                count: 1
            )
        case .unsupported:
            return .unsupported
        }
    }

    private func abilityEffectKey(_ effect: AbilityEffectUnit) -> String {
        switch effect {
        case .drawFish:
            return "drawFish"
        case .placeEgg:
            return "placeEgg"
        case .placeYoung:
            return "placeYoung"
        case .hatchEgg:
            return "hatchEgg"
        case .moveYoungOrSchool:
            return "moveYoungOrSchool"
        case .recoverFromDiscardOrDraw:
            return "recoverFromDiscardOrDraw"
        case .gameEndScore:
            return "gameEndScore"
        case .placeEggOnMatchingFish:
            return "placeEggOnMatchingFish"
        case .playFishFromHand:
            return "playFishFromHand"
        case let .gainCoral(selector, _):
            return "gainCoral-\(selector.rawValue)"
        case .scatterSchool:
            return "scatterSchool"
        case .consumeFishFromHand:
            return "consumeFishFromHand"
        case let .playFishForFree(filter, placement, sourceCondition, _):
            return "playFishForFree-\(freePlayFilterKey(filter))-\(placementConstraintKey(placement))-\(freePlaySourceConditionKey(sourceCondition))"
        case .unsupported:
            return "unsupported"
        }
    }

    private func freePlayFilterKey(_ filter: FreePlayFishFilter) -> String {
        switch filter {
        case .any:
            return "any"
        case let .tag(kind):
            return "tag-\(kind)"
        case let .lengthBucket(bucket):
            return "length-\(bucket.rawValue)"
        case let .unsupported(value):
            return "unsupported-\(value)"
        }
    }

    private func placementConstraintKey(_ placement: FishPlacementConstraint) -> String {
        switch placement {
        case .any:
            return "any"
        case .topRow:
            return "topRow"
        case .bottomRow:
            return "bottomRow"
        case .sunlight:
            return "sunlight"
        case let .diveSite(diveSite):
            return "diveSite-\(diveSite.rawValue)"
        case let .diveSiteWithCoralAtLeast(count):
            return "diveSiteCoralAtLeast-\(count)"
        case .sameDiveSiteAsSource:
            return "sameDiveSiteAsSource"
        }
    }

    private func freePlaySourceConditionKey(_ condition: FreePlaySourceCondition) -> String {
        switch condition {
        case .none:
            return "none"
        case .sourceDiveSiteHasNoCoral:
            return "sourceDiveSiteHasNoCoral"
        }
    }

    private func compoundEffectIsCurrentlySelectable(
        _ effect: AbilityEffectUnit,
        choice: PendingChoice,
        progress: CompoundAbilityProgress
    ) -> Bool {
        guard let playerState = state.playerGameStates[progress.playerId] else {
            return false
        }

        switch effect {
        case .drawFish:
            return !state.deckState.fishDrawPile.isEmpty
        case .recoverFromDiscardOrDraw:
            return !playerState.discardPile.isEmpty || !state.deckState.fishDrawPile.isEmpty
        case .placeEgg:
            return playerState.ocean.slots.contains { $0.content.hasFish && resourceAmount(.egg, in: $0) == 0 }
        case .placeYoung:
            return !playerState.ocean.slots.isEmpty
        case .hatchEgg:
            return playerState.ocean.slots.contains { resourceAmount(.egg, in: $0) > 0 }
        case .moveYoungOrSchool:
            return hasAnyLegalMoveYoungOrSchool(playerState: playerState)
        case let .gainCoral(selector, _):
            return hasAnyLegalCoralGain(selector: selector, playerState: playerState)
        case .scatterSchool:
            return !playerState.ocean.slots.isEmpty
        case .consumeFishFromHand:
            return hasAnyLegalConsumeFishFromHand(playerState: playerState)
        case .playFishFromHand:
            return false
        case .placeEggOnMatchingFish:
            return false
        case .gameEndScore:
            return false
        case .playFishForFree:
            return hasAnyLegalPlayFishForFree(choice: choice, playerState: playerState)
        case .unsupported:
            return false
        }
    }

    private func canResolvePendingChoice(_ choice: PendingChoice) -> Bool {
        state.activePlayerId == choice.playerId
            || (state.phase == .endGamePending && state.pendingChoices[choice.choiceId] != nil)
    }

    private func drawCount(for choice: PendingChoice) -> Int {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .drawFish(count) = effect else {
            return 1
        }
        return count
    }

    private func pendingChoiceActionButtons(for choice: PendingChoice) -> [PendingChoiceActionViewData] {
        var actions = pendingEffectSetActionButtons(for: choice)
        let canResolve = canResolvePendingChoice(choice)

        if actions.isEmpty {
            actions.append(contentsOf: legacyPendingChoiceActionButtons(for: choice, canResolve: canResolve))
        }

        if choice.kind == .compoundAbility {
            actions.append(
                PendingChoiceActionViewData(
                    choiceId: choice.choiceId,
                    action: .finishAbility,
                    title: AppStrings.GameBoard.finishAbility,
                    isEnabled: canResolve && choice.isOptional,
                    effectNodeId: nil
                )
            )
        }

        if choice.isOptional {
            actions.append(
                PendingChoiceActionViewData(
                    choiceId: choice.choiceId,
                    action: .skip,
                    title: AppStrings.GameBoard.skipChoice,
                    isEnabled: canResolve,
                    effectNodeId: nil
                )
            )
        }

        return actions
    }

    private func pendingEffectSetActionButtons(for choice: PendingChoice) -> [PendingChoiceActionViewData] {
        let canResolve = canResolvePendingChoice(choice)
        return pendingEffectActionChoices(for: choice).map { actionChoice in
            PendingChoiceActionViewData(
                choiceId: choice.choiceId,
                action: actionChoice.action,
                title: actionChoice.title,
                isEnabled: canResolve,
                effectNodeId: actionChoice.effectNodeId
            )
        }
    }

    private func pendingEffectActionChoices(for choice: PendingChoice) -> [PendingEffectActionChoice] {
        choice.v2PendingEffectSet.available.compactMap { node in
            pendingEffectActionChoice(for: node, choice: choice)
        }
    }

    private func pendingEffectActionChoice(
        for node: EffectNode,
        choice: PendingChoice
    ) -> PendingEffectActionChoice? {
        if choice.kind == .compoundAbility,
           let progress = choice.compoundAbilityProgress,
           !compoundEffectIsCurrentlySelectable(node.effect, choice: choice, progress: progress) {
            return nil
        }
        switch node.effect {
        case let .drawFish(count):
            return PendingEffectActionChoice(
                effectNodeId: node.id,
                action: choice.kind == .compoundAbility ? .chooseDrawAbilityEffect : .drawFish,
                title: AppStrings.GameBoard.drawFishCard(count: count)
            )
        case .recoverFromDiscardOrDraw:
            if choice.kind == .compoundAbility {
                return PendingEffectActionChoice(
                    effectNodeId: node.id,
                    action: .chooseRecoverAbilityEffect,
                    title: AppStrings.GameBoard.recoverOneFromDiscard
                )
            }
            guard state.playerGameStates[choice.playerId]?.discardPile.isEmpty == true else {
                return nil
            }
            return PendingEffectActionChoice(
                effectNodeId: node.id,
                action: .drawFromDeck,
                title: AppStrings.GameBoard.drawOneFishCard
            )
        case .placeEgg:
            guard choice.kind == .compoundAbility else {
                return nil
            }
            return PendingEffectActionChoice(
                effectNodeId: node.id,
                action: .choosePlaceEggAbilityEffect,
                title: AppStrings.GameBoard.placeEggAbilityAction
            )
        case .placeYoung:
            guard choice.kind == .compoundAbility else {
                return nil
            }
            return PendingEffectActionChoice(
                effectNodeId: node.id,
                action: .choosePlaceYoungAbilityEffect,
                title: AppStrings.GameBoard.placeYoungAbilityAction
            )
        case .hatchEgg:
            guard choice.kind == .compoundAbility else {
                return nil
            }
            return PendingEffectActionChoice(
                effectNodeId: node.id,
                action: .chooseHatchEggAbilityEffect,
                title: AppStrings.GameBoard.hatchEggAbilityAction
            )
        case .moveYoungOrSchool,
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

    private func legacyPendingChoiceActionButtons(
        for choice: PendingChoice,
        canResolve: Bool
    ) -> [PendingChoiceActionViewData] {
        var actions: [PendingChoiceActionViewData] = []

        switch choice.kind {
        case .drawFish:
            let count = drawCount(for: choice)
            actions.append(
                PendingChoiceActionViewData(
                    choiceId: choice.choiceId,
                    action: .drawFish,
                    title: AppStrings.GameBoard.drawFishCard(count: count),
                    isEnabled: canResolve
                )
            )
        case .recoverFromDiscardOrDraw:
            if state.playerGameStates[choice.playerId]?.discardPile.isEmpty == true {
                actions.append(
                    PendingChoiceActionViewData(
                        choiceId: choice.choiceId,
                        action: .drawFromDeck,
                        title: AppStrings.GameBoard.drawOneFishCard,
                        isEnabled: canResolve && !state.deckState.fishDrawPile.isEmpty
                    )
                )
            }
        case .placeEgg,
             .placeYoung,
             .placeEggOnMatchingFish,
             .hatchEgg,
             .moveYoungOrSchool,
             .gainCoral,
             .scatterSchool,
             .consumeFishFromHand,
             .playFishForFree,
             .playFishFromHand:
            break
        case .compoundAbility:
            if choice.compoundAbilityProgress != nil {
                let selectableEffects = selectableCompoundEffects(for: choice)
                if abilityEffectCount(.placeEgg(count: 1), in: selectableEffects) > 0 {
                    actions.append(
                        PendingChoiceActionViewData(
                            choiceId: choice.choiceId,
                            action: .choosePlaceEggAbilityEffect,
                            title: AppStrings.GameBoard.placeEggAbilityAction,
                            isEnabled: canResolve
                        )
                    )
                }
                if abilityEffectCount(.placeYoung(count: 1), in: selectableEffects) > 0 {
                    actions.append(
                        PendingChoiceActionViewData(
                            choiceId: choice.choiceId,
                            action: .choosePlaceYoungAbilityEffect,
                            title: AppStrings.GameBoard.placeYoungAbilityAction,
                            isEnabled: canResolve
                        )
                    )
                }
                if abilityEffectCount(.hatchEgg(count: 1), in: selectableEffects) > 0 {
                    actions.append(
                        PendingChoiceActionViewData(
                            choiceId: choice.choiceId,
                            action: .chooseHatchEggAbilityEffect,
                            title: AppStrings.GameBoard.hatchEggAbilityAction,
                            isEnabled: canResolve
                        )
                    )
                }
            }
        case .bottomBonus,
             .placeholder,
             .unsupported:
            actions.append(
                PendingChoiceActionViewData(
                    choiceId: choice.choiceId,
                    action: .chooseTarget,
                    title: AppStrings.GameBoard.unsupportedSkippableChoice,
                    isEnabled: false
                )
            )
        }

        return actions
    }

    private func rewardTokenEntries(
        for choice: PendingChoice
    ) -> [(token: RewardTokenViewState, action: RewardTokenAction)] {
        let canResolve = canResolvePendingChoice(choice)
        switch choice.kind {
        case .drawFish:
            let count = drawCount(for: choice)
            let tokenId = "\(choice.choiceId)-drawFish"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .drawFish,
                    title: AppStrings.GameBoard.drawFishCard(count: count),
                    subtitle: rewardSourceText(for: choice),
                    iconText: "牌",
                    symbolName: "rectangle.stack",
                    isSelectable: canResolve
                ),
                .direct(choiceId: choice.choiceId, resolution: .draw(count: count))
            )]
        case .recoverFromDiscardOrDraw:
            guard let playerState = state.playerGameStates[choice.playerId] else {
                return []
            }
            if playerState.discardPile.isEmpty {
                let tokenId = "\(choice.choiceId)-drawFromDeck"
                return [(
                    rewardToken(
                        id: tokenId,
                        kind: .recoverFromDiscardOrDraw,
                        title: AppStrings.GameBoard.drawOneFishCard,
                        subtitle: AppStrings.GameBoard.discardPileEmptyDrawAlternative,
                        iconText: "牌",
                        symbolName: "rectangle.stack",
                        isSelectable: canResolve && !state.deckState.fishDrawPile.isEmpty,
                        unavailableReasonText: state.deckState.fishDrawPile.isEmpty ? AppStrings.GameBoard.fishDrawPileEmpty : nil
                    ),
                    .direct(choiceId: choice.choiceId, resolution: .drawFromDeck)
                )]
            }
            return playerState.discardPile.map { cardId in
                let tokenId = "\(choice.choiceId)-recover-\(cardId)"
                return (
                    rewardToken(
                        id: tokenId,
                        kind: .recoverFromDiscardOrDraw,
                        title: AppStrings.GameBoard.recoverOneFromDiscard,
                        subtitle: cardTitle(cardId),
                        iconText: "回",
                        symbolName: "arrow.uturn.backward",
                        isSelectable: canResolve
                    ),
                    .direct(choiceId: choice.choiceId, resolution: .recoverCard(cardId))
                )
            }
        case .placeEgg:
            let tokenId = "\(choice.choiceId)-placeEgg"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .placeEgg,
                    title: AppStrings.GameBoard.placeEggAbilityAction,
                    subtitle: AppStrings.GameBoard.chooseLeftTarget,
                    iconText: "卵",
                    symbolName: "circle",
                    isSelectable: canResolve
                ),
                .chooseTarget(choiceId: choice.choiceId, kind: .placeEgg)
            )]
        case .placeYoung:
            let tokenId = "\(choice.choiceId)-placeYoung"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .placeYoung,
                    title: AppStrings.GameBoard.placeYoungAbilityAction,
                    subtitle: AppStrings.GameBoard.chooseLeftTarget,
                    iconText: "幼",
                    symbolName: "circle.fill",
                    isSelectable: canResolve
                ),
                .chooseTarget(choiceId: choice.choiceId, kind: .placeYoung)
            )]
        case .hatchEgg:
            let tokenId = "\(choice.choiceId)-hatchEgg"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .hatchEgg,
                    title: AppStrings.GameBoard.hatchEggAbilityAction,
                    subtitle: AppStrings.GameBoard.chooseLeftTarget,
                    iconText: "孵",
                    symbolName: "circle.dotted",
                    isSelectable: canResolve
                ),
                .chooseTarget(choiceId: choice.choiceId, kind: .hatchEgg)
            )]
        case .moveYoungOrSchool:
            let tokenId = "\(choice.choiceId)-moveYoungOrSchool"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .moveYoungOrSchool,
                    title: AppStrings.GameBoard.moveYoungOrSchool,
                    subtitle: AppStrings.GameBoard.chooseSource,
                    iconText: "移",
                    symbolName: "arrow.up.and.down.and.arrow.left.and.right",
                    isSelectable: canResolve
                ),
                .chooseMoveSource(choiceId: choice.choiceId)
            )]
        case .gainCoral:
            guard choice.expectedInput == .coralPayment else {
                return abilityCoralRewardEntries(for: choice)
            }
            guard let playerState = state.playerGameStates[choice.playerId],
                  let diveSite = coralDiveSite(for: choice),
                  let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == diveSite })
            else {
                return []
            }
            let hasEgg = playerState.ocean.slots.contains { resourceAmount(.egg, in: $0) > 0 }
            let hasYoung = playerState.ocean.slots.contains { resourceAmount(.young, in: $0) > 0 }
            let hasHandCard = !playerState.hand.isEmpty
            let progressText = AppStrings.coralReefProgressText(
                coralCount: reef.coralCount,
                maxCoral: reef.maxCoral
            )
            return [
                (
                    rewardToken(
                        id: "\(choice.choiceId)-coral-egg",
                        kind: .gainCoral,
                        title: AppStrings.GameBoard.payOneEgg,
                        subtitle: progressText,
                        iconText: "卵",
                        symbolName: "circle",
                        isSelectable: canResolve && hasEgg,
                        unavailableReasonText: hasEgg ? nil : AppStrings.GameBoard.noCoralPaymentResource
                    ),
                    .chooseCoralResource(choiceId: choice.choiceId, tokenId: "\(choice.choiceId)-coral-egg", kind: .egg)
                ),
                (
                    rewardToken(
                        id: "\(choice.choiceId)-coral-young",
                        kind: .gainCoral,
                        title: AppStrings.GameBoard.payOneYoung,
                        subtitle: progressText,
                        iconText: "幼",
                        symbolName: "circle.dotted",
                        isSelectable: canResolve && hasYoung,
                        unavailableReasonText: hasYoung ? nil : AppStrings.GameBoard.noCoralPaymentResource
                    ),
                    .chooseCoralResource(choiceId: choice.choiceId, tokenId: "\(choice.choiceId)-coral-young", kind: .young)
                ),
                (
                    rewardToken(
                        id: "\(choice.choiceId)-coral-discard",
                        kind: .gainCoral,
                        title: AppStrings.GameBoard.discardOneHandCard,
                        subtitle: progressText,
                        iconText: "牌",
                        symbolName: "rectangle.stack.badge.minus",
                        isSelectable: canResolve && hasHandCard,
                        unavailableReasonText: hasHandCard ? nil : AppStrings.GameBoard.noCoralPaymentHandCard
                    ),
                    .chooseCoralHandCard(choiceId: choice.choiceId, tokenId: "\(choice.choiceId)-coral-discard")
                ),
                (
                    rewardToken(
                        id: "\(choice.choiceId)-coral-skip",
                        kind: .skipOrEnd,
                        title: AppStrings.GameBoard.skipChoice,
                        subtitle: AppStrings.GameBoard.optionalChoice,
                        iconText: "跳",
                        symbolName: "forward.end",
                        isSelectable: canResolve
                    ),
                    .direct(choiceId: choice.choiceId, resolution: .skip)
                )
            ]
        case .placeEggOnMatchingFish:
            return placeEggOnMatchingFishRewardEntries(for: choice)
        case .scatterSchool:
            return scatterSchoolRewardEntries(for: choice)
        case .consumeFishFromHand:
            return consumeFishFromHandRewardEntries(for: choice)
        case .playFishForFree:
            return playFishForFreeRewardEntries(for: choice)
        case .playFishFromHand:
            return playFishFromHandRewardEntries(for: choice)
        case .compoundAbility:
            var entries: [(token: RewardTokenViewState, action: RewardTokenAction)] = []
            if choice.compoundAbilityProgress != nil {
                let selectableEffects = selectableCompoundEffects(for: choice)
                let remainingDraws = abilityEffectCount(.drawFish(count: 1), in: selectableEffects)
                for index in 0..<remainingDraws {
                    let tokenId = "\(choice.choiceId)-compoundDrawFish-\(index)"
                    entries.append((
                        rewardToken(
                            id: tokenId,
                            kind: .drawFish,
                            title: AppStrings.GameBoard.drawOneFishCard,
                            subtitle: rewardSourceText(for: choice),
                            iconText: "牌",
                            symbolName: "rectangle.stack",
                            countText: "\(index + 1)/\(remainingDraws)",
                            isSelectable: canResolve && !state.deckState.fishDrawPile.isEmpty,
                            unavailableReasonText: state.deckState.fishDrawPile.isEmpty ? AppStrings.GameBoard.fishDrawPileEmpty : nil
                        ),
                        .direct(choiceId: choice.choiceId, resolution: .chooseAbilityEffect(.drawFish(count: 1)))
                    ))
                }

                let remainingRecovers = abilityEffectCount(.recoverFromDiscardOrDraw(count: 1), in: selectableEffects)
                for index in 0..<remainingRecovers {
                    let tokenId = "\(choice.choiceId)-compoundRecover-\(index)"
                    entries.append((
                        rewardToken(
                            id: tokenId,
                            kind: .recoverFromDiscardOrDraw,
                            title: AppStrings.GameBoard.recoverOneFromDiscard,
                            subtitle: AppStrings.GameBoard.discardPileEmptyDrawAlternative,
                            iconText: "回",
                            symbolName: "arrow.uturn.backward",
                            countText: "\(index + 1)/\(remainingRecovers)",
                            isSelectable: canResolve
                        ),
                        .direct(choiceId: choice.choiceId, resolution: .chooseAbilityEffect(.recoverFromDiscardOrDraw(count: 1)))
                    ))
                }

                let remainingPlaceEggs = abilityEffectCount(.placeEgg(count: 1), in: selectableEffects)
                for index in 0..<remainingPlaceEggs {
                    let tokenId = "\(choice.choiceId)-compoundPlaceEgg-\(index)"
                    entries.append((
                        rewardToken(
                            id: tokenId,
                            kind: .compoundPlaceEgg,
                            title: AppStrings.GameBoard.placeEggAbilityAction,
                            subtitle: AppStrings.GameBoard.chooseLeftTarget,
                            iconText: "卵",
                            symbolName: "circle",
                            countText: "\(index + 1)/\(remainingPlaceEggs)",
                            isSelectable: canResolve
                        ),
                        .direct(choiceId: choice.choiceId, resolution: .chooseAbilityEffect(.placeEgg(count: 1)))
                    ))
                }

                let remainingYoung = abilityEffectCount(.placeYoung(count: 1), in: selectableEffects)
                for index in 0..<remainingYoung {
                    let tokenId = "\(choice.choiceId)-compoundPlaceYoung-\(index)"
                    entries.append((
                        rewardToken(
                            id: tokenId,
                            kind: .placeYoung,
                            title: AppStrings.GameBoard.placeYoungAbilityAction,
                            subtitle: AppStrings.GameBoard.chooseLeftTarget,
                            iconText: "幼",
                            symbolName: "circle.fill",
                            countText: "\(index + 1)/\(remainingYoung)",
                            isSelectable: canResolve
                        ),
                        .direct(choiceId: choice.choiceId, resolution: .chooseAbilityEffect(.placeYoung(count: 1)))
                    ))
                }

                let remainingHatches = abilityEffectCount(.hatchEgg(count: 1), in: selectableEffects)
                for index in 0..<remainingHatches {
                    let tokenId = "\(choice.choiceId)-compoundHatchEgg-\(index)"
                    entries.append((
                        rewardToken(
                            id: tokenId,
                            kind: .compoundHatchEgg,
                            title: AppStrings.GameBoard.hatchEggAbilityAction,
                            subtitle: AppStrings.GameBoard.chooseLeftTarget,
                            iconText: "孵",
                            symbolName: "circle.dotted",
                            countText: "\(index + 1)/\(remainingHatches)",
                            isSelectable: canResolve
                        ),
                        .direct(choiceId: choice.choiceId, resolution: .chooseAbilityEffect(.hatchEgg(count: 1)))
                    ))
                }

                for effect in selectableEffects {
                    guard case let .gainCoral(selector, count) = effect else {
                        continue
                    }
                    for index in 0..<count {
                        let tokenId = "\(choice.choiceId)-compoundGainCoral-\(selector.rawValue)-\(index)"
                        entries.append((
                            rewardToken(
                                id: tokenId,
                                kind: .gainCoral,
                                title: AppStrings.GameBoard.gainOneCoral,
                                subtitle: selector.fixedDiveSite.map(AppStrings.oceanDiveSiteName) ?? AppStrings.GameBoard.chooseCoralDiveSite,
                                iconText: "珊",
                                symbolName: "hexagon.fill",
                                countText: "\(index + 1)/\(count)",
                                isSelectable: canResolve
                            ),
                            .direct(
                                choiceId: choice.choiceId,
                                resolution: .chooseAbilityEffect(.gainCoral(selector: selector, count: 1))
                            )
                        ))
                    }
                }
                let remainingScatterSchools = abilityEffectCount(.scatterSchool(count: 1), in: selectableEffects)
                for index in 0..<remainingScatterSchools {
                    let tokenId = "\(choice.choiceId)-compoundScatterSchool-\(index)"
                    entries.append((
                        rewardToken(
                            id: tokenId,
                            kind: .scatterSchool,
                            title: AppStrings.GameBoard.scatterSchool,
                            subtitle: AppStrings.GameBoard.scatterSchoolSource,
                            iconText: "散",
                            symbolName: "circle.grid.cross",
                            countText: "\(index + 1)/\(remainingScatterSchools)",
                            isSelectable: canResolve
                        ),
                        .direct(choiceId: choice.choiceId, resolution: .chooseAbilityEffect(.scatterSchool(count: 1)))
                    ))
                }
                let remainingConsumes = abilityEffectCount(.consumeFishFromHand(count: 1), in: selectableEffects)
                for index in 0..<remainingConsumes {
                    let tokenId = "\(choice.choiceId)-compoundConsumeFish-\(index)"
                    entries.append((
                        rewardToken(
                            id: tokenId,
                            kind: .consumeFish,
                            title: AppStrings.GameBoard.consumeFishFromHand,
                            subtitle: AppStrings.GameBoard.consumeFishConsumer,
                            iconText: "吞",
                            symbolName: "fish",
                            countText: "\(index + 1)/\(remainingConsumes)",
                            isSelectable: canResolve
                        ),
                        .direct(choiceId: choice.choiceId, resolution: .chooseAbilityEffect(.consumeFishFromHand(count: 1)))
                    ))
                }
                for effect in selectableEffects {
                    guard case let .playFishForFree(filter, placement, sourceCondition, count) = effect else {
                        continue
                    }
                    for index in 0..<count {
                        let tokenId = "\(choice.choiceId)-compoundFreePlay-\(index)"
                        entries.append((
                            rewardToken(
                                id: tokenId,
                                kind: .playFishForFree,
                                title: AppStrings.GameBoard.playFishForFree,
                                subtitle: freePlayFilterText(filter),
                                iconText: "免",
                                symbolName: "fish",
                                countText: "\(index + 1)/\(count)",
                                isSelectable: canResolve
                            ),
                            .direct(
                                choiceId: choice.choiceId,
                                resolution: .chooseAbilityEffect(
                                    .playFishForFree(
                                        filter: filter,
                                        placement: placement,
                                        sourceCondition: sourceCondition,
                                        count: 1
                                    )
                                )
                            )
                        ))
                    }
                }
            }
            let tokenId = "\(choice.choiceId)-finishAbility"
            entries.append((
                rewardToken(
                    id: tokenId,
                    kind: .skipOrEnd,
                    title: AppStrings.GameBoard.finishAbility,
                    subtitle: choice.isOptional ? AppStrings.GameBoard.optionalChoice : AppStrings.GameBoard.requiredChoice,
                    iconText: "止",
                    symbolName: "checkmark.circle",
                    isSelectable: canResolve && choice.isOptional,
                    unavailableReasonText: choice.isOptional ? nil : AppStrings.GameBoard.pendingChoiceRequired
                ),
                .direct(choiceId: choice.choiceId, resolution: .finishAbility)
            ))
            return entries
        case .bottomBonus,
             .placeholder,
             .unsupported:
            let tokenId = "\(choice.choiceId)-unsupported"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .unsupported,
                    title: AppStrings.GameBoard.abilityUnsupported,
                    subtitle: rewardSourceText(for: choice),
                    iconText: "?",
                    symbolName: "questionmark.circle",
                    isSelectable: false,
                    isUnsupported: true,
                    unavailableReasonText: AppStrings.GameBoard.abilityUnsupported
                ),
                .unsupported
            )]
        }
    }

    private func rewardToken(
        id: String,
        kind: RewardTokenKind,
        title: String,
        subtitle: String,
        iconText: String,
        symbolName: String?,
        countText: String? = nil,
        isSelectable: Bool,
        isCompleted: Bool = false,
        isUnsupported: Bool = false,
        unavailableReasonText: String? = nil
    ) -> RewardTokenViewState {
        RewardTokenViewState(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            iconText: iconText,
            symbolName: symbolName,
            countText: countText,
            isSelectable: isSelectable,
            isSelected: selectedRewardTokenId == id,
            isCompleted: isCompleted,
            isUnsupported: isUnsupported,
            unavailableReasonText: unavailableReasonText
        )
    }

    private func placeEggOnMatchingFishRewardEntries(
        for choice: PendingChoice
    ) -> [(token: RewardTokenViewState, action: RewardTokenAction)] {
        let canResolve = canResolvePendingChoice(choice)
        let targetCount = pendingChoiceTargets(for: choice).count
        let tokenId = "\(choice.choiceId)-matching-egg"
        let isOnEach = choice.expectedInput == PendingChoiceExpectedInput.none
        return [(
            rewardToken(
                id: tokenId,
                kind: .placeEgg,
                title: AppStrings.GameBoard.placeEggOnMatchingFish,
                subtitle: isOnEach
                    ? AppStrings.GameBoard.compoundAbilityProgressText(
                        title: AppStrings.GameBoard.placeEggAbilityAction,
                        completedCount: 0,
                        totalCount: targetCount
                    )
                    : AppStrings.GameBoard.chooseLeftTarget,
                iconText: "卵",
                symbolName: "circle",
                isSelectable: canResolve && targetCount > 0,
                unavailableReasonText: targetCount > 0 ? nil : AppStrings.GameBoard.noPendingChoiceTargets
            ),
            isOnEach
                ? .direct(choiceId: choice.choiceId, resolution: .finishAbility)
                : .chooseTarget(choiceId: choice.choiceId, kind: .placeEggOnMatchingFish)
        )]
    }

    private func playFishFromHandRewardEntries(
        for choice: PendingChoice
    ) -> [(token: RewardTokenViewState, action: RewardTokenAction)] {
        guard let playerState = state.playerGameStates[choice.playerId] else {
            return []
        }
        let canResolve = canResolvePendingChoice(choice)
        if choice.expectedInput == .playFishFromHandPayment,
           let progress = choice.playFishFromHandProgress,
           let cardId = progress.selectedCardId,
           let targetSlot = progress.targetSlot {
            let tokenId = "\(choice.choiceId)-paid-payment"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .playFishFromHand,
                    title: AppStrings.GameBoard.playFishFromHandPayment,
                    subtitle: cardTitle(cardId),
                    iconText: "付",
                    symbolName: "checkmark.circle",
                    isSelectable: canResolve
                ),
                .choosePlayFishFromHandPayment(
                    choiceId: choice.choiceId,
                    tokenId: tokenId,
                    cardId: cardId,
                    targetSlot: targetSlot
                )
            )]
        }
        if choice.expectedInput == .playFishFromHandTargetSlot,
           let cardId = choice.playFishFromHandProgress?.selectedCardId {
            let tokenId = "\(choice.choiceId)-paid-target"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .playFishFromHand,
                    title: AppStrings.GameBoard.playFishFromHandTarget,
                    subtitle: cardTitle(cardId),
                    iconText: "位",
                    symbolName: "scope",
                    isSelectable: canResolve
                ),
                .choosePlayFishFromHandTarget(choiceId: choice.choiceId, tokenId: tokenId, cardId: cardId)
            )]
        }

        let hasMatchingCard = playerState.hand.contains { playFishFromHandCardIsLegal($0, for: choice) }
        let tokenId = "\(choice.choiceId)-paid-hand"
        return [(
            rewardToken(
                id: tokenId,
                kind: .playFishFromHand,
                title: AppStrings.GameBoard.playFishFromHand,
                subtitle: handFishFilterText(handFishFilter(for: choice) ?? .unsupported("unknown")),
                iconText: "牌",
                symbolName: "fish",
                isSelectable: canResolve && hasMatchingCard,
                unavailableReasonText: hasMatchingCard ? nil : AppStrings.GameBoard.playFishFromHandNoMatchingHandCard
            ),
            .choosePlayFishFromHandCard(choiceId: choice.choiceId, tokenId: tokenId)
        )]
    }

    private func abilityCoralRewardEntries(
        for choice: PendingChoice
    ) -> [(token: RewardTokenViewState, action: RewardTokenAction)] {
        guard let playerState = state.playerGameStates[choice.playerId],
              let selector = gainCoralSelector(for: choice)
        else {
            return []
        }

        let diveSites = selector.fixedDiveSite.map { [$0] } ?? DiveSite.allCases
        return diveSites.compactMap { diveSite in
            guard let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == diveSite }) else {
                return nil
            }
            let isAvailable = canResolvePendingChoice(choice) && reef.coralCount < reef.maxCoral
            let tokenId = "\(choice.choiceId)-ability-coral-\(diveSite.rawValue)"
            let progressText = AppStrings.coralReefProgressText(
                coralCount: reef.coralCount,
                maxCoral: reef.maxCoral
            )
            return (
                rewardToken(
                    id: tokenId,
                    kind: .gainCoral,
                    title: selector.fixedDiveSite == nil
                        ? "\(AppStrings.oceanDiveSiteName(diveSite)) \(AppStrings.GameBoard.gainOneCoral)"
                        : AppStrings.GameBoard.gainOneCoral,
                    subtitle: progressText,
                    iconText: "珊",
                    symbolName: "hexagon.fill",
                    isSelectable: isAvailable,
                    unavailableReasonText: isAvailable ? nil : AppStrings.GameBoard.coralReefFull
                ),
                .direct(choiceId: choice.choiceId, resolution: .gainCoralFromAbility(diveSite: diveSite))
            )
        }
    }

    private func scatterSchoolRewardEntries(
        for choice: PendingChoice
    ) -> [(token: RewardTokenViewState, action: RewardTokenAction)] {
        guard let playerState = state.playerGameStates[choice.playerId] else {
            return []
        }
        let canResolve = canResolvePendingChoice(choice)
        let progress = scatterSchoolProgress(for: choice, playerState: playerState)
        if choice.expectedInput == .scatterSchoolYoungTarget || !progress.requiresSchoolSource {
            let tokenId = "\(choice.choiceId)-scatter-young-target"
            let title = progress.requiresSchoolSource
                ? AppStrings.GameBoard.scatterSchoolYoungTarget
                : AppStrings.GameBoard.scatterSchoolNoSchool
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .scatterSchool,
                    title: title,
                    subtitle: AppStrings.GameBoard.scatterSchoolProgressText(
                        completedCount: progress.completedTargetCount,
                        totalCount: progress.requiredTargetCount
                    ),
                    iconText: "幼",
                    symbolName: "circle.dotted",
                    isSelectable: canResolve
                ),
                .chooseScatterSchoolYoungTarget(choiceId: choice.choiceId, tokenId: tokenId)
            )]
        }

        let hasSchool = playerHasSchool(playerState)
        let tokenId = "\(choice.choiceId)-scatter-source"
        return [(
            rewardToken(
                id: tokenId,
                kind: .scatterSchool,
                title: AppStrings.GameBoard.scatterSchool,
                subtitle: AppStrings.GameBoard.scatterSchoolSource,
                iconText: "散",
                symbolName: "circle.grid.cross",
                isSelectable: canResolve && hasSchool,
                unavailableReasonText: hasSchool ? nil : AppStrings.GameBoard.scatterSchoolNoSource
            ),
            .chooseScatterSchoolSource(choiceId: choice.choiceId, tokenId: tokenId)
        )]
    }

    private func consumeFishFromHandRewardEntries(
        for choice: PendingChoice
    ) -> [(token: RewardTokenViewState, action: RewardTokenAction)] {
        guard let playerState = state.playerGameStates[choice.playerId] else {
            return []
        }
        let canResolve = canResolvePendingChoice(choice)
        if choice.expectedInput == .consumeFishHandCard {
            let hasConsumableHandCard = playerState.hand.contains { consumeFishHandCardIsLegal($0, for: choice) }
            let tokenId = "\(choice.choiceId)-consume-hand-card"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .consumeFish,
                    title: AppStrings.GameBoard.consumeFishHandCard,
                    subtitle: AppStrings.GameBoard.consumeFishMustBeShorter,
                    iconText: "牌",
                    symbolName: "rectangle.stack.badge.minus",
                    isSelectable: canResolve && hasConsumableHandCard,
                    unavailableReasonText: hasConsumableHandCard ? nil : AppStrings.GameBoard.consumeFishNoHandCard
                ),
                .chooseConsumeFishHandCard(choiceId: choice.choiceId, tokenId: tokenId)
            )]
        }

        let hasConsumer = playerState.ocean.slots.contains { consumeFishConsumerIsLegal($0, for: choice) }
        let tokenId = "\(choice.choiceId)-consume-consumer"
        return [(
            rewardToken(
                id: tokenId,
                kind: .consumeFish,
                title: AppStrings.GameBoard.consumeFishFromHand,
                subtitle: AppStrings.GameBoard.consumeFishConsumer,
                iconText: "吞",
                symbolName: "fish",
                isSelectable: canResolve && hasConsumer,
                unavailableReasonText: hasConsumer ? nil : AppStrings.GameBoard.consumeFishNoConsumer
            ),
            .chooseConsumeFishConsumer(choiceId: choice.choiceId, tokenId: tokenId)
        )]
    }

    private func playFishForFreeRewardEntries(
        for choice: PendingChoice
    ) -> [(token: RewardTokenViewState, action: RewardTokenAction)] {
        guard let playerState = state.playerGameStates[choice.playerId] else {
            return []
        }
        let canResolve = canResolvePendingChoice(choice)
        if choice.expectedInput == .freePlayTargetSlot,
           let cardId = choice.playFishForFreeProgress?.selectedCardId {
            let tokenId = "\(choice.choiceId)-free-target"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .playFishForFree,
                    title: AppStrings.GameBoard.playFishForFreeTarget,
                    subtitle: cardTitle(cardId),
                    iconText: "位",
                    symbolName: "scope",
                    isSelectable: canResolve
                ),
                .chooseFreePlayTarget(choiceId: choice.choiceId, tokenId: tokenId, cardId: cardId)
            )]
        }

        let hasMatchingCard = playerState.hand.contains { freePlayHandCardIsLegal($0, for: choice) }
        let tokenId = "\(choice.choiceId)-free-hand"
        return [(
            rewardToken(
                id: tokenId,
                kind: .playFishForFree,
                title: AppStrings.GameBoard.playFishForFree,
                subtitle: freePlayFilterText(freePlayFilter(for: choice) ?? .unsupported("unknown")),
                iconText: "免",
                symbolName: "fish",
                isSelectable: canResolve && hasMatchingCard,
                unavailableReasonText: hasMatchingCard ? nil : AppStrings.GameBoard.playFishForFreeNoMatchingHandCard
            ),
            .chooseFreePlayHandCard(choiceId: choice.choiceId, tokenId: tokenId)
        )]
    }

    func pendingChoiceTargets(for choice: PendingChoice) -> [PendingChoiceTargetViewData] {
        guard let playerState = state.playerGameStates[choice.playerId],
              choice.kind == .placeEgg
                || choice.kind == .placeYoung
                || choice.kind == .hatchEgg
                || choice.kind == .placeEggOnMatchingFish
        else {
            return []
        }

        return playerState.ocean.slots
            .sorted { left, right in
                if left.address.diveSite.rawValue == right.address.diveSite.rawValue {
                    return left.address.rowIndex < right.address.rowIndex
                }
                return diveSiteSortIndex(left.address.diveSite) < diveSiteSortIndex(right.address.diveSite)
            }
            .compactMap { slot in
                guard pendingChoiceTargetIsLegal(slot, for: choice) else {
                    return nil
                }
                return PendingChoiceTargetViewData(
                    choiceId: choice.choiceId,
                    address: slot.address,
                    title: "\(AppStrings.oceanDiveSiteName(slot.address.diveSite)) · \(slotTitle(slot.address))",
                    subtitle: slotContentText(slot.content),
                    resourcesText: resourcesText(slot.resources),
                    isEnabled: canResolvePendingChoice(choice)
                )
            }
    }

    func pendingChoiceCardTargets(for choice: PendingChoice) -> [PendingChoiceCardTargetViewData] {
        guard choice.kind == .recoverFromDiscardOrDraw,
              let playerState = state.playerGameStates[choice.playerId]
        else {
            return []
        }

        return playerState.discardPile.map { cardId in
            PendingChoiceCardTargetViewData(
                choiceId: choice.choiceId,
                cardId: cardId,
                title: cardTitle(cardId),
                subtitle: AppStrings.GameBoard.recoverFromDiscardOrDraw,
                isEnabled: canResolvePendingChoice(choice)
            )
        }
    }

    func pendingChoiceMoveTargets(for choice: PendingChoice) -> [PendingChoiceMoveTargetViewData] {
        guard choice.kind == .moveYoungOrSchool,
              let playerState = state.playerGameStates[choice.playerId]
        else {
            return []
        }

        let slots = playerState.ocean.slots.sorted(by: slotSort)
        var results: [PendingChoiceMoveTargetViewData] = []
        for source in slots {
            for kind in [ResourceKind.young, ResourceKind.school] where resourceAmount(kind, in: source) > 0 {
                for target in slots where moveTargetIsLegal(target, from: source, kind: kind) {
                    results.append(
                        PendingChoiceMoveTargetViewData(
                            choiceId: choice.choiceId,
                            source: source.address,
                            target: target.address,
                            kind: kind,
                            title: "\(resourceName(kind))：\(slotLocationText(source.address)) → \(slotLocationText(target.address))",
                            subtitle: "\(AppStrings.GameBoard.chooseMoveSource)：\(resourcesText(source.resources))，\(AppStrings.GameBoard.chooseMoveTarget)：\(resourcesText(target.resources))",
                            isEnabled: canResolvePendingChoice(choice)
                        )
                    )
                }
            }
        }
        return results
    }

    private func moveTargetIsLegal(_ target: OceanSlot, from source: OceanSlot, kind: ResourceKind) -> Bool {
        guard source.address != target.address,
              source.address.playerId == target.address.playerId,
              moveDistance(from: source.address, to: target.address) == 1
        else {
            return false
        }
        if kind == .school {
            return resourceAmount(.school, in: target) == 0
        }
        return kind == .young
    }

    private func moveDistance(from source: OceanSlotAddress, to target: OceanSlotAddress) -> Int {
        let diveSiteDistance = abs(diveSiteSortIndex(source.diveSite) - diveSiteSortIndex(target.diveSite))
        let rowDistance = abs(source.rowIndex - target.rowIndex)
        return max(diveSiteDistance, rowDistance)
    }

    private func pendingChoiceTargetIsLegal(_ slot: OceanSlot, for choice: PendingChoice) -> Bool {
        guard slot.address.playerId == choice.playerId else {
            return false
        }

        switch choice.kind {
        case .placeEgg:
            return slot.content.hasFish && resourceAmount(.egg, in: slot) == 0
        case .placeYoung:
            return slot.content.hasFish || slot.content == .empty
        case .placeEggOnMatchingFish:
            return matchingEggTargetIsLegal(slot, for: choice)
        case .hatchEgg:
            return resourceAmount(.egg, in: slot) > 0
        case .drawFish,
             .recoverFromDiscardOrDraw,
             .moveYoungOrSchool,
             .gainCoral,
             .scatterSchool,
             .consumeFishFromHand,
             .playFishForFree,
             .playFishFromHand,
             .compoundAbility,
             .bottomBonus,
             .placeholder,
             .unsupported:
            return false
        }
    }

    private func pendingChoiceTargetPrompt(for choice: PendingChoice) -> String? {
        switch choice.kind {
        case .placeEgg:
            return AppStrings.GameBoard.choosePlaceEggTarget
        case .placeYoung:
            return AppStrings.GameBoard.choosePlaceYoungTarget
        case .hatchEgg:
            return AppStrings.GameBoard.chooseHatchEggTarget
        case .placeEggOnMatchingFish:
            return choice.expectedInput == .matchingEggTarget
                ? AppStrings.GameBoard.choosePlaceEggTarget
                : AppStrings.GameBoard.placeEggOnMatchingFish
        case .recoverFromDiscardOrDraw:
            return state.playerGameStates[choice.playerId]?.discardPile.isEmpty == true
                ? AppStrings.GameBoard.discardPileEmptyDrawHint
                : AppStrings.GameBoard.chooseDiscardCardToRecover
        case .moveYoungOrSchool:
            return AppStrings.GameBoard.moveYoungOrSchool
        case .gainCoral:
            return AppStrings.GameBoard.chooseCoralPayment
        case .scatterSchool:
            return choice.expectedInput == .scatterSchoolYoungTarget
                ? AppStrings.GameBoard.scatterSchoolYoungTarget
                : AppStrings.GameBoard.scatterSchoolSource
        case .consumeFishFromHand:
            return choice.expectedInput == .consumeFishHandCard
                ? AppStrings.GameBoard.consumeFishHandCard
                : AppStrings.GameBoard.consumeFishConsumer
        case .playFishForFree:
            return choice.expectedInput == .freePlayTargetSlot
                ? AppStrings.GameBoard.playFishForFreeTarget
                : AppStrings.GameBoard.playFishForFreeHandCard
        case .playFishFromHand:
            switch choice.expectedInput {
            case .playFishFromHandTargetSlot:
                return AppStrings.GameBoard.playFishFromHandTarget
            case .playFishFromHandPayment:
                return AppStrings.GameBoard.playFishFromHandPayment
            default:
                return AppStrings.GameBoard.playFishFromHandHandCard
            }
        case .drawFish,
             .compoundAbility,
             .bottomBonus,
             .placeholder,
             .unsupported:
            return nil
        }
    }

    private func noPendingChoiceTargetsText(for choice: PendingChoice) -> String? {
        if choice.kind == .placeEgg || choice.kind == .placeYoung || choice.kind == .hatchEgg || choice.kind == .placeEggOnMatchingFish {
            return pendingChoiceTargets(for: choice).isEmpty ? AppStrings.GameBoard.noPendingChoiceTargets : nil
        }
        if choice.kind == .moveYoungOrSchool {
            return pendingChoiceMoveTargets(for: choice).isEmpty ? AppStrings.GameBoard.noMovableYoungOrSchool : nil
        }
        if choice.kind == .scatterSchool {
            return nil
        }
        if choice.kind == .consumeFishFromHand {
            return nil
        }
        if choice.kind == .playFishForFree {
            return nil
        }
        if choice.kind == .playFishFromHand {
            return nil
        }
        if choice.kind == .recoverFromDiscardOrDraw {
            return nil
        }
        return nil
    }

    private func rewardSourceText(for choice: PendingChoice) -> String {
        switch choice.source {
        case let .diveBonus(diveSite):
            let prefix = AppStrings.GameBoard.triggering
            return "\(prefix)：\(AppStrings.diveActionSiteName(diveSite))"
        case let .coralReef(diveSite):
            let prefix = AppStrings.GameBoard.triggering
            return "\(prefix)：\(AppStrings.oceanDiveSiteName(diveSite))\(AppStrings.GameBoard.coralReef)"
        case let .fishAbility(cardId):
            let prefix = AppStrings.GameBoard.activating
            return "\(prefix)：\(cardTitle(cardId))"
        case .endGameAbility:
            return "\(AppStrings.GameBoard.activating)：\(AppStrings.GameBoard.finalScoreGameEndAbility)"
        case .allPlayers:
            return AppStrings.GameBoard.players
        case let .expansion(expansionId):
            return "\(AppStrings.GameBoard.triggering)：\(expansionId)"
        case let .placeholder(value):
            return "\(AppStrings.GameBoard.triggering)：\(value)"
        }
    }

    private func rewardInstructionText(for choice: PendingChoice) -> String {
        if let mode = rewardSelectionMode {
            switch mode {
            case .target:
                return AppStrings.GameBoard.chooseLeftTarget
            case .moveSource:
                return AppStrings.GameBoard.chooseSource
            case .moveTarget:
                return AppStrings.GameBoard.chooseTarget
            case .coralResource:
                return AppStrings.GameBoard.chooseCoralResourceSource
            case .coralHandCard:
                return AppStrings.GameBoard.chooseCoralDiscardCard
            case .scatterSchoolSource:
                return AppStrings.GameBoard.scatterSchoolSource
            case .scatterSchoolYoungTarget:
                return AppStrings.GameBoard.scatterSchoolYoungTarget
            case .consumeFishConsumer:
                return AppStrings.GameBoard.consumeFishConsumer
            case .consumeFishHandCard:
                return AppStrings.GameBoard.consumeFishHandCard
            case .freePlayHandCard:
                return AppStrings.GameBoard.playFishForFreeHandCard
            case .freePlayTarget:
                return AppStrings.GameBoard.playFishForFreeTarget
            case .playFishFromHandCard:
                return AppStrings.GameBoard.playFishFromHandHandCard
            case .playFishFromHandTarget:
                return AppStrings.GameBoard.playFishFromHandTarget
            case .playFishFromHandPayment:
                return AppStrings.GameBoard.playFishFromHandPayment
            }
        }

        switch choice.kind {
        case .drawFish,
             .recoverFromDiscardOrDraw,
             .compoundAbility:
            return AppStrings.GameBoard.chooseRewardToken
        case .placeEgg,
             .placeYoung,
             .placeEggOnMatchingFish,
             .hatchEgg:
            return AppStrings.GameBoard.chooseRewardThenTarget
        case .moveYoungOrSchool:
            return AppStrings.GameBoard.chooseRewardThenSource
        case .gainCoral:
            return choice.expectedInput == .coralPayment
                ? AppStrings.GameBoard.chooseCoralPayment
                : AppStrings.GameBoard.chooseCoralDiveSite
        case .scatterSchool:
            return choice.expectedInput == .scatterSchoolYoungTarget
                ? AppStrings.GameBoard.scatterSchoolYoungTarget
                : AppStrings.GameBoard.scatterSchoolSource
        case .consumeFishFromHand:
            return choice.expectedInput == .consumeFishHandCard
                ? AppStrings.GameBoard.consumeFishHandCard
                : AppStrings.GameBoard.consumeFishConsumer
        case .playFishForFree:
            return choice.expectedInput == .freePlayTargetSlot
                ? AppStrings.GameBoard.playFishForFreeTarget
                : AppStrings.GameBoard.playFishForFreeHandCard
        case .playFishFromHand:
            switch choice.expectedInput {
            case .playFishFromHandTargetSlot:
                return AppStrings.GameBoard.playFishFromHandTarget
            case .playFishFromHandPayment:
                return AppStrings.GameBoard.playFishFromHandPayment
            default:
                return AppStrings.GameBoard.playFishFromHandHandCard
            }
        case .bottomBonus,
             .placeholder,
             .unsupported:
            return AppStrings.GameBoard.abilityUnsupported
        }
    }

    private func preferredMoveResourceKind(in slot: OceanSlot) -> ResourceKind? {
        if resourceAmount(.young, in: slot) > 0 {
            return .young
        }
        if resourceAmount(.school, in: slot) > 0 {
            return .school
        }
        return nil
    }

    private func pendingChoiceResolutionName(_ resolution: PendingChoiceResolution) -> String {
        switch resolution {
        case .skip:
            return AppStrings.GameBoard.skipChoice
        case .chooseTarget:
            return AppStrings.GameBoard.chooseTarget
        case .draw:
            return AppStrings.GameBoard.drawFish
        case .recoverCard:
            return AppStrings.GameBoard.recoverFromDiscardOrDraw
        case .drawFromDeck:
            return AppStrings.GameBoard.drawFish
        case .moveResource:
            return AppStrings.GameBoard.moveYoungOrSchool
        case .gainCoralWithEgg:
            return AppStrings.GameBoard.payOneEgg
        case .gainCoralWithYoung:
            return AppStrings.GameBoard.payOneYoung
        case .gainCoralByDiscard:
            return AppStrings.GameBoard.discardOneHandCard
        case .gainCoralFromAbility:
            return AppStrings.GameBoard.gainOneCoral
        case .chooseScatterSchoolSource:
            return AppStrings.GameBoard.scatterSchool
        case .placeScatterSchoolYoung:
            return AppStrings.GameBoard.scatterSchoolYoungTarget
        case .chooseConsumeFishConsumer:
            return AppStrings.GameBoard.consumeFishConsumer
        case .consumeFishFromHand:
            return AppStrings.GameBoard.consumeFishFromHand
        case .chooseFreePlayFish:
            return AppStrings.GameBoard.playFishForFreeHandCard
        case .playFishForFree:
            return AppStrings.GameBoard.playFishForFree
        case .choosePlayFishFromHand:
            return AppStrings.GameBoard.playFishFromHandHandCard
        case .choosePlayFishFromHandTarget:
            return AppStrings.GameBoard.playFishFromHandTarget
        case .playFishFromHand:
            return AppStrings.GameBoard.playFishFromHand
        case .chooseOption:
            return AppStrings.GameBoard.chooseOption
        case .chooseAbilityEffect:
            return AppStrings.GameBoard.chooseOption
        case .finishAbility:
            return AppStrings.GameBoard.finishAbility
        }
    }

    private func resourcesText(_ resources: [ResourceQuantity]) -> String {
        guard !resources.isEmpty else {
            return AppStrings.GameBoard.noResources
        }
        return resources
            .map { "\(resourceName($0.kind)) \($0.amount)" }
            .joined(separator: "，")
    }

    private func oceanSlotViewData(_ slot: OceanSlot) -> OceanSlotViewData {
        let isHighlighted = slotIsHighlightedByDiveQueue(slot)
        let preview = playFishSlotPreview(for: slot)
        let isDropTarget = draggingHandCardId != nil
        let rewardHighlightText = rewardSelectionHighlightText(for: slot)
        return OceanSlotViewData(
            address: slot.address,
            title: slotTitle(slot.address),
            subtitle: slotContentText(slot.content),
            resourcesText: resourcesText(slot.resources),
            cardFace: fishCardFaceViewState(content: slot.content),
            isOccupied: slot.content != .empty,
            isSelected: selectedTargetSlot == slot.address,
            isHighlightedByDiveQueue: isHighlighted,
            highlightReasonText: isHighlighted ? slotDiveQueueHighlightText(slot) : nil,
            playFishPreview: preview,
            resourceTokens: resourceTokens(for: slot),
            aspectRatio: slotAspectRatio,
            isDropTarget: isDropTarget,
            isValidDropTarget: isDropTarget && preview.isSelectable,
            dropTargetReasonText: isDropTarget
                ? dropTargetReasonText(preview: preview)
                : nil,
            isHighlightedByRewardSelection: rewardHighlightText != nil,
            rewardSelectionReasonText: rewardHighlightText
        )
    }

    private func coralReefViewState(for diveSite: DiveSite) -> CoralReefViewState? {
        guard let reef = activePlayerState?.ocean.coralReefs.first(where: { $0.diveSite == diveSite }) else {
            return nil
        }
        return CoralReefViewState(
            diveSite: reef.diveSite,
            iconAssetName: coralReefIconAssetName(for: reef.diveSite),
            coralCount: reef.coralCount,
            maxCoral: reef.maxCoral,
            completionBonus: reef.completionBonus,
            isEnabled: true,
            title: AppStrings.GameBoard.coralReef,
            progressText: AppStrings.coralReefProgressText(
                coralCount: reef.coralCount,
                maxCoral: reef.maxCoral
            ),
            completionBonusText: AppStrings.coralReefCompletionBonusText(
                completionBonus: reef.completionBonus
            )
        )
    }

    private func coralReefIconAssetName(for diveSite: DiveSite) -> String {
        switch diveSite {
        case .blue:
            return "BlueCoral"
        case .purple:
            return "PurpleCoral"
        case .green:
            return "GreenCoral"
        }
    }

    private func coralDiveSite(for choice: PendingChoice) -> DiveSite? {
        guard case let .coralReef(diveSite) = choice.source else {
            return nil
        }
        return diveSite
    }

    private func gainCoralSelector(for choice: PendingChoice) -> CoralDiveSiteSelector? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .gainCoral(selector, _) = effect else {
            return nil
        }
        return selector
    }

    private func scatterSchoolProgress(
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> ScatterSchoolProgress {
        if let progress = choice.scatterSchoolProgress {
            return progress
        }
        let hasSchool = playerHasSchool(playerState)
        return ScatterSchoolProgress(
            requiredTargetCount: hasSchool ? 4 : 1,
            requiresSchoolSource: hasSchool
        )
    }

    private func playerHasSchool(_ playerState: PlayerGameState) -> Bool {
        playerState.ocean.slots.contains { resourceAmount(.school, in: $0) > 0 }
    }

    private func scatterSchoolYoungTargetIsLegal(
        _ target: OceanSlot,
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        guard target.address.playerId == choice.playerId else {
            return false
        }
        let progress = scatterSchoolProgress(for: choice, playerState: playerState)
        guard progress.targetSlots.contains(target.address) == false,
              progress.completedTargetCount < progress.requiredTargetCount
        else {
            return false
        }
        return !progress.requiresSchoolSource || progress.sourceSlot != nil
    }

    private func consumeFishConsumerIsLegal(_ slot: OceanSlot, for choice: PendingChoice) -> Bool {
        guard slot.address.playerId == choice.playerId,
              choice.kind == .consumeFishFromHand,
              choice.expectedInput == .consumeFishConsumer,
              case .fishCard = slot.content
        else {
            return false
        }
        return true
    }

    private func consumeFishHandCardIsLegal(_ cardId: CardID, for choice: PendingChoice) -> Bool {
        guard choice.kind == .consumeFishFromHand,
              choice.expectedInput == .consumeFishHandCard,
              let playerState = state.playerGameStates[choice.playerId],
              playerState.hand.contains(cardId),
              let consumedCard = cardsById[cardId],
              let consumerSlotAddress = choice.consumeFishFromHandProgress?.consumerSlot,
              let consumerSlot = playerState.ocean.slots.first(where: { $0.address == consumerSlotAddress }),
              case let .fishCard(consumerCardId) = consumerSlot.content,
              let consumerCard = cardsById[consumerCardId]
        else {
            return false
        }
        return consumedCard.lengthCm < consumerCard.lengthCm
    }

    private func freePlayHandCardIsLegal(_ cardId: CardID, for choice: PendingChoice) -> Bool {
        guard choice.kind == .playFishForFree,
              choice.expectedInput == .freePlayHandCard,
              freePlaySourceConditionSatisfied(for: choice),
              state.playerGameStates[choice.playerId]?.hand.contains(cardId) == true,
              let card = cardsById[cardId],
              let filter = freePlayFilter(for: choice)
        else {
            return false
        }
        return freePlayFilterMatches(card, filter: filter)
    }

    private func freePlayFilter(for choice: PendingChoice) -> FreePlayFishFilter? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishForFree(filter, _, _, _) = effect else {
            return nil
        }
        return filter
    }

    private func freePlayPlacementConstraint(for choice: PendingChoice) -> FishPlacementConstraint? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishForFree(_, placement, _, _) = effect else {
            return nil
        }
        return placement
    }

    private func freePlaySourceCondition(for choice: PendingChoice) -> FreePlaySourceCondition? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishForFree(_, _, sourceCondition, _) = effect else {
            return nil
        }
        return sourceCondition
    }

    private func freePlayFilterMatches(_ card: Card, filter: FreePlayFishFilter) -> Bool {
        switch filter {
        case .any:
            return true
        case let .tag(kind):
            return card.tags.contains { $0.kind == kind && $0.count > 0 }
        case let .lengthBucket(bucket):
            return lengthBucket(for: card.lengthCm) == bucket
        case .unsupported:
            return false
        }
    }

    private func lengthBucket(for lengthCm: Int) -> FishLengthBucket {
        if lengthCm < 50 {
            return .small
        }
        if lengthCm < 150 {
            return .medium
        }
        return .large
    }

    private func freePlayFilterText(_ filter: FreePlayFishFilter) -> String {
        switch filter {
        case .any:
            return AppStrings.GameBoard.playFishForFreeHandCard
        case let .tag(kind):
            return cardTagName(kind)
        case let .lengthBucket(bucket):
            switch bucket {
            case .small:
                return "小型鱼"
            case .medium:
                return "中型鱼"
            case .large:
                return "大型鱼"
            }
        case .unsupported:
            return AppStrings.GameBoard.abilityUnsupported
        }
    }

    private func freePlayTargetIsLegal(_ address: OceanSlotAddress, for choice: PendingChoice) -> Bool {
        guard choice.kind == .playFishForFree,
              choice.expectedInput == .freePlayTargetSlot,
              let playerState = state.playerGameStates[choice.playerId],
              freePlaySourceConditionSatisfied(for: choice),
              let selectedCardId = choice.playFishForFreeProgress?.selectedCardId,
              state.playerGameStates[choice.playerId]?.hand.contains(selectedCardId) == true,
              let card = cardsById[selectedCardId],
              let slot = playerState.ocean.slots.first(where: { $0.address == address }),
              freePlayPlacementConstraintMatches(address, for: choice, playerState: playerState)
        else {
            return false
        }
        return playFishSlotPreview(for: slot, card: card).isSelectable
    }

    private func freePlayPlacementConstraintMatches(
        _ address: OceanSlotAddress,
        for choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        switch freePlayPlacementConstraint(for: choice) ?? .any {
        case .any:
            return true
        case .topRow:
            return address.rowIndex == 0
        case .bottomRow:
            return address.rowIndex == 5
        case .sunlight:
            return address.zone == .sunlit
        case let .diveSite(diveSite):
            return address.diveSite == diveSite
        case let .diveSiteWithCoralAtLeast(requiredCoral):
            guard let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == address.diveSite }) else {
                return false
            }
            return reef.coralCount >= requiredCoral
        case .sameDiveSiteAsSource:
            return address.diveSite == sourceAddress(for: choice)?.diveSite
        }
    }

    private func freePlaySourceConditionSatisfied(for choice: PendingChoice) -> Bool {
        guard let playerState = state.playerGameStates[choice.playerId] else {
            return false
        }
        switch freePlaySourceCondition(for: choice) ?? .none {
        case .none:
            return true
        case .sourceDiveSiteHasNoCoral:
            guard let sourceAddress = sourceAddress(for: choice),
                  let sourceSlot = playerState.ocean.slots.first(where: { $0.address == sourceAddress }),
                  case let .fishCard(visibleCardId) = sourceSlot.content,
                  visibleCardId == sourceCardId(for: choice),
                  let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == sourceAddress.diveSite })
            else {
                return false
            }
            return reef.coralCount == 0
        }
    }

    private func sourceAddress(for choice: PendingChoice) -> OceanSlotAddress? {
        choice.compoundAbilityProgress?.sourceAddress
    }

    private func sourceCardId(for choice: PendingChoice) -> CardID? {
        choice.compoundAbilityProgress?.sourceCardId
    }

    private func diveSiteSortIndex(_ diveSite: DiveSite) -> Int {
        switch diveSite {
        case .blue:
            return 0
        case .purple:
            return 1
        case .green:
            return 2
        }
    }

    private func hasAnyLegalMoveYoungOrSchool(playerState: PlayerGameState) -> Bool {
        for sourceSlot in playerState.ocean.slots {
            for kind in [ResourceKind.young, .school] where resourceAmount(kind, in: sourceSlot) > 0 {
                for targetSlot in playerState.ocean.slots where targetSlot.address != sourceSlot.address {
                    if moveDistance(from: sourceSlot.address, to: targetSlot.address) == 1 {
                        if kind == .school, resourceAmount(.school, in: targetSlot) > 0 {
                            continue
                        }
                        return true
                    }
                }
            }
        }
        return false
    }

    private func hasAnyLegalCoralGain(
        selector: CoralDiveSiteSelector,
        playerState: PlayerGameState
    ) -> Bool {
        if let fixedDiveSite = selector.fixedDiveSite {
            guard let reef = playerState.ocean.coralReefs.first(where: { $0.diveSite == fixedDiveSite }) else {
                return false
            }
            return reef.coralCount < reef.maxCoral
        }
        return playerState.ocean.coralReefs.contains { $0.coralCount < $0.maxCoral }
    }

    private func hasAnyLegalConsumeFishFromHand(playerState: PlayerGameState) -> Bool {
        let handCards = playerState.hand.compactMap { cardsById[$0] }
        guard !handCards.isEmpty else {
            return false
        }

        for slot in playerState.ocean.slots {
            guard case let .fishCard(consumerCardId) = slot.content,
                  let consumerCard = cardsById[consumerCardId]
            else {
                continue
            }
            if handCards.contains(where: { $0.lengthCm < consumerCard.lengthCm }) {
                return true
            }
        }
        return false
    }

    private func hasAnyLegalPlayFishForFree(
        choice: PendingChoice,
        playerState: PlayerGameState
    ) -> Bool {
        guard freePlaySourceConditionSatisfied(for: choice) else {
            return false
        }

        for cardId in playerState.hand {
            guard let card = cardsById[cardId],
                  let filter = freePlayFilter(for: choice),
                  freePlayFilterMatches(card, filter: filter)
            else {
                continue
            }
            if playerState.ocean.slots.contains(where: { slot in
                freePlayPlacementConstraintMatches(slot.address, for: choice, playerState: playerState)
                    && playFishSlotPreview(for: slot, card: card).isSelectable
            }) {
                return true
            }
        }
        return false
    }

    private func playFishFromHandCardIsLegal(_ cardId: CardID, for choice: PendingChoice) -> Bool {
        guard choice.kind == .playFishFromHand,
              choice.expectedInput == .playFishFromHandCard,
              state.playerGameStates[choice.playerId]?.hand.contains(cardId) == true,
              let card = cardsById[cardId],
              let filter = handFishFilter(for: choice)
        else {
            return false
        }
        return handFishFilterMatches(card, filter: filter)
    }

    private func handFishFilter(for choice: PendingChoice) -> HandFishFilter? {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishFromHand(filter, _, _) = effect else {
            return nil
        }
        return filter
    }

    private func handFishFilterMatches(_ card: Card, filter: HandFishFilter) -> Bool {
        switch filter {
        case .any:
            return true
        case let .tag(kind):
            return card.tags.contains { $0.kind == kind && $0.count > 0 }
        case let .lengthBucket(bucket):
            return lengthBucket(for: card.lengthCm) == bucket
        case .unsupported:
            return false
        }
    }

    private func handFishFilterText(_ filter: HandFishFilter) -> String {
        switch filter {
        case .any:
            return AppStrings.GameBoard.playFishFromHandHandCard
        case let .tag(kind):
            return cardTagName(kind)
        case let .lengthBucket(bucket):
            switch bucket {
            case .small:
                return "小型鱼"
            case .medium:
                return "中型鱼"
            case .large:
                return "大型鱼"
            }
        case .unsupported:
            return AppStrings.GameBoard.abilityUnsupported
        }
    }

    private func playFishFromHandTargetIsLegal(
        _ slot: OceanSlot,
        card: Card,
        for choice: PendingChoice
    ) -> Bool {
        guard choice.kind == .playFishFromHand,
              slot.address.playerId == choice.playerId,
              placementConstraintMatches(slot.address, for: choice)
        else {
            return false
        }
        return playFishSlotPreview(for: slot, card: card).isSelectable
    }

    private func placementConstraintMatches(_ address: OceanSlotAddress, for choice: PendingChoice) -> Bool {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard case let .playFishFromHand(_, placement, _) = effect else {
            return false
        }
        switch placement {
        case .any:
            return true
        case .topRow:
            return address.rowIndex == 0
        case .bottomRow:
            return address.rowIndex == 5
        case .sunlight:
            return address.zone == .sunlit
        case let .diveSite(diveSite):
            return address.diveSite == diveSite
        case let .diveSiteWithCoralAtLeast(requiredCoral):
            guard let reef = state.playerGameStates[address.playerId]?.ocean.coralReefs.first(where: { $0.diveSite == address.diveSite }) else {
                return false
            }
            return reef.coralCount >= requiredCoral
        case .sameDiveSiteAsSource:
            return sourceAddress(for: choice)?.diveSite == address.diveSite
        }
    }

    private func matchingEggTargetIsLegal(_ slot: OceanSlot, for choice: PendingChoice) -> Bool {
        let effect = choice.selectedAbilityEffect ?? choice.abilityDefinition?.effects.first
        guard slot.address.playerId == choice.playerId,
              slot.content.hasFish,
              resourceAmount(.egg, in: slot) == 0,
              case let .placeEggOnMatchingFish(filter, _) = effect
        else {
            return false
        }
        return eggPlacementFilterMatches(slot, filter: filter)
    }

    private func eggPlacementFilterMatches(_ slot: OceanSlot, filter: EggPlacementFilter) -> Bool {
        switch filter {
        case let .lengthBucket(bucket):
            guard let lengthCm = fishLengthForEggFilter(in: slot.content) else {
                return false
            }
            return lengthBucket(for: lengthCm) == bucket
        case .topRow:
            return slot.address.rowIndex == 0
        case .bottomRow:
            return slot.address.rowIndex == 5
        case let .diveSite(diveSite):
            return slot.address.diveSite == diveSite
        case let .tag(kind):
            guard case let .fishCard(cardId) = slot.content,
                  let card = cardsById[cardId]
            else {
                return false
            }
            return card.tags.contains { $0.kind == kind && $0.count > 0 }
        }
    }

    private func fishLengthForEggFilter(in content: OceanSlotContent) -> Int? {
        switch content {
        case .empty:
            return nil
        case let .forageFish(fish):
            return fish.lengthCm
        case let .fishCard(cardId):
            return cardsById[cardId]?.lengthCm
        }
    }

    private func rewardSelectionHighlightText(for slot: OceanSlot) -> String? {
        guard let rewardSelectionMode else {
            return nil
        }

        switch rewardSelectionMode {
        case let .target(choiceId, _, _):
            guard let choice = state.pendingChoices[choiceId],
                  pendingChoiceTargetIsLegal(slot, for: choice)
            else {
                return nil
            }
            return AppStrings.GameBoard.chooseLeftTarget
        case let .moveSource(choiceId, _):
            guard let choice = state.pendingChoices[choiceId],
                  slot.address.playerId == choice.playerId,
                  preferredMoveResourceKind(in: slot) != nil
            else {
                return nil
            }
            return AppStrings.GameBoard.chooseSource
        case let .moveTarget(choiceId, _, sourceAddress, kind):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  let source = playerState.ocean.slots.first(where: { $0.address == sourceAddress }),
                  moveTargetIsLegal(slot, from: source, kind: kind)
            else {
                return nil
            }
            return AppStrings.GameBoard.chooseTarget
        case let .coralResource(choiceId, _, kind):
            guard let choice = state.pendingChoices[choiceId],
                  slot.address.playerId == choice.playerId,
                  resourceAmount(kind, in: slot) > 0
            else {
                return nil
            }
            return AppStrings.GameBoard.chooseCoralResourceSource
        case .coralHandCard:
            return nil
        case let .scatterSchoolSource(choiceId, _):
            guard let choice = state.pendingChoices[choiceId],
                  slot.address.playerId == choice.playerId,
                  resourceAmount(.school, in: slot) > 0
            else {
                return nil
            }
            return AppStrings.GameBoard.scatterSchoolSource
        case let .scatterSchoolYoungTarget(choiceId, _):
            guard let choice = state.pendingChoices[choiceId],
                  let playerState = state.playerGameStates[choice.playerId],
                  scatterSchoolYoungTargetIsLegal(slot, for: choice, playerState: playerState)
            else {
                return nil
            }
            return AppStrings.GameBoard.scatterSchoolYoungTarget
        case let .consumeFishConsumer(choiceId, _):
            guard let choice = state.pendingChoices[choiceId],
                  consumeFishConsumerIsLegal(slot, for: choice)
            else {
                return nil
            }
            return AppStrings.GameBoard.consumeFishConsumer
        case .consumeFishHandCard:
            return nil
        case .freePlayHandCard:
            return nil
        case let .freePlayTarget(choiceId, _, cardId):
            guard let choice = state.pendingChoices[choiceId],
                  slot.address.playerId == choice.playerId,
                  let card = cardsById[cardId],
                  playFishSlotPreview(for: slot, card: card).isSelectable
            else {
                return nil
            }
            return AppStrings.GameBoard.playFishForFreeTarget
        case .playFishFromHandCard:
            return nil
        case let .playFishFromHandTarget(choiceId, _, cardId):
            guard let choice = state.pendingChoices[choiceId],
                  slot.address.playerId == choice.playerId,
                  let card = cardsById[cardId],
                  playFishFromHandTargetIsLegal(slot, card: card, for: choice)
            else {
                return nil
            }
            return AppStrings.GameBoard.playFishFromHandTarget
        case .playFishFromHandPayment:
            return nil
        }
    }

    private func dropTargetReasonText(preview: PlayFishSlotPreview) -> String {
        guard preview.isSelectable else {
            return "\(AppStrings.GameBoard.slotCannotPlayHere)：\(preview.message)"
        }
        if preview.message == AppStrings.GameBoard.canCoverShorterFish {
            return preview.message
        }
        return AppStrings.GameBoard.dragToPlayHere
    }

    private func resourceTokens(for slot: OceanSlot) -> [SlotResourceTokenViewState] {
        var tokens: [SlotResourceTokenViewState] = []
        for kind in displayResourceKinds {
            let tokenCount = resourceTokenCount(kind, in: slot)
            guard tokenCount > 0 else {
                continue
            }
            for tokenIndex in 0..<tokenCount {
                tokens.append(resourceToken(for: slot, kind: kind, tokenIndex: tokenIndex))
            }
        }
        return tokens
    }

    private func resourceToken(
        for slot: OceanSlot,
        kind: ResourceKind,
        tokenIndex: Int
    ) -> SlotResourceTokenViewState {
        let key = ResourcePaymentTokenKey(
            address: slot.address,
            kind: kind,
            tokenIndex: tokenIndex
        )
        let isSelected = selectedResourcePaymentTokens.contains(key)
        let isSelectable = resourceTokenIsSelectable(kind: kind, isSelected: isSelected)
        return SlotResourceTokenViewState(
            address: slot.address,
            kind: kind,
            tokenIndex: tokenIndex,
            title: resourceName(kind),
            iconText: resourceIconText(kind),
            isSelectable: isSelectable,
            isSelectedForPayment: isSelected,
            selectionMarkerText: isSelected ? AppStrings.GameBoard.paymentSelectionMarker : nil,
            unavailableReasonText: resourceTokenUnavailableReason(
                kind: kind,
                isSelected: isSelected,
                isSelectable: isSelectable
            ),
            warningText: resourceTokenWarningText(kind: kind, in: slot)
        )
    }

    private func resourceTokenIsSelectable(
        kind: ResourceKind,
        isSelected: Bool
    ) -> Bool {
        guard !hasBlockingPendingChoices,
              state.activeDiveQueue == nil,
              isSelectingPlayFish,
              resourcePaymentKinds.contains(kind),
              resourceCostCount(kind, for: selectedCard) > 0
        else {
            return false
        }
        if isSelected {
            return true
        }
        return selectedResourcePaymentTokens.filter { $0.kind == kind }.count < resourceCostCount(kind, for: selectedCard)
    }

    private func resourceTokenUnavailableReason(
        kind: ResourceKind,
        isSelected: Bool,
        isSelectable: Bool
    ) -> String? {
        guard !isSelectable else {
            return nil
        }
        if isSelected {
            return nil
        }
        if hasBlockingPendingChoices {
            return AppStrings.GameBoard.resolveCurrentRewardFirst
        }
        guard isSelectingPlayFish else {
            return nil
        }
        guard resourcePaymentKinds.contains(kind) else {
            return AppStrings.GameBoard.resourceTokenUnsupportedPayment
        }
        let requiredCount = resourceCostCount(kind, for: selectedCard)
        guard requiredCount > 0 else {
            return AppStrings.GameBoard.resourceTokenNotRequired
        }
        if selectedSources(for: kind).count >= requiredCount {
            return AppStrings.GameBoard.resourcePaymentAlreadyComplete
        }
        return nil
    }

    private func resourceTokenWarningText(kind: ResourceKind, in slot: OceanSlot) -> String? {
        let amount = resourceAmount(kind, in: slot)
        if kind == .egg, amount > 1 {
            return AppStrings.GameBoard.resourceTokenIllegalMultipleEggs
        }
        if kind == .school, amount > 1 {
            return AppStrings.GameBoard.resourceTokenIllegalMultipleSchools
        }
        if kind == .young, amount >= 3, !slot.hasSchool {
            return AppStrings.GameBoard.resourceTokenIllegalYoungWithoutSchool
        }
        return nil
    }

    private func resourceTokenCount(_ kind: ResourceKind, in slot: OceanSlot) -> Int {
        let amount = max(resourceAmount(kind, in: slot), 0)
        if kind == .egg || kind == .school {
            return min(amount, 1)
        }
        return amount
    }

    private func resourceTokenCount(
        _ kind: ResourceKind,
        at address: OceanSlotAddress,
        in playerState: PlayerGameState
    ) -> Int {
        guard let slot = playerState.ocean.slots.first(where: { $0.address == address }) else {
            return 0
        }
        return resourceTokenCount(kind, in: slot)
    }

    private func bottomAreaViewState(for diveSite: DiveActionSite) -> DiveSiteBottomAreaViewState {
        let definition = bottomBonusDefinition(for: diveSite)
        let bonusKind = definition?.kind ?? .unsupported
        let isAlreadyReached = activePlayerState?.diveSitesReachedBottomThisWeek.contains(diveSite) ?? false
        let isHighlighted = highlightedBottomBonusDiveSite == diveSite
        return DiveSiteBottomAreaViewState(
            diveSite: diveSite,
            diveSiteTitle: AppStrings.diveActionSiteName(diveSite),
            bonusTitle: bottomBonusTitle(for: bonusKind),
            bonusKind: bonusKind,
            bonusDetailText: bottomBonusDetailText(for: bonusKind),
            isFirstBottomThisWeekAvailable: !isAlreadyReached,
            isAlreadyReachedThisWeek: isAlreadyReached,
            statusText: isAlreadyReached
                ? AppStrings.GameBoard.bottomBonusClaimedThisWeek
                : AppStrings.GameBoard.bottomBonusAvailableThisWeek,
            isHighlightedByDiveQueue: isHighlighted,
            highlightReasonText: isHighlighted ? AppStrings.GameBoard.triggeringFirstBottomBonus : nil
        )
    }

    private func bottomBonusDefinition(for diveSite: DiveActionSite) -> DiveBonusDefinition? {
        DiveSiteBonusLayout.baseGame
            .bonuses(for: diveSite)
            .first { bonus in
                if case .bottom = bonus.position {
                    return true
                }
                return false
            }
    }

    private func bottomBonusTitle(for kind: DiveBonusKind) -> String {
        switch kind {
        case .recoverFromDiscardOrDraw:
            return AppStrings.GameBoard.recoverFromDiscardOrDraw
        case .placeEgg:
            return AppStrings.GameBoard.gainOneEgg
        case .moveYoungOrSchool:
            return AppStrings.GameBoard.moveYoungOrSchool
        case .drawFish:
            return AppStrings.GameBoard.drawOneFishCard
        case .hatchEgg:
            return AppStrings.pendingChoiceKindName(.hatchEgg)
        case .unsupported:
            return AppStrings.GameBoard.unsupportedSkippableChoice
        }
    }

    private func bottomBonusDetailText(for kind: DiveBonusKind) -> String? {
        switch kind {
        case .recoverFromDiscardOrDraw:
            return AppStrings.GameBoard.discardPileEmptyDrawAlternative
        case .placeEgg,
             .moveYoungOrSchool,
             .drawFish,
             .hatchEgg,
             .unsupported:
            return nil
        }
    }

    private func slotIsHighlightedByDiveQueue(_ slot: OceanSlot) -> Bool {
        guard let queue = state.activeDiveQueue,
              let currentStep = queue.currentStep,
              let highlightedDiveSite = DiveSiteBonusLayout.baseGame.oceanDiveSite(for: queue.diveSite),
              slot.address.diveSite == highlightedDiveSite
        else {
            return false
        }

        switch currentStep.source {
        case let .printedDiveBonus(zone):
            return slot.address.zone == zone
        case .bottomBonus,
             .coralReefOverlay,
             .fishAbility,
             .compoundFishAbility:
            return false
        }
    }

    private func slotDiveQueueHighlightText(_ slot: OceanSlot) -> String? {
        guard let queue = state.activeDiveQueue,
              let currentStep = queue.currentStep,
              let highlightedDiveSite = DiveSiteBonusLayout.baseGame.oceanDiveSite(for: queue.diveSite),
              slot.address.diveSite == highlightedDiveSite
        else {
            return nil
        }

        if case let .printedDiveBonus(zone) = currentStep.source,
           slot.address.zone == zone {
            return "正在触发：\(AppStrings.oceanZoneName(zone))奖励"
        }
        if case .coralReefOverlay = currentStep.source {
            return AppStrings.GameBoard.gainCoral
        }
        return nil
    }

    private func slotTitle(_ address: OceanSlotAddress) -> String {
        AppStrings.oceanRowLabel(rowIndex: address.rowIndex)
    }

    private func slotLocationText(_ address: OceanSlotAddress) -> String {
        "\(AppStrings.oceanDiveSiteName(address.diveSite)) · \(slotTitle(address))"
    }

    private func slotSort(_ left: OceanSlot, _ right: OceanSlot) -> Bool {
        if left.address.diveSite.rawValue == right.address.diveSite.rawValue {
            return left.address.rowIndex < right.address.rowIndex
        }
        return diveSiteSortIndex(left.address.diveSite) < diveSiteSortIndex(right.address.diveSite)
    }

    private func zoneName(_ zone: OceanZone) -> String {
        AppStrings.oceanZoneName(zone)
    }

    private func playerSortIndex(_ playerId: PlayerID) -> Int {
        players.firstIndex(where: { $0.playerId == playerId })
            ?? state.players.firstIndex(where: { $0.id == playerId })
            ?? Int.max
    }

    private func displayName(for playerId: PlayerID) -> String {
        players.first(where: { $0.playerId == playerId })?.displayName
            ?? state.players.first(where: { $0.id == playerId })?.name
            ?? playerId
    }

    private func gameEndAbilityRows() -> [GameEndAbilityRowViewState] {
        state.players.flatMap { player in
            guard let playerState = state.playerGameStates[player.id] else {
                return [] as [GameEndAbilityRowViewState]
            }
            return playerState.ocean.slots.flatMap { slot -> [GameEndAbilityRowViewState] in
                guard case let .fishCard(cardId) = slot.content,
                      let card = cardsById[cardId]
                else {
                    return []
                }
                return abilityResolver.abilityDefinitions(for: card, trigger: .gameEnd).map { ability in
                    let source = GameEndAbilitySource(
                        playerId: player.id,
                        slotAddress: slot.address,
                        cardId: cardId,
                        abilityId: ability.abilityId
                    )
                    let isActivated = state.activatedGameEndAbilitySourceIds.contains(source.id)
                    let isScoringOnly = ability.effects.allSatisfy { effect in
                        if case .gameEndScore = effect {
                            return true
                        }
                        return false
                    }
                    let isSupported = !ability.effects.contains(.unsupported) && !isScoringOnly
                    let canActivate = state.pendingChoices.isEmpty && isSupported && !isActivated
                    let statusText: String
                    if isActivated {
                        statusText = AppStrings.GameBoard.gameEndAbilityActivated
                    } else if isScoringOnly {
                        statusText = AppStrings.GameBoard.gameEndAbilityAutomaticScoring
                    } else if isSupported {
                        statusText = AppStrings.GameBoard.gameEndAbilityAvailable
                    } else {
                        statusText = AppStrings.GameBoard.gameEndAbilityUnsupported
                    }
                    return GameEndAbilityRowViewState(
                        source: source,
                        fishName: card.name,
                        abilitySummary: gameEndAbilitySummary(for: ability, card: card),
                        statusText: statusText,
                        isActivated: isActivated,
                        isSupported: isSupported,
                        canActivate: canActivate
                    )
                }
            }
        }
    }

    private func gameEndAbilitySummary(for ability: AbilityDefinition, card: Card) -> String {
        if !ability.displayText.isEmpty {
            return ability.displayText
        }
        return card.abilityText ?? AppStrings.GameBoard.gameEndAbilityUnsupported
    }

    private func finalScoreLegendItems(shouldShowCoralScores: Bool) -> [ScoreLegendItemViewState] {
        var items = [
            ScoreLegendItemViewState(
                title: AppStrings.GameBoard.finalScoreWeeklyAchievements,
                displayColorKey: .weeklyAchievements
            ),
            ScoreLegendItemViewState(
                title: AppStrings.GameBoard.finalScoreFishPrintedPoints,
                displayColorKey: .fishPrintedPoints
            ),
            ScoreLegendItemViewState(
                title: AppStrings.GameBoard.finalScoreGameEndAbility,
                displayColorKey: .gameEndAbilityPoints
            ),
            ScoreLegendItemViewState(
                title: AppStrings.GameBoard.finalScoreEggsAndYoung,
                displayColorKey: .eggsAndYoung
            ),
            ScoreLegendItemViewState(
                title: AppStrings.GameBoard.finalScoreSchools,
                displayColorKey: .schools
            ),
            ScoreLegendItemViewState(
                title: AppStrings.GameBoard.finalScoreConsumedFish,
                displayColorKey: .consumedFish
            )
        ]
        if shouldShowCoralScores {
            items.append(
                ScoreLegendItemViewState(
                    title: AppStrings.GameBoard.finalScoreCoral,
                    displayColorKey: .coral
                )
            )
            items.append(
                ScoreLegendItemViewState(
                    title: AppStrings.GameBoard.finalScoreCompleteReefBonus,
                    displayColorKey: .completeReefBonus
                )
            )
        }
        return items
    }

    private func finalScoreSegments(
        for result: FinalScoreBreakdown,
        maximumTotal: Int,
        shouldShowCoralScores: Bool
    ) -> [ScoreBarSegmentViewState] {
        var segmentValues: [(ScoreBarCategory, String, Int, ScoreBarColorStyle)] = [
            (
                .weeklyAchievements,
                AppStrings.GameBoard.finalScoreWeeklyAchievements,
                result.weeklyAchievementPoints,
                .weeklyAchievements
            ),
            (
                .fishPrintedPoints,
                AppStrings.GameBoard.finalScoreFishPrintedPoints,
                result.fishPrintedPoints,
                .fishPrintedPoints
            ),
            (
                .gameEndAbilityPoints,
                AppStrings.GameBoard.finalScoreGameEndAbility,
                result.gameEndAbilityPoints,
                .gameEndAbilityPoints
            ),
            (
                .eggsAndYoung,
                AppStrings.GameBoard.finalScoreEggsAndYoung,
                result.eggPoints + result.youngPoints,
                .eggsAndYoung
            ),
            (
                .schools,
                AppStrings.GameBoard.finalScoreSchools,
                result.schoolPoints,
                .schools
            ),
            (
                .consumedFish,
                AppStrings.GameBoard.finalScoreConsumedFish,
                result.consumedFishPoints,
                .consumedFish
            )
        ]
        if shouldShowCoralScores {
            segmentValues.append(
                (
                    .coral,
                    AppStrings.GameBoard.finalScoreCoral,
                    result.coralPoints,
                    .coral
                )
            )
            segmentValues.append(
                (
                    .completeReefBonus,
                    AppStrings.GameBoard.finalScoreCompleteReefBonus,
                    result.completeReefBonusPoints,
                    .completeReefBonus
                )
            )
        }

        return segmentValues.map { category, title, points, colorStyle in
            ScoreBarSegmentViewState(
                category: category,
                title: title,
                points: points,
                widthRatioRelativeToMaxTotal: scoreBarWidthRatio(
                    points: points,
                    maximumTotal: maximumTotal
                ),
                displayColorKey: colorStyle
            )
        }
    }

    private func shouldShowCoralScoreSegments(for result: FinalScoreResult) -> Bool {
        let isSharksAndReefsEnabled = roomService.gameRoom?.gameConfig.enabledExpansions.contains(.sharksAndReefs) ?? false
        let hasScoredCoral = result.results.contains {
            $0.coralPoints > 0 || $0.completeReefBonusPoints > 0
        }
        let hasCoralReefs = state.playerGameStates.values.contains {
            !$0.ocean.coralReefs.isEmpty
        }
        return isSharksAndReefsEnabled && (hasScoredCoral || hasCoralReefs)
    }

    private func scoreBarWidthRatio(points: Int, maximumTotal: Int) -> Double {
        guard maximumTotal > 0 else {
            return 0
        }
        return min(max(Double(points) / Double(maximumTotal), 0), 1)
    }

    private func discardCostCount(for card: Card?) -> Int? {
        card?.costs.compactMap { cost in
            if case let .discardCards(count) = cost {
                return count
            }
            return nil
        }.first
    }

    private func resourceCostCount(_ kind: ResourceKind, for card: Card?) -> Int {
        card?.costs.reduce(0) { partialResult, cost in
            if case let .resource(costKind, count) = cost, costKind == kind {
                return partialResult + count
            }
            return partialResult
        } ?? 0
    }

    private func cardHasUnsupportedCostInUI(_ card: Card?) -> Bool {
        guard let card else {
            return false
        }
        return card.costs.contains { cost in
            switch cost {
            case .discardCards:
                return false
            case let .resource(kind, _):
                return kind != .egg && kind != .young
            case .coverShorterFish:
                return false
            }
        }
    }

    private func cardHasUnsupportedRequirementInUI(_ card: Card?) -> Bool {
        guard let card else {
            return false
        }
        return card.requirements.contains { $0.coralRequirement == nil }
    }

    private func selectedCardUnsupportedItems(_ card: Card) -> [String] {
        var items: [String] = []
        if cardHasUnsupportedRequirementInUI(card) {
            items.append(AppStrings.GameBoard.unsupportedRequirementInUI)
        }
        if abilityResolver.abilityDefinitions(for: card).contains(where: abilityIsUnsupported) {
            items.append(AppStrings.GameBoard.unsupportedAbilityInUI)
        }
        return items
    }

    private func abilityDisplayText(_ ability: AbilityDefinition) -> String {
        if abilityIsUnsupported(ability) {
            return AppStrings.GameBoard.abilityUnsupported
        }
        return ability.displayText
    }

    private func abilityIsUnsupported(_ ability: AbilityDefinition) -> Bool {
        ability.effects.contains { effect in
            if case .unsupported = effect {
                return true
            }
            return false
        }
    }

    private func countPrompt(_ label: String, _ count: Int?) -> String? {
        guard let count, count > 0 else {
            return nil
        }
        return "\(label)：\(count)"
    }

    private func countPrompt(_ label: String, _ count: Int) -> String? {
        guard count > 0 else {
            return nil
        }
        return "\(label)：\(count)"
    }

    private func resourceSourceOptions(for kind: ResourceKind) -> [ResourceSourceViewData] {
        guard resourceCostCount(kind, for: selectedCard) > 0,
              let activePlayerState
        else {
            return []
        }

        let selectedSources = selectedSources(for: kind)
        return activePlayerState.ocean.slots.compactMap { slot in
            let availableCount = slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
            guard availableCount > 0 else {
                return nil
            }
            return ResourceSourceViewData(
                address: slot.address,
                resourceKind: kind,
                title: slotTitle(slot.address),
                availableCount: availableCount,
                selectedCount: selectedSources.filter { $0 == slot.address }.count
            )
        }
    }

    private func selectedSources(for kind: ResourceKind) -> [OceanSlotAddress] {
        if kind == .egg {
            return selectedEggSources
        }
        if kind == .young {
            return selectedYoungSources
        }
        return []
    }

    private func cycleResourceSource(_ address: OceanSlotAddress, kind: ResourceKind) {
        guard let activePlayerState else {
            return
        }
        let requiredCount = resourceCostCount(kind, for: selectedCard)
        guard requiredCount > 0 else {
            return
        }

        let availableCount = resourceTokenCount(kind, at: address, in: activePlayerState)
        guard availableCount > 0, resourcePaymentKinds.contains(kind) else {
            return
        }

        let selectedKeysForSlot = selectedResourcePaymentTokens.filter {
            $0.address == address && $0.kind == kind
        }
        if selectedKeysForSlot.count >= min(availableCount, requiredCount)
            || (!selectedKeysForSlot.isEmpty && selectedResourcePaymentTokens.filter({ $0.kind == kind }).count >= requiredCount) {
            selectedResourcePaymentTokens.subtract(selectedKeysForSlot)
            syncSelectedResourceSourcesFromTokens()
            errorMessage = nil
            return
        }

        guard selectedResourcePaymentTokens.filter({ $0.kind == kind }).count < requiredCount else {
            return
        }

        let selectedIndexes = Set(selectedKeysForSlot.map(\.tokenIndex))
        guard let nextTokenIndex = (0..<availableCount).first(where: { !selectedIndexes.contains($0) }) else {
            return
        }
        selectedResourcePaymentTokens.insert(
            ResourcePaymentTokenKey(address: address, kind: kind, tokenIndex: nextTokenIndex)
        )
        syncSelectedResourceSourcesFromTokens()
        errorMessage = nil
    }

    private func clearResourcePaymentSelection() {
        selectedResourcePaymentTokens = []
        selectedEggSources = []
        selectedYoungSources = []
    }

    private func trimSelectedResourcePaymentTokensToRequiredCounts() {
        for kind in resourcePaymentKinds {
            let requiredCount = resourceCostCount(kind, for: selectedCard)
            let selectedKeys = selectedResourcePaymentTokens
                .filter { $0.kind == kind }
                .sorted(by: resourcePaymentTokenSort)
            guard selectedKeys.count > requiredCount else {
                continue
            }
            for key in selectedKeys.dropFirst(requiredCount) {
                selectedResourcePaymentTokens.remove(key)
            }
        }
    }

    private func syncSelectedResourceSourcesFromTokens() {
        let selectedKeys = selectedResourcePaymentTokens.sorted(by: resourcePaymentTokenSort)
        selectedEggSources = selectedKeys
            .filter { $0.kind == .egg }
            .map(\.address)
        selectedYoungSources = selectedKeys
            .filter { $0.kind == .young }
            .map(\.address)
    }

    private func resourcePaymentTokenSort(
        _ left: ResourcePaymentTokenKey,
        _ right: ResourcePaymentTokenKey
    ) -> Bool {
        if left.address.diveSite != right.address.diveSite {
            return diveSiteSortIndex(left.address.diveSite) < diveSiteSortIndex(right.address.diveSite)
        }
        if left.address.rowIndex != right.address.rowIndex {
            return left.address.rowIndex < right.address.rowIndex
        }
        if left.kind.rawValue != right.kind.rawValue {
            return left.kind.rawValue < right.kind.rawValue
        }
        return left.tokenIndex < right.tokenIndex
    }

    private func resourceAmount(
        _ kind: ResourceKind,
        at address: OceanSlotAddress,
        in playerState: PlayerGameState
    ) -> Int {
        playerState.ocean.slots
            .first(where: { $0.address == address })?
            .resources
            .first(where: { $0.kind == kind })?
            .amount ?? 0
    }

    private func resourceAmount(_ kind: ResourceKind, in slot: OceanSlot) -> Int {
        slot.resources.first(where: { $0.kind == kind })?.amount ?? 0
    }

    private func localizedErrorMessage(for error: Error) -> String {
        if let validationError = error as? CommandValidationError {
            switch validationError {
            case .invalidPhase:
                return "当前阶段不能执行该行动。"
            case .notActivePlayer:
                return "只有当前行动玩家可以执行该行动。"
            case .gameNotPlaying:
                return "当前阶段不能出牌。"
            case .inactivePlayer:
                return "只有当前行动玩家可以出牌。"
            case .missingPlayerState:
                return "找不到该玩家的游戏状态。"
            case .cardNotInHand:
                return "所选鱼牌不在手牌中。"
            case .unknownCard:
                return "找不到所选鱼牌。"
            case .targetSlotNotOwnedByPlayer:
                return "目标格子不属于当前玩家。"
            case .targetSlotNotFound:
                return "找不到目标格子。"
            case .targetSlotOccupied:
                return "目标格子已被占用。"
            case .targetMustCoverShorterFish:
                return AppStrings.GameBoard.mustCoverShorterFish
            case .targetFishTooLongToCover:
                return AppStrings.GameBoard.cannotCoverLongerOrSameFish
            case .targetZoneNotAllowed:
                return "所选鱼牌不能放入该海域层。"
            case .requiredDiveSiteColorMismatch:
                return "所选鱼牌不符合该格子颜色要求。"
            case .coralRequirementMustBeSunlit:
                return AppStrings.GameBoard.reefFishMustBeSunlit
            case .coralRequirementDiveSiteMismatch:
                return AppStrings.GameBoard.slotDiveSiteMismatch
            case .coralReefMissing:
                return AppStrings.GameBoard.coralReefMissing
            case let .insufficientCoral(_, required, _):
                return AppStrings.GameBoard.coralRequirementText(count: required)
            case .paymentCardNotInHand:
                return "弃牌支付中包含不在手牌中的卡牌。"
            case .paymentCannotDiscardPlayedCard:
                return "不能弃置正在打出的鱼牌。"
            case .paymentDiscardCountMismatch:
                return AppStrings.GameBoard.discardPaymentIncomplete
            case .paymentResourceCountMismatch,
                 .paymentResourceUnavailable:
                return "资源支付不足。"
            case .unsupportedRequirement:
                return "该鱼牌条件暂未支持。"
            case .unsupportedCost:
                return AppStrings.GameBoard.costUnsupportedInUI
            case .invalidDiveSite:
                return "请选择合法的潜水点。"
            case .pendingChoiceNotFound:
                return AppStrings.GameBoard.pendingChoiceNotFound
            case .pendingChoiceNotOwned:
                return AppStrings.GameBoard.pendingChoiceNotOwned
            case .pendingChoiceRequired:
                return AppStrings.GameBoard.pendingChoiceRequired
            case .invalidPendingChoiceResolution:
                return AppStrings.GameBoard.pendingChoiceResolutionInvalid
            case .fishDrawPileEmpty:
                return AppStrings.GameBoard.fishDrawPileEmpty
            case .unresolvedPendingChoices:
                return AppStrings.GameBoard.resolveCurrentRewardFirst
            case .noAvailableDiver:
                return AppStrings.GameBoard.diversUsedThisWeek
            case .passTurnNotAllowed:
                return AppStrings.GameBoard.passTurnNotAllowed
            }
        }
        return "操作失败：\(String(describing: error))"
    }

    private func nextCommandId() -> CommandID {
        commandCounter += 1
        return "game-board-command-\(commandCounter)"
    }
}

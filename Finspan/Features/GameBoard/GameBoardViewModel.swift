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

struct HandCardViewState: Identifiable, Equatable {
    var id: CardID { cardId }

    static let fixedCardWidth: Double = 164
    static let fixedCardHeight: Double = 224
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

struct OceanSlotViewData: Identifiable, Equatable {
    var id: String {
        "\(address.playerId)-\(address.diveSite.rawValue)-\(address.rowIndex)"
    }

    let address: OceanSlotAddress
    let title: String
    let subtitle: String
    let resourcesText: String
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
    let slots: [OceanSlotViewData]
    let zoneSections: [OceanZoneSectionViewData]
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
    case coverLengthTooShort
    case zoneMismatch
    case diveSiteMismatch
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
    var id: String { "\(choiceId)-\(action.rawValue)" }

    let choiceId: PendingChoiceID
    let action: PendingChoiceAction
    let title: String
    let isEnabled: Bool
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
}

enum ScoreBarColorStyle: String, Codable, Equatable, Sendable {
    case weeklyAchievements
    case fishPrintedPoints
    case gameEndAbilityPoints
    case eggsAndYoung
    case schools
    case consumedFish
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
    case unsupported
}

private enum RewardTokenAction: Equatable {
    case direct(choiceId: PendingChoiceID, resolution: PendingChoiceResolution)
    case chooseTarget(choiceId: PendingChoiceID, kind: PendingChoiceKind)
    case chooseMoveSource(choiceId: PendingChoiceID)
    case unsupported
}

private enum RewardSelectionMode: Equatable {
    case target(choiceId: PendingChoiceID, tokenId: String, kind: PendingChoiceKind)
    case moveSource(choiceId: PendingChoiceID, tokenId: String)
    case moveTarget(choiceId: PendingChoiceID, tokenId: String, source: OceanSlotAddress, kind: ResourceKind)
}

enum PendingChoiceAction: String, Equatable {
    case drawFish
    case drawFromDeck
    case chooseTarget
    case choosePlaceEggAbilityEffect
    case chooseHatchEggAbilityEffect
    case finishAbility
    case skip
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

    private let roomService: any RoomService
    private let cardCatalog: any CardCatalog
    private let abilityResolver: AbilityResolver
    private var commandCounter = 0
    private var cardsById: [CardID: Card] {
        Dictionary(
            uniqueKeysWithValues: (cardCatalog.starterFishCards + cardCatalog.fishCards).map { ($0.id, $0) }
        )
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

    var canDive: Bool {
        state.phase == .playing
            && !isSelectingPlayFish
            && !hasBlockingPendingChoices
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
                    progressLines: compoundAbilityProgressLines(for: choice),
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
                segments: finalScoreSegments(for: result, maximumTotal: ratioDivisor)
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
            legendItems: finalScoreLegendItems
        )
    }

    var activePlayerState: PlayerGameState? {
        guard let activePlayerId = state.activePlayerId else {
            return nil
        }
        return state.playerGameStates[activePlayerId]
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
        guard state.phase == .playing,
              selectedCard != nil,
              selectedTargetSlotIsAvailable,
              !hasBlockingPendingChoices,
              state.activeDiveQueue == nil,
              (activePlayerState?.availableDivers ?? 0) > 0,
              !selectedCardHasUnsupportedUICost
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

    private var canSelectHandCards: Bool {
        state.phase == .playing
            && activePlayerState != nil
            && !hasBlockingPendingChoices
            && state.activeDiveQueue == nil
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
        72
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
        0.72
    }

    private var selectedTargetSlotIsAvailable: Bool {
        guard let selectedTargetSlot,
              let activePlayerState,
              let slot = activePlayerState.ocean.slots.first(where: { $0.address == selectedTargetSlot })
        else {
            return false
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
        self.init(roomService: roomService, cardCatalog: SampleCardCatalog())
    }

    init(
        roomService: any RoomService,
        cardCatalog: any CardCatalog,
        abilityResolver: AbilityResolver = AbilityResolver()
    ) {
        self.roomService = roomService
        self.cardCatalog = cardCatalog
        self.abilityResolver = abilityResolver
        refresh()
    }

    func refresh() {
        state = roomService.gameState
        players = roomService.gameRoom?.players ?? []
        eventLog = roomService.eventLog
        removeInvalidSelections()
    }

    func selectHandCard(_ cardId: CardID) {
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
            rewardSelectionMode = nil
            resolvePendingChoice(choiceId, resolution: resolution)
        case let .chooseTarget(choiceId, kind):
            rewardSelectionMode = .target(choiceId: choiceId, tokenId: tokenId, kind: kind)
            errorMessage = AppStrings.GameBoard.chooseLeftTarget
        case let .chooseMoveSource(choiceId):
            rewardSelectionMode = .moveSource(choiceId: choiceId, tokenId: tokenId)
            errorMessage = AppStrings.GameBoard.chooseSource
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
        }
    }

    func cancelPlayFishSelection() {
        clearPlayFishSelection()
        errorMessage = nil
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

    func performPendingChoiceAction(_ action: PendingChoiceAction, for choiceId: PendingChoiceID) {
        switch action {
        case .drawFish:
            resolvePendingChoice(choiceId, resolution: .draw(count: 1))
        case .drawFromDeck:
            resolvePendingChoice(choiceId, resolution: .drawFromDeck)
        case .skip:
            resolvePendingChoice(choiceId, resolution: .skip)
        case .chooseTarget:
            errorMessage = AppStrings.GameBoard.chooseTargetFromList
        case .choosePlaceEggAbilityEffect:
            resolvePendingChoice(choiceId, resolution: .chooseAbilityEffect(.placeEgg(count: 1)))
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
            visibleHeightRatio: isPulledOutFromStack ? 1 : 0.48,
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
        if !card.requirements.isEmpty {
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

        guard card.requirements.isEmpty else {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .unsupportedRequirement,
                message: AppStrings.GameBoard.unsupportedRequirementInUI
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

        if let existingLength = visibleFishLength(in: slot.content),
           card.lengthCm <= existingLength {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .coverLengthTooShort,
                message: AppStrings.GameBoard.cannotCoverLongerOrSameFish
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
        return [
            "\(AppStrings.GameBoard.pendingChoicePlayer)：\(playerName)",
            "\(AppStrings.GameBoard.pendingChoiceSource)：\(AppStrings.pendingChoiceSourceName(choice.source))",
            "\(AppStrings.GameBoard.pendingChoiceStatus)：\(AppStrings.GameBoard.pendingChoiceWaiting)",
            optionalText
        ].joined(separator: "，")
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
                title: AppStrings.GameBoard.hatchEggAbilityAction,
                kind: .hatchEgg(count: 1),
                progress: progress
            )
        ].compactMap { $0 }
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
             let .hatchEgg(count),
             let .moveYoungOrSchool(count),
             let .recoverFromDiscardOrDraw(count):
            return count
        case .unsupported:
            return 0
        }
    }

    private func abilityEffectKey(_ effect: AbilityEffectUnit) -> String {
        switch effect {
        case .drawFish:
            return "drawFish"
        case .placeEgg:
            return "placeEgg"
        case .hatchEgg:
            return "hatchEgg"
        case .moveYoungOrSchool:
            return "moveYoungOrSchool"
        case .recoverFromDiscardOrDraw:
            return "recoverFromDiscardOrDraw"
        case .unsupported:
            return "unsupported"
        }
    }

    private func canResolvePendingChoice(_ choice: PendingChoice) -> Bool {
        state.activePlayerId == choice.playerId
    }

    private func pendingChoiceActionButtons(for choice: PendingChoice) -> [PendingChoiceActionViewData] {
        var actions: [PendingChoiceActionViewData] = []
        let canResolve = canResolvePendingChoice(choice)

        switch choice.kind {
        case .drawFish:
            actions.append(
                PendingChoiceActionViewData(
                    choiceId: choice.choiceId,
                    action: .drawFish,
                    title: AppStrings.GameBoard.drawOneFishCard,
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
             .hatchEgg,
             .moveYoungOrSchool:
            break
        case .compoundAbility:
            if let progress = choice.compoundAbilityProgress {
                if abilityEffectCount(.placeEgg(count: 1), in: progress.remainingEffects) > 0 {
                    actions.append(
                        PendingChoiceActionViewData(
                            choiceId: choice.choiceId,
                            action: .choosePlaceEggAbilityEffect,
                            title: AppStrings.GameBoard.placeEggAbilityAction,
                            isEnabled: canResolve
                        )
                    )
                }
                if abilityEffectCount(.hatchEgg(count: 1), in: progress.remainingEffects) > 0 {
                    actions.append(
                        PendingChoiceActionViewData(
                            choiceId: choice.choiceId,
                            action: .chooseHatchEggAbilityEffect,
                            title: AppStrings.GameBoard.hatchEggAbilityAction,
                            isEnabled: canResolve
                        )
                    )
                }
                actions.append(
                    PendingChoiceActionViewData(
                        choiceId: choice.choiceId,
                        action: .finishAbility,
                        title: AppStrings.GameBoard.finishAbility,
                        isEnabled: canResolve && choice.isOptional
                    )
                )
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

        if choice.isOptional {
            actions.append(
                PendingChoiceActionViewData(
                    choiceId: choice.choiceId,
                    action: .skip,
                    title: AppStrings.GameBoard.skipChoice,
                    isEnabled: canResolve
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
            let tokenId = "\(choice.choiceId)-drawFish"
            return [(
                rewardToken(
                    id: tokenId,
                    kind: .drawFish,
                    title: AppStrings.GameBoard.drawOneFishCard,
                    subtitle: rewardSourceText(for: choice),
                    iconText: "牌",
                    symbolName: "rectangle.stack",
                    isSelectable: canResolve
                ),
                .direct(choiceId: choice.choiceId, resolution: .draw(count: 1))
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
        case .compoundAbility:
            var entries: [(token: RewardTokenViewState, action: RewardTokenAction)] = []
            if let progress = choice.compoundAbilityProgress {
                let remainingPlaceEggs = abilityEffectCount(.placeEgg(count: 1), in: progress.remainingEffects)
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

                let remainingHatches = abilityEffectCount(.hatchEgg(count: 1), in: progress.remainingEffects)
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

    func pendingChoiceTargets(for choice: PendingChoice) -> [PendingChoiceTargetViewData] {
        guard let playerState = state.playerGameStates[choice.playerId],
              choice.kind == .placeEgg || choice.kind == .hatchEgg
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
        case .hatchEgg:
            return resourceAmount(.egg, in: slot) > 0
        case .drawFish,
             .recoverFromDiscardOrDraw,
             .moveYoungOrSchool,
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
        case .hatchEgg:
            return AppStrings.GameBoard.chooseHatchEggTarget
        case .recoverFromDiscardOrDraw:
            return state.playerGameStates[choice.playerId]?.discardPile.isEmpty == true
                ? AppStrings.GameBoard.discardPileEmptyDrawHint
                : AppStrings.GameBoard.chooseDiscardCardToRecover
        case .moveYoungOrSchool:
            return AppStrings.GameBoard.moveYoungOrSchool
        case .drawFish,
             .compoundAbility,
             .bottomBonus,
             .placeholder,
             .unsupported:
            return nil
        }
    }

    private func noPendingChoiceTargetsText(for choice: PendingChoice) -> String? {
        if choice.kind == .placeEgg || choice.kind == .hatchEgg {
            return pendingChoiceTargets(for: choice).isEmpty ? AppStrings.GameBoard.noPendingChoiceTargets : nil
        }
        if choice.kind == .moveYoungOrSchool {
            return pendingChoiceMoveTargets(for: choice).isEmpty ? AppStrings.GameBoard.noMovableYoungOrSchool : nil
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
            }
        }

        switch choice.kind {
        case .drawFish,
             .recoverFromDiscardOrDraw,
             .compoundAbility:
            return AppStrings.GameBoard.chooseRewardToken
        case .placeEgg,
             .hatchEgg:
            return AppStrings.GameBoard.chooseRewardThenTarget
        case .moveYoungOrSchool:
            return AppStrings.GameBoard.chooseRewardThenSource
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

    private var finalScoreLegendItems: [ScoreLegendItemViewState] {
        [
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
    }

    private func finalScoreSegments(
        for result: FinalScoreBreakdown,
        maximumTotal: Int
    ) -> [ScoreBarSegmentViewState] {
        let segmentValues: [(ScoreBarCategory, String, Int, ScoreBarColorStyle)] = [
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
            if case let .resource(kind, _) = cost {
                return kind != .egg && kind != .young
            }
            return false
        }
    }

    private func selectedCardUnsupportedItems(_ card: Card) -> [String] {
        var items: [String] = []
        if !card.requirements.isEmpty {
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
            case .targetFishTooLongToCover:
                return AppStrings.GameBoard.cannotCoverLongerOrSameFish
            case .targetZoneNotAllowed:
                return "所选鱼牌不能放入该海域层。"
            case .requiredDiveSiteColorMismatch:
                return "所选鱼牌不符合该格子颜色要求。"
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

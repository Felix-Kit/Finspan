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
    let playFishPreview: PlayFishSlotPreview
}

struct OceanDiveSiteColumnViewData: Identifiable, Equatable {
    var id: String { diveSite.rawValue }

    let diveSite: DiveSite
    let title: String
    let slots: [OceanSlotViewData]
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
    let targetPrompt: String?
    let noTargetsText: String?
    let targets: [PendingChoiceTargetViewData]
    let canSkip: Bool
    let canResolve: Bool
    let actions: [PendingChoiceActionViewData]
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

enum PendingChoiceAction: String, Equatable {
    case drawFish
    case chooseTarget
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

    private let roomService: any RoomService
    private let cardCatalog: any CardCatalog
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
        !isSelectingPlayFish && !hasBlockingPendingChoices && (activePlayerState?.availableDivers ?? 0) > 0
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
                    title: AppStrings.pendingChoiceKindName(choice.kind),
                    subtitle: pendingChoiceSubtitle(choice),
                    sourceText: AppStrings.pendingChoiceSourceName(choice.source),
                    statusText: AppStrings.GameBoard.pendingChoiceWaiting,
                    targetPrompt: pendingChoiceTargetPrompt(for: choice),
                    noTargetsText: noPendingChoiceTargetsText(for: choice),
                    targets: pendingChoiceTargets(for: choice),
                    canSkip: choice.isOptional,
                    canResolve: canResolvePendingChoice(choice),
                    actions: pendingChoiceActionButtons(for: choice)
                )
            }
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
            OceanDiveSiteColumnViewData(
                diveSite: diveSite,
                title: AppStrings.oceanDiveSiteName(diveSite),
                slots: oceanSlots.filter { $0.address.diveSite == diveSite }
            )
        }
    }

    var selectedFishCardDetails: SelectedFishCardViewData? {
        guard let selectedCard else {
            return nil
        }

        let unsupportedItems = selectedCardUnsupportedItems(selectedCard)
        return SelectedFishCardViewData(
            title: cardTitle(selectedCard.id),
            scoreText: AppStrings.GameBoard.cardScoreUnsupported,
            lengthText: AppStrings.GameBoard.cardLengthUnsupported,
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
              !hasBlockingPendingChoices,
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

    init(roomService: any RoomService, cardCatalog: any CardCatalog) {
        self.roomService = roomService
        self.cardCatalog = cardCatalog
        refresh()
    }

    func refresh() {
        state = roomService.gameState
        players = roomService.gameRoom?.players ?? []
        eventLog = roomService.eventLog
        removeInvalidSelections()
    }

    func selectCard(_ cardId: CardID) {
        guard !hasBlockingPendingChoices else {
            errorMessage = AppStrings.GameBoard.resolveCurrentRewardFirst
            return
        }
        selectedCardId = cardId
        selectedTargetSlot = nil
        selectedDiscardCardIds = []
        selectedEggSources = []
        selectedYoungSources = []
        errorMessage = nil
    }

    func selectTargetSlot(_ address: OceanSlotAddress) {
        guard let activePlayerState,
              let slot = activePlayerState.ocean.slots.first(where: { $0.address == address }),
              playFishSlotPreview(for: slot).isSelectable
        else {
            return
        }
        selectedTargetSlot = address
        errorMessage = nil
    }

    func cancelPlayFishSelection() {
        clearPlayFishSelection()
        errorMessage = nil
    }

    func toggleDiscardPaymentCard(_ cardId: CardID) {
        if selectedDiscardCardIds.contains(cardId) {
            selectedDiscardCardIds.remove(cardId)
        } else {
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

    func submitPlayFish() {
        guard !hasBlockingPendingChoices else {
            errorMessage = AppStrings.GameBoard.resolveCurrentRewardFirst
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
        case .skip:
            resolvePendingChoice(choiceId, resolution: .skip)
        case .chooseTarget:
            errorMessage = AppStrings.GameBoard.chooseTargetFromList
        }
    }

    func resolvePendingChoice(_ choiceId: PendingChoiceID, target: OceanSlotAddress) {
        resolvePendingChoice(choiceId, resolution: .chooseTarget(target))
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
            if let nextWeek = event.nextWeek {
                payload = "第 \(event.endedWeek) 周结束，进入第 \(nextWeek) 周"
            } else if event.isGameEndTriggered {
                payload = "第 \(event.endedWeek) 周结束，游戏结束待结算"
            } else {
                payload = "第 \(event.endedWeek) 周结束"
            }
        case .gameEnded:
            payload = "游戏结束"
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
            selectedDiscardCardIds = []
            selectedEggSources = []
            selectedYoungSources = []
        }

        selectedDiscardCardIds = selectedDiscardCardIds.filter {
            activePlayerState.hand.contains($0) && $0 != selectedCardId
        }
        selectedEggSources = selectedEggSources.filter {
            resourceAmount(.egg, at: $0, in: activePlayerState) > 0
        }
        selectedYoungSources = selectedYoungSources.filter {
            resourceAmount(.young, at: $0, in: activePlayerState) > 0
        }

        if let selectedTargetSlot,
           !activePlayerState.ocean.slots.contains(where: { $0.address == selectedTargetSlot && playFishSlotPreview(for: $0).isSelectable }) {
            self.selectedTargetSlot = nil
        }
    }

    private func clearPlayFishSelection() {
        selectedCardId = nil
        selectedTargetSlot = nil
        selectedDiscardCardIds = []
        selectedEggSources = []
        selectedYoungSources = []
    }

    private func cardTitle(_ cardId: CardID) -> String {
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

    private func playFishSlotPreview(for slot: OceanSlot) -> PlayFishSlotPreview {
        guard let card = selectedCard else {
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

        guard slot.content == .empty else {
            return PlayFishSlotPreview(
                availability: .unavailable,
                unavailableReason: .occupied,
                message: AppStrings.GameBoard.slotOccupied
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

        return PlayFishSlotPreview(
            availability: .available,
            unavailableReason: nil,
            message: AppStrings.GameBoard.slotAvailable
        )
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
        case .placeEgg,
             .hatchEgg:
            break
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
        case .drawFish,
             .bottomBonus,
             .placeholder,
             .unsupported:
            return nil
        }
    }

    private func noPendingChoiceTargetsText(for choice: PendingChoice) -> String? {
        guard choice.kind == .placeEgg || choice.kind == .hatchEgg else {
            return nil
        }
        return pendingChoiceTargets(for: choice).isEmpty ? AppStrings.GameBoard.noPendingChoiceTargets : nil
    }

    private func pendingChoiceResolutionName(_ resolution: PendingChoiceResolution) -> String {
        switch resolution {
        case .skip:
            return AppStrings.GameBoard.skipChoice
        case .chooseTarget:
            return AppStrings.GameBoard.chooseTarget
        case .draw:
            return AppStrings.GameBoard.drawFish
        case .chooseOption:
            return AppStrings.GameBoard.chooseOption
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
        OceanSlotViewData(
            address: slot.address,
            title: slotTitle(slot.address),
            subtitle: slotContentText(slot.content),
            resourcesText: resourcesText(slot.resources),
            isOccupied: slot.content != .empty,
            isSelected: selectedTargetSlot == slot.address,
            playFishPreview: playFishSlotPreview(for: slot)
        )
    }

    private func slotTitle(_ address: OceanSlotAddress) -> String {
        AppStrings.oceanRowLabel(rowIndex: address.rowIndex)
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
        if !card.abilities.isEmpty {
            items.append(AppStrings.GameBoard.unsupportedAbilityInUI)
        }
        return items
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

        let availableCount = resourceAmount(kind, at: address, in: activePlayerState)
        guard availableCount > 0 else {
            return
        }

        if kind == .egg {
            selectedEggSources = cycledSources(
                selectedEggSources,
                address: address,
                maxForSource: availableCount,
                requiredCount: requiredCount
            )
        } else if kind == .young {
            selectedYoungSources = cycledSources(
                selectedYoungSources,
                address: address,
                maxForSource: availableCount,
                requiredCount: requiredCount
            )
        }
        errorMessage = nil
    }

    private func cycledSources(
        _ sources: [OceanSlotAddress],
        address: OceanSlotAddress,
        maxForSource: Int,
        requiredCount: Int
    ) -> [OceanSlotAddress] {
        let currentCount = sources.filter { $0 == address }.count
        if currentCount >= min(maxForSource, requiredCount) {
            return sources.filter { $0 != address }
        }

        guard sources.count < requiredCount else {
            return sources
        }

        return sources + [address]
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

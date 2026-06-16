import Foundation

struct BoardCardInteractionTask: Identifiable, Equatable {
    let id: String
    let source: BoardCardInteractionSource
    let taxonomy: BoardCardInteractionTaxonomy
    let steps: [BoardCardInteractionStep]
    let controls: BoardCardInteractionControlState
    let hintText: String?
}

struct BoardCardInteractionTaxonomy: Equatable {
    let inlineEntrySurfaces: [InlineEntrySurface]
    let continuationSurfaces: [ContinuationSurface]
    let commitReversibility: CommitReversibility
    let sourceVisibility: SourceVisibility
    let requiresFallback: Bool
    let requiresOverlay: Bool
    let canStartInline: Bool
}

struct BoardCardInteractionStep: Identifiable, Equatable {
    let id: String
    let kind: BoardCardInteractionStepKind
    let tokens: [BoardCardInteractionToken]
    let sources: [BoardCardInteractionSourceOption]
    let targets: [BoardCardInteractionTarget]
    let state: BoardCardInteractionSelectionState
}

struct BoardCardInteractionToken: Identifiable, Equatable {
    let id: String
    let kind: BoardCardInteractionTokenKind
    let role: BoardCardInteractionTokenRole
    let state: BoardCardInteractionSelectionState
    let count: Int
    let title: String
}

struct BoardCardInteractionSourceOption: Identifiable, Equatable {
    let id: String
    let kind: BoardCardInteractionSourceOptionKind
    let state: BoardCardInteractionSelectionState
    let satisfiesTokenIds: [String]
}

struct BoardCardInteractionTarget: Identifiable, Equatable {
    let id: String
    let kind: BoardCardInteractionTargetKind
    let state: BoardCardInteractionSelectionState
}

struct BoardCardInteractionControlState: Equatable {
    let forward: BoardCardInteractionControl
    let back: BoardCardInteractionControl
    let fallbackPanelVisible: Bool
    let compactHintText: String?
}

struct BoardCardInteractionControl: Equatable {
    let visibility: BoardCardInteractionControlVisibility
    let action: BoardCardInteractionAction?
    let isEnabled: Bool
}

enum BoardCardInteractionSource: Equatable {
    case handCard(CardID)
    case sourceFishCard(cardId: CardID, slot: OceanSlotAddress)
    case diveSite(DiveActionSite)
    case zone(diveSite: DiveActionSite, zone: OceanZone)
    case reef(DiveSite)
    case boardMarker(String)
    case incomingRewardDock(String)
    case gameEndDock(String)
    case pendingEffectNode(choiceId: PendingChoiceID, nodeId: String?)
}

enum InlineEntrySurface: String, Equatable {
    case cardAbilityIcon
    case boardZoneIcon
    case incomingRewardDock
    case gameEndDock
    case noInlineEntry
}

enum ContinuationSurface: String, Equatable {
    case directCommit
    case boardTarget
    case handPicker
    case discardOverlay
    case playFishFlow
    case paymentFlow
    case reefTarget
    case fallbackPanel
}

enum CommitReversibility: String, Equatable {
    case stagedOnlyUndo
    case committedUndoSupported
    case noCommittedUndo
}

enum SourceVisibility: String, Equatable {
    case ownVisibleSourceCard
    case opponentSourceCard
    case boardZoneOrDiveSite
    case gameEndSourceCard
    case externalPendingReward
}

enum BoardCardInteractionStepKind: String, Equatable {
    case choosePaymentSource
    case chooseRewardToken
    case chooseTargetSlot
    case chooseTargetFish
    case chooseTargetReef
    case chooseHandCard
    case chooseDiscardCard
    case confirm
    case skip
    case fallback
}

enum BoardCardInteractionTokenKind: Equatable {
    case handCardCost
    case egg
    case young
    case school
    case consume
    case fish
    case coral(DiveSite?)
    case draw
    case hatch
    case move
    case arrow
    case zoneReward
    case wave
    case score
}

enum BoardCardInteractionTokenRole: String, Equatable {
    case costOrRequirement
    case reward
    case displayOnly
}

enum BoardCardInteractionSelectionState: String, Equatable {
    case notStarted
    case available
    case selected
    case completed
    case disabled
    case fallbackRequired
}

enum BoardCardInteractionSourceOptionKind: Equatable {
    case boardResource(address: OceanSlotAddress, resourceKind: ResourceKind, tokenIndex: Int?)
    case handCard(CardID)
    case visibleFish(address: OceanSlotAddress)
    case reef(DiveSite)
}

enum BoardCardInteractionTargetKind: Equatable {
    case slot(OceanSlotAddress)
    case fish(OceanSlotAddress)
    case reef(DiveSite)
    case handCard(CardID)
    case discardCard(CardID)
}

enum BoardCardInteractionAction: Equatable {
    case confirmPlayFish
    case resolvePendingEffect(choiceId: PendingChoiceID, intent: PendingEffectIntent?)
    case skipCurrentEffect(choiceId: PendingChoiceID)
    case skipRemainingFishAbility(choiceId: PendingChoiceID)
    case skipDiveReward(choiceId: PendingChoiceID)
    case stagedUndo
    case showFallback
}

enum BoardCardInteractionControlVisibility: String, Equatable {
    case visible
    case hidden
}

struct IncomingRewardDockState: Identifiable, Equatable {
    let id: String
    let sourceSummary: IncomingRewardDockSourceSummary
    let tokens: [IncomingRewardDockToken]
    let controls: BoardCardInteractionControlState
    let fallbackReason: String?
    let isVisible: Bool
}

struct IncomingRewardDockSourceSummary: Equatable {
    let sourcePlayerId: PlayerID
    let sourcePlayerName: String
    let sourcePlayerColorName: String
    let sourceFishName: String?
    let sourceCardId: CardID?
    let triggerText: String
    let sourceVisibility: SourceVisibility
}

struct IncomingRewardDockToken: Identifiable, Equatable {
    let id: String
    let kind: BoardCardInteractionTokenKind
    let icon: GameTokenIconAsset
    let title: String
    let state: BoardCardInteractionSelectionState
    let continuationSurfaces: [ContinuationSurface]
    let action: IncomingRewardDockAction
    let fallbackReason: String?
}

enum IncomingRewardDockAction: Equatable {
    case selectRewardToken(String)
    case skipCurrentReward(PendingChoiceID)
    case stagedUndo
    case showFallback
}

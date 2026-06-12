import Combine
import Foundation

final class DiscoveredCardStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "Finspan.discoveredCardIds"
    ) {
        self.defaults = defaults
        self.key = key
    }

    var discoveredCardIds: Set<CardID> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func markDiscovered(_ cardId: CardID) {
        var ids = discoveredCardIds
        ids.insert(cardId)
        defaults.set(Array(ids).sorted(), forKey: key)
    }

    func replaceDiscoveredCardIds(_ cardIds: Set<CardID>) {
        defaults.set(Array(cardIds).sorted(), forKey: key)
    }
}

enum CardLibraryDisplayMode: String, CaseIterable, Identifiable, Equatable {
    case discovered
    case all

    var id: String { rawValue }
}

struct CardLibraryCardViewState: Identifiable, Equatable {
    var id: CardID { cardId }

    let cardId: CardID
    let cardFace: FishCardFaceViewState
    let expansionBadgeText: String
    let isDiscovered: Bool
    let isLocked: Bool
}

struct CardLibraryViewState: Equatable {
    let title: String
    let displayMode: CardLibraryDisplayMode
    let cards: [CardLibraryCardViewState]
    let emptyText: String
}

@MainActor
final class CardLibraryViewModel: ObservableObject {
    @Published var displayMode: CardLibraryDisplayMode = .discovered

    private let cards: [Card]
    private let discoveredStore: DiscoveredCardStore

    init(
        catalog: (any CardCatalog)? = nil,
        discoveredStore: DiscoveredCardStore? = nil
    ) {
        self.discoveredStore = discoveredStore ?? DiscoveredCardStore()
        if let catalog {
            cards = Self.sortedCards(from: catalog)
        } else {
            let factory = CardCatalogFactory()
            let resolvedCatalog = (try? factory.makeCatalog(for: .baseGame, enabledExpansions: [.sharksAndReefs]))
                ?? EmptyCardCatalog()
            cards = Self.sortedCards(from: resolvedCatalog)
        }
    }

    var viewState: CardLibraryViewState {
        let discoveredIds = discoveredStore.discoveredCardIds
        return CardLibraryViewState(
            title: AppStrings.Lobby.CardLibrary.title,
            displayMode: displayMode,
            cards: cards.map { card in
                let isDiscovered = discoveredIds.contains(card.id)
                return CardLibraryCardViewState(
                    cardId: card.id,
                    cardFace: fishCardFaceViewState(for: card),
                    expansionBadgeText: expansionBadgeText(for: card.id),
                    isDiscovered: isDiscovered,
                    isLocked: displayMode == .discovered && !isDiscovered
                )
            },
            emptyText: AppStrings.Lobby.CardLibrary.empty
        )
    }

    func markDiscovered(_ cardId: CardID) {
        discoveredStore.markDiscovered(cardId)
        objectWillChange.send()
    }

    private static func sortedCards(from catalog: any CardCatalog) -> [Card] {
        (catalog.starterFishCards + catalog.fishCards).sorted { left, right in
            left.id < right.id
        }
    }

    private func expansionBadgeText(for cardId: CardID) -> String {
        if cardId.hasPrefix("sr.") {
            return AppStrings.Lobby.CardLibrary.sharksAndReefsBadge
        }
        if cardId.hasPrefix("base.") {
            return AppStrings.Lobby.CardLibrary.baseBadge
        }
        return AppStrings.Lobby.CardLibrary.unknownExpansionBadge
    }

    private func fishCardFaceViewState(for card: Card) -> FishCardFaceViewState {
        let abilityText = card.abilityText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayAbilityText = abilityText?.isEmpty == false
            ? abilityText!
            : AppStrings.GameBoard.cardFaceAbilityTextMissing
        return FishCardFaceViewState(
            kind: .fishCard,
            cardId: card.id,
            displayName: card.name,
            scientificName: card.scientificName,
            printedPointsText: "\(card.printedPoints)\(AppStrings.GameBoard.cardFacePointsSuffix)",
            lengthText: "\(card.lengthCm) \(AppStrings.GameBoard.centimeters)",
            costText: card.costs.isEmpty ? AppStrings.GameBoard.noCost : card.costs.map(costText).joined(separator: "，"),
            allowedZonesText: card.allowedZones.map(AppStrings.oceanZoneName).joined(separator: "，"),
            requiredDiveSiteColor: card.requiredDiveSiteColor,
            requiredDiveSiteText: card.requiredDiveSiteColor.map(AppStrings.diveSiteColorName) ?? AppStrings.GameBoard.noLimit,
            tagsText: card.tags.isEmpty ? AppStrings.GameBoard.cardFaceNoTags : card.tags.map(\.kind).joined(separator: "，"),
            abilityTriggerText: abilityTriggerText(for: card),
            abilityText: displayAbilityText,
            costIcons: [],
            zoneIcons: [],
            tagIcons: [],
            sizeClassIcon: FishCardFaceIconViewState(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼"),
            abilitySegments: FishCardAbilityTokenParser.parse(displayAbilityText),
            backgroundAssetPrefix: backgroundAssetPrefix(for: card.requiredDiveSiteColor),
            abilityStripAssetPrefix: abilityStripAssetPrefix(for: card),
            abilityPanelStyle: abilityPanelStyle(for: card),
            localFishImagePrefix: card.visualAssetName ?? inferredFishImagePrefix(cardId: card.id),
            aspectRatio: CardRenderMetrics.cardAspectRatio,
            isPlaceholder: false
        )
    }

    private func costText(_ cost: Cost) -> String {
        switch cost {
        case .discardCards(let count):
            return "\(AppStrings.GameBoard.discardPayment) \(count)"
        case .resource(let kind, let count):
            return "\(resourceName(kind)) \(count)"
        case .coverShorterFish(let count):
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

    private func abilityTriggerText(for card: Card) -> String? {
        guard let firstAbilityId = card.abilityIds.first else {
            return nil
        }
        if firstAbilityId.contains(".whenPlayed.") {
            return AppStrings.GameBoard.abilityTriggerWhenPlayed
        }
        if firstAbilityId.contains(".ifActivated.") {
            return AppStrings.GameBoard.abilityTriggerIfActivated
        }
        if firstAbilityId.contains(".gameEnd.") {
            return AppStrings.GameBoard.abilityTriggerGameEnd
        }
        return nil
    }

    private func backgroundAssetPrefix(for requiredDiveSiteColor: DiveSiteColor?) -> String {
        switch requiredDiveSiteColor {
        case .blue:
            return "blue"
        case .purple:
            return "purple"
        case .green:
            return "green"
        case .none:
            return "base"
        }
    }

    private func abilityStripAssetPrefix(for card: Card) -> String? {
        guard let abilityTriggerText = abilityTriggerText(for: card) else {
            return nil
        }
        if abilityTriggerText == AppStrings.GameBoard.abilityTriggerGameEnd {
            return "GameEnd"
        }
        return "IfActivated"
    }

    private func abilityPanelStyle(for card: Card) -> FishCardAbilityPanelStyle {
        guard let abilityTriggerText = abilityTriggerText(for: card) else {
            return .none
        }
        if abilityTriggerText == AppStrings.GameBoard.abilityTriggerGameEnd {
            return .yellowBrush
        }
        return .tanBrush
    }

    private func inferredFishImagePrefix(cardId: CardID) -> String {
        cardId.replacingOccurrences(of: ".", with: "_")
    }
}

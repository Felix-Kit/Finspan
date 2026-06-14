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
    private let cardAssetResolver = CardAssetResolver.shared
    private let symbolAssetResolver = CardSymbolAssetResolver.shared
    private let fishImageAssetResolver = FishImageAssetResolver.shared
    private let triggerStyleResolver = CardTriggerStyleResolver.shared

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
        let triggerText = abilityTriggerText(for: card)
        let costIcons = cardCostIcons(card)
        let zoneIcons = cardZoneIcons(card)
        let tagIcons = cardTagIcons(card.tags)
        let sizeClassIcon = cardSizeClassIcon(card)
        let abilitySegments = FishCardAbilityTokenParser.parse(displayAbilityText)
        let backgroundPrefix = backgroundAssetPrefix(for: card.requiredDiveSiteColor)
        let backgroundLookup = cardAssetResolver.resolve(
            kind: .background,
            requestedName: backgroundPrefix,
            subdirectories: CardAssetDirectories.backgrounds,
            fileExtensions: ["webp", "png"]
        )
        let triggerStyle = triggerStyleResolver.style(for: triggerText)
        let fishImagePrefix = card.visualAssetName ?? inferredFishImagePrefix(cardId: card.id)
        let fishImageLookup = fishImageAssetResolver.image(
            forCardId: card.id,
            visualAssetName: card.visualAssetName
        )
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
            abilityTriggerText: triggerText,
            abilityText: displayAbilityText,
            costIcons: costIcons,
            zoneIcons: zoneIcons,
            tagIcons: tagIcons,
            sizeClassIcon: sizeClassIcon,
            abilitySegments: abilitySegments,
            backgroundAssetPrefix: backgroundPrefix,
            abilityStripAssetPrefix: triggerStyle.stripAssetPrefix,
            backgroundAsset: backgroundLookup.asset,
            abilityStripAsset: triggerStyle.stripAsset,
            abilityPanelStyle: triggerStyle.abilityPanelStyle,
            localFishImagePrefix: fishImagePrefix,
            localFishImageAsset: fishImageLookup.asset,
            missingAssets: cardFaceMissingAssets(
                backgroundLookup: backgroundLookup,
                triggerStyle: triggerStyle,
                fishImageLookup: fishImageLookup,
                icons: costIcons + zoneIcons + tagIcons + [sizeClassIcon],
                abilitySegments: abilitySegments
            ),
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

    private func cardCostIcons(_ card: Card) -> [FishCardFaceIconViewState] {
        let icons = card.costs.flatMap { cost -> [FishCardFaceIconViewState] in
            switch cost {
            case let .discardCards(count):
                return repeatedIcon(assetName: "DrawCard", fallbackText: "抽牌", accessibilityText: AppStrings.GameBoard.discardPayment, count: count)
            case let .resource(kind, count):
                return repeatedIcon(for: kind, count: count)
            case let .coverShorterFish(count):
                return repeatedIcon(assetName: "ConsumeFish", fallbackText: "吞", accessibilityText: AppStrings.GameBoard.canCoverShorterFish, count: count)
            }
        }
        return icons.isEmpty ? [cardIcon(assetName: "NoCost", fallbackText: "-", accessibilityText: AppStrings.GameBoard.noCost)] : icons
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
            return cardIcon(assetName: "Predator", fallbackText: "捕", accessibilityText: tag.kind)
        case "bioluminescent":
            return cardIcon(assetName: "Bioluminescent", fallbackText: "光", accessibilityText: tag.kind)
        case "camouflage":
            return cardIcon(assetName: "Camouflage", fallbackText: "隐", accessibilityText: tag.kind)
        case "electric":
            return cardIcon(assetName: "Electric", fallbackText: "电", accessibilityText: tag.kind)
        case "venomous":
            return cardIcon(assetName: "Venomous", fallbackText: "毒", accessibilityText: tag.kind)
        default:
            return cardIcon(assetName: "NoCost", fallbackText: tag.kind, accessibilityText: tag.kind)
        }
    }

    private func cardSizeClassIcon(_ card: Card) -> FishCardFaceIconViewState {
        if card.lengthCm < 50 {
            return cardIcon(assetName: "FishLengthSmall", fallbackText: "小", accessibilityText: "小型鱼")
        }
        if card.lengthCm < 150 {
            return cardIcon(assetName: "FishLengthMedium", fallbackText: "中", accessibilityText: "中型鱼")
        }
        return cardIcon(assetName: "FishLengthLarge", fallbackText: "大", accessibilityText: "大型鱼")
    }

    private func cardIcon(
        assetName: String,
        fallbackText: String,
        accessibilityText: String
    ) -> FishCardFaceIconViewState {
        symbolAssetResolver.icon(
            named: assetName,
            fallbackText: fallbackText,
            accessibilityText: accessibilityText
        )
    }

    private func cardFaceMissingAssets(
        backgroundLookup: CardAssetLookup,
        triggerStyle: CardTriggerStyle,
        fishImageLookup: CardAssetLookup,
        icons: [FishCardFaceIconViewState],
        abilitySegments: [FishCardAbilitySegment]
    ) -> [MissingCardAsset] {
        var missingAssets: [MissingCardAsset] = []
        appendMissing(backgroundLookup.missingAsset, to: &missingAssets)
        appendMissing(triggerStyle.missingAsset, to: &missingAssets)
        appendMissing(fishImageLookup.missingAsset, to: &missingAssets)
        icons.forEach { appendMissing($0.missingAsset, to: &missingAssets) }
        abilitySegments.forEach { segment in
            if case let .icon(icon) = segment {
                appendMissing(icon.missingAsset, to: &missingAssets)
            }
        }
        return missingAssets
    }

    private func appendMissing(_ missingAsset: MissingCardAsset?, to missingAssets: inout [MissingCardAsset]) {
        guard let missingAsset,
              !missingAssets.contains(missingAsset)
        else {
            return
        }
        missingAssets.append(missingAsset)
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

    private func inferredFishImagePrefix(cardId: CardID) -> String? {
        guard let sourceId = fishImageAssetResolver.sourceId(fromCardId: cardId) else {
            return nil
        }
        return "\(sourceId)"
    }
}

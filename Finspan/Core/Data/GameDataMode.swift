import Foundation

enum GameDataMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case sample
    case baseGame

    var id: String { rawValue }

    /// Normal room setup uses reviewed local card data. Sample data remains available
    /// to tests and explicit development fixtures through `CardCatalogFactory`.
    static let runtimeCases: [GameDataMode] = [.baseGame]
}

typealias CardCatalogMode = GameDataMode

struct CardCatalogFactory {
    func makeCatalog(for mode: GameDataMode) throws -> any CardCatalog {
        try makeCatalog(for: mode, enabledExpansions: [])
    }

    func makeCatalog(
        for mode: GameDataMode,
        enabledExpansions: [Expansion]
    ) throws -> any CardCatalog {
        switch mode {
        case .sample:
            return SampleCardCatalog()
        case .baseGame:
            let baseCatalog = try BaseGameCardCatalog()
            guard enabledExpansions.contains(.sharksAndReefs) else {
                return baseCatalog
            }
            return try CompositeCardCatalog(
                catalogs: [
                    baseCatalog,
                    SharksAndReefsCardCatalog()
                ]
            )
        }
    }
}

struct CompositeCardCatalog: CardCatalog {
    let starterFishCards: [Card]
    let fishCards: [Card]

    init(catalogs: [any CardCatalog]) throws {
        starterFishCards = catalogs.flatMap { $0.starterFishCards }
        fishCards = catalogs.flatMap { $0.fishCards }
        try validateUniqueCardIds(starterFishCards + fishCards)
    }

    private func validateUniqueCardIds(_ cards: [Card]) throws {
        var seenIds: Set<CardID> = []
        for card in cards {
            guard seenIds.insert(card.id).inserted else {
                throw CompositeCardCatalogError.duplicateCardId(card.id)
            }
        }
    }
}

enum CompositeCardCatalogError: Error, Equatable {
    case duplicateCardId(CardID)
}

protocol GameDataModeConfiguring: AnyObject {
    var gameDataMode: GameDataMode { get }
    func setGameDataMode(_ mode: GameDataMode) throws
}

final class GameDataController {
    private let factory: CardCatalogFactory
    private var catalog: any CardCatalog
    private(set) var mode: GameDataMode

    init(
        mode: GameDataMode = .baseGame,
        factory: CardCatalogFactory = CardCatalogFactory()
    ) {
        self.factory = factory
        self.mode = mode
        catalog = (try? factory.makeCatalog(for: mode)) ?? EmptyCardCatalog()
    }

    func currentCatalog() -> any CardCatalog {
        catalog
    }

    func setMode(_ mode: GameDataMode) throws {
        catalog = try factory.makeCatalog(for: mode)
        self.mode = mode
    }
}

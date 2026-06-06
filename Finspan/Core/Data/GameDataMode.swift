import Foundation

enum GameDataMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case sample
    case baseGame

    var id: String { rawValue }
}

typealias CardCatalogMode = GameDataMode

struct CardCatalogFactory {
    func makeCatalog(for mode: GameDataMode) throws -> any CardCatalog {
        switch mode {
        case .sample:
            return SampleCardCatalog()
        case .baseGame:
            return try BaseGameCardCatalog()
        }
    }
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
        mode: GameDataMode = .sample,
        factory: CardCatalogFactory = CardCatalogFactory()
    ) {
        self.factory = factory
        self.mode = mode
        catalog = (try? factory.makeCatalog(for: mode)) ?? SampleCardCatalog()
    }

    func currentCatalog() -> any CardCatalog {
        catalog
    }

    func setMode(_ mode: GameDataMode) throws {
        catalog = try factory.makeCatalog(for: mode)
        self.mode = mode
    }
}

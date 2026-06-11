import Foundation

struct ResourceQuantity: Codable, Equatable, Sendable {
    var kind: ResourceKind
    var amount: Int
}

enum DiveSite: String, Codable, CaseIterable, Equatable, Sendable {
    case blue
    case purple
    case green
}

enum OceanZone: String, Codable, CaseIterable, Equatable, Sendable {
    case sunlit
    case twilight
    case midnight
}

enum DiveSiteColor: String, Codable, CaseIterable, Equatable, Sendable {
    case blue
    case purple
    case green
}

enum OceanRowTrait: String, Codable, Equatable, Sendable {
    case none
    case topRow
    case bottomRow
}

struct DiveActionSite: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension DiveActionSite {
    static let blue = DiveActionSite(rawValue: "blue")
    static let purple = DiveActionSite(rawValue: "purple")
    static let green = DiveActionSite(rawValue: "green")

    static let baseGameSites: Set<DiveActionSite> = [.blue, .purple, .green]
}

struct OceanSlotAddress: Codable, Equatable, Hashable, Sendable {
    var playerId: PlayerID
    var diveSite: DiveSite
    var rowIndex: Int

    var zone: OceanZone {
        switch rowIndex {
        case 0...2:
            return .sunlit
        case 3:
            return .twilight
        default:
            return .midnight
        }
    }

    var zoneSlotIndex: Int {
        switch rowIndex {
        case 0...2:
            return rowIndex
        case 3:
            return 0
        default:
            return rowIndex - 4
        }
    }

    var rowTrait: OceanRowTrait {
        switch rowIndex {
        case 0:
            return .topRow
        case 5:
            return .bottomRow
        default:
            return .none
        }
    }
}

typealias BoardSlotAddress = OceanSlotAddress

struct ForageFish: Codable, Equatable, Sendable {
    var forageFishId: ForageFishID
    var name: String
    var lengthCm: Int
    var diveSite: DiveSite
    var rowIndex: Int

    var zone: OceanZone {
        OceanSlotAddress(playerId: "", diveSite: diveSite, rowIndex: rowIndex).zone
    }
}

struct ConsumedFish: Codable, Equatable, Sendable {
    var cardId: CardID?
    var forageFishId: ForageFishID?
    var name: String?
    var lengthCm: Int?

    init(cardId: CardID, lengthCm: Int? = nil) {
        self.cardId = cardId
        self.forageFishId = nil
        self.name = nil
        self.lengthCm = lengthCm
    }

    init(forageFish: ForageFish) {
        cardId = nil
        forageFishId = forageFish.forageFishId
        name = forageFish.name
        lengthCm = forageFish.lengthCm
    }
}

enum OceanSlotContent: Codable, Equatable, Sendable {
    case empty
    case forageFish(ForageFish)
    case fishCard(CardID)

    var fishCardId: CardID? {
        if case let .fishCard(cardId) = self {
            return cardId
        }
        return nil
    }

    var hasFish: Bool {
        switch self {
        case .empty:
            return false
        case .forageFish,
             .fishCard:
            return true
        }
    }
}

struct OceanSlot: Codable, Equatable, Sendable {
    var address: OceanSlotAddress
    var diveSiteColor: DiveSiteColor
    var content: OceanSlotContent
    var resources: [ResourceQuantity]
    var consumedFish: [ConsumedFish]

    var fishCardId: CardID? {
        get {
            content.fishCardId
        }
        set {
            content = newValue.map(OceanSlotContent.fishCard) ?? .empty
        }
    }

    var rowTrait: OceanRowTrait {
        address.rowTrait
    }

    var youngCount: Int {
        resources.first(where: { $0.kind == .young })?.amount ?? 0
    }

    var schoolCount: Int {
        resources.first(where: { $0.kind == .school })?.amount ?? 0
    }

    var hasSchool: Bool {
        schoolCount > 0
    }
}

struct CoralReefState: Codable, Equatable, Sendable {
    var diveSite: DiveSite
    var coralCount: Int
    var maxCoral: Int
    var completionBonus: Int

    static let maxCoral = 6

    static let sharksAndReefsInitial: [CoralReefState] = [
        CoralReefState(diveSite: .blue, coralCount: 0, maxCoral: maxCoral, completionBonus: 6),
        CoralReefState(diveSite: .purple, coralCount: 0, maxCoral: maxCoral, completionBonus: 8),
        CoralReefState(diveSite: .green, coralCount: 0, maxCoral: maxCoral, completionBonus: 5)
    ]
}

struct OceanState: Codable, Equatable, Sendable {
    var resources: [ResourceQuantity]
    var slots: [OceanSlot]
    var coralReefs: [CoralReefState]

    init(
        resources: [ResourceQuantity],
        slots: [OceanSlot],
        coralReefs: [CoralReefState] = []
    ) {
        self.resources = resources
        self.slots = slots
        self.coralReefs = coralReefs
    }

    private enum CodingKeys: String, CodingKey {
        case resources
        case slots
        case coralReefs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resources = try container.decodeIfPresent([ResourceQuantity].self, forKey: .resources) ?? []
        slots = try container.decodeIfPresent([OceanSlot].self, forKey: .slots) ?? []
        coralReefs = try container.decodeIfPresent([CoralReefState].self, forKey: .coralReefs) ?? []
    }

    static func baseGameInitial(for playerId: PlayerID) -> OceanState {
        SampleOceanLayout.baseGameInitial(for: playerId)
    }

    static func sharksAndReefsInitial(for playerId: PlayerID) -> OceanState {
        var ocean = baseGameInitial(for: playerId)
        ocean.coralReefs = CoralReefState.sharksAndReefsInitial
        return ocean
    }
}

struct PlayerGameState: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var hand: [CardID]
    var discardPile: [CardID] = []
    var availableDivers: Int
    var usedDivers: Int
    var ocean: OceanState
    var diveSitesReachedBottomThisWeek: Set<DiveActionSite> = []
}

/// Authoritative deck state for local replay.
///
/// In future online play this full hidden order should remain server-only.
/// Ordinary clients should receive only public facts and their own private hand.
struct DeckState: Codable, Equatable, Sendable {
    var starterFishDrawPile: [CardID]
    var fishDrawPile: [CardID]
    var discardPile: [CardID]

    static let empty = DeckState(
        starterFishDrawPile: [],
        fishDrawPile: [],
        discardPile: []
    )
}

struct GameSetup: Codable, Equatable, Sendable {
    var randomSeed: Int
    var startingPlayerId: PlayerID
    var playerStates: [PlayerGameState]
    var deckState: DeckState
    var weeklyGoals: [WeeklyGoalDefinition]? = nil
}

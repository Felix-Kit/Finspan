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
    var cardId: CardID
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

struct OceanState: Codable, Equatable, Sendable {
    var resources: [ResourceQuantity]
    var slots: [OceanSlot]

    static func baseGameInitial(for playerId: PlayerID) -> OceanState {
        SampleOceanLayout.baseGameInitial(for: playerId)
    }
}

enum SampleOceanLayout {
    nonisolated static let rowIndices = Array(0...5)

    nonisolated static func baseGameInitial(for playerId: PlayerID) -> OceanState {
        let startingResourceSummary = [
            ResourceQuantity(kind: .egg, amount: 2),
            ResourceQuantity(kind: .young, amount: 1)
        ]
        let forageFishLayout = baseForageFish()

        return OceanState(
            resources: startingResourceSummary,
            slots: DiveSite.allCases.flatMap { diveSite in
                rowIndices.map { rowIndex in
                    let address = OceanSlotAddress(
                        playerId: playerId,
                        diveSite: diveSite,
                        rowIndex: rowIndex
                    )
                    let forageFish = forageFishLayout.first { fish in
                        fish.diveSite == diveSite && fish.rowIndex == rowIndex
                    }
                    // Sample-only starting resources until the real base game ocean mat positions are encoded.
                    let slotResources = forageFish.map(startingResources) ?? []
                    return OceanSlot(
                        address: address,
                        diveSiteColor: diveSiteColor(for: diveSite),
                        content: forageFish.map(OceanSlotContent.forageFish) ?? .empty,
                        resources: slotResources,
                        consumedFish: []
                    )
                }
            }
        )
    }

    nonisolated static func baseForageFish() -> [ForageFish] {
        [
            ForageFish(
                forageFishId: "sample-forage-blue-row-4",
                name: "印刷小鱼一",
                lengthCm: 5,
                diveSite: .blue,
                rowIndex: 4
            ),
            ForageFish(
                forageFishId: "sample-forage-purple-row-3",
                name: "印刷小鱼二",
                lengthCm: 8,
                diveSite: .purple,
                rowIndex: 3
            ),
            ForageFish(
                forageFishId: "sample-forage-green-row-1",
                name: "印刷小鱼三",
                lengthCm: 12,
                diveSite: .green,
                rowIndex: 1
            )
        ]
    }

    nonisolated private static func diveSiteColor(for diveSite: DiveSite) -> DiveSiteColor {
        switch diveSite {
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .green:
            return .green
        }
    }

    nonisolated private static func startingResources(for fish: ForageFish) -> [ResourceQuantity] {
        switch (fish.diveSite, fish.rowIndex) {
        case (.blue, 4):
            return [ResourceQuantity(kind: .egg, amount: 1)]
        case (.purple, 3):
            return [ResourceQuantity(kind: .egg, amount: 1)]
        case (.green, 1):
            return [ResourceQuantity(kind: .young, amount: 1)]
        default:
            return []
        }
    }
}

struct PlayerGameState: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var hand: [CardID]
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
}

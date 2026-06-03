import Foundation

struct ResourceQuantity: Codable, Equatable, Sendable {
    var kind: ResourceKind
    var amount: Int
}

enum DiveSite: String, Codable, CaseIterable, Equatable, Sendable {
    case coast
    case reef
    case deep
}

enum OceanZone: String, Codable, CaseIterable, Equatable, Sendable {
    case sunlit
    case twilight
    case midnight
}

enum DiveSiteColor: String, Codable, CaseIterable, Equatable, Sendable {
    case blue
    case green
    case yellow
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
    var zone: OceanZone
    var slotIndex: Int
}

typealias BoardSlotAddress = OceanSlotAddress

struct OceanSlot: Codable, Equatable, Sendable {
    var address: OceanSlotAddress
    var diveSiteColor: DiveSiteColor
    var fishCardId: CardID?
    var resources: [ResourceQuantity]
}

struct OceanState: Codable, Equatable, Sendable {
    var forageFishCardIds: [CardID]
    var resources: [ResourceQuantity]
    var slots: [OceanSlot]

    static func baseGameInitial(for playerId: PlayerID) -> OceanState {
        let startingResources = [
            ResourceQuantity(kind: .egg, amount: 2),
            ResourceQuantity(kind: .young, amount: 1)
        ]

        return OceanState(
            forageFishCardIds: ["base-forage-placeholder"],
            resources: startingResources,
            slots: [
                OceanSlot(
                    address: OceanSlotAddress(
                        playerId: playerId,
                        diveSite: .coast,
                        zone: .sunlit,
                        slotIndex: 0
                    ),
                    diveSiteColor: .blue,
                    fishCardId: nil,
                    resources: startingResources
                ),
                OceanSlot(
                    address: OceanSlotAddress(
                        playerId: playerId,
                        diveSite: .reef,
                        zone: .twilight,
                        slotIndex: 0
                    ),
                    diveSiteColor: .green,
                    fishCardId: nil,
                    resources: []
                ),
                OceanSlot(
                    address: OceanSlotAddress(
                        playerId: playerId,
                        diveSite: .deep,
                        zone: .midnight,
                        slotIndex: 0
                    ),
                    diveSiteColor: .yellow,
                    fishCardId: nil,
                    resources: []
                )
            ]
        )
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

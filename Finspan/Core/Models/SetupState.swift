import Foundation

struct ResourceQuantity: Codable, Equatable, Sendable {
    var kind: ResourceKind
    var amount: Int
}

struct OceanState: Codable, Equatable, Sendable {
    var forageFishCardIds: [CardID]
    var resources: [ResourceQuantity]

    static let baseGameInitial = OceanState(
        forageFishCardIds: ["base-forage-placeholder"],
        resources: [
            ResourceQuantity(kind: ResourceKind(rawValue: "egg"), amount: 2),
            ResourceQuantity(kind: ResourceKind(rawValue: "young"), amount: 1)
        ]
    )
}

struct PlayerGameState: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var hand: [CardID]
    var availableDivers: Int
    var ocean: OceanState
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

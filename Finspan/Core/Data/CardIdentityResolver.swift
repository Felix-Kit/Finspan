import Foundation

struct CardIdentityResolver {
    private let cardsByCanonicalId: [CardID: Card]
    private let canonicalIdByAlias: [CardID: CardID]

    init(cards: [Card]) {
        let canonicalPairs = cards.map { ($0.id, $0) }
        cardsByCanonicalId = Dictionary(uniqueKeysWithValues: canonicalPairs)

        var aliasBuckets: [CardID: Set<CardID>] = [:]
        for card in cards {
            for alias in Self.aliases(for: card.id) {
                aliasBuckets[alias, default: []].insert(card.id)
            }
        }

        var aliasMap: [CardID: CardID] = [:]
        for (alias, canonicalIds) in aliasBuckets where canonicalIds.count == 1 {
            aliasMap[alias] = canonicalIds.first
        }
        canonicalIdByAlias = aliasMap
    }

    func card(for storedId: CardID) -> Card? {
        guard let canonicalId = canonicalId(for: storedId) else {
            return nil
        }
        return cardsByCanonicalId[canonicalId]
    }

    func canonicalId(for storedId: CardID) -> CardID? {
        canonicalIdByAlias[storedId]
    }

    var cardsByLookupId: [CardID: Card] {
        canonicalIdByAlias.reduce(into: [:]) { partialResult, entry in
            guard let card = cardsByCanonicalId[entry.value] else {
                return
            }
            partialResult[entry.key] = card
        }
    }

    private static func aliases(for canonicalId: CardID) -> Set<CardID> {
        var aliases: Set<CardID> = [canonicalId]

        guard let digitRun = trailingDigitRun(in: canonicalId) else {
            return aliases
        }

        aliases.insert(digitRun)

        if let numericValue = Int(digitRun) {
            aliases.insert(String(numericValue))
            aliases.insert("card_\(digitRun)")
            aliases.insert("card-\(digitRun)")
            aliases.insert("card\(digitRun)")
        }

        return aliases
    }

    private static func trailingDigitRun(in text: String) -> String? {
        var digits: [Character] = []

        for character in text.reversed() {
            guard character.isNumber else {
                break
            }
            digits.append(character)
        }

        guard !digits.isEmpty else {
            return nil
        }
        return String(digits.reversed())
    }
}

extension CardCatalog {
    var allCards: [Card] {
        starterFishCards + fishCards
    }

    func identityResolver() -> CardIdentityResolver {
        CardIdentityResolver(cards: allCards)
    }

    func card(forStoredId storedId: CardID) -> Card? {
        identityResolver().card(for: storedId)
    }

    func canonicalCardId(for storedId: CardID) -> CardID? {
        identityResolver().canonicalId(for: storedId)
    }
}

struct EmptyCardCatalog: CardCatalog {
    let starterFishCards: [Card] = []
    let fishCards: [Card] = []
}

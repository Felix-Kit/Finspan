import Foundation

enum CardIdentityMigrationError: Error, Equatable {
    case unresolvedCardId(CardID)
}

extension GameState {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> GameState {
        var normalized = self
        normalized.playerGameStates = try playerGameStates.mapValues { try $0.normalizedCardIdentities(using: resolver) }
        normalized.deckState = try deckState.normalizedCardIdentities(using: resolver)
        normalized.pendingChoices = try pendingChoices.mapValues { try $0.normalizedCardIdentities(using: resolver) }
        normalized.activeDiveQueue = try activeDiveQueue?.normalizedCardIdentities(using: resolver)
        return normalized
    }

    func unresolvedCardIds(using resolver: CardIdentityResolver) -> [CardID] {
        do {
            _ = try normalizedCardIdentities(using: resolver)
            return []
        } catch let CardIdentityMigrationError.unresolvedCardId(cardId) {
            return [cardId]
        } catch {
            return []
        }
    }
}

private extension PlayerGameState {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> PlayerGameState {
        var normalized = self
        normalized.hand = try hand.map { try canonicalCardId($0, using: resolver) }
        normalized.discardPile = try discardPile.map { try canonicalCardId($0, using: resolver) }
        normalized.ocean = try ocean.normalizedCardIdentities(using: resolver)
        return normalized
    }
}

private extension OceanState {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> OceanState {
        var normalized = self
        normalized.slots = try slots.map { try $0.normalizedCardIdentities(using: resolver) }
        return normalized
    }
}

private extension OceanSlot {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> OceanSlot {
        var normalized = self
        normalized.content = try content.normalizedCardIdentities(using: resolver)
        normalized.consumedFish = try consumedFish.map { try $0.normalizedCardIdentities(using: resolver) }
        return normalized
    }
}

private extension OceanSlotContent {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> OceanSlotContent {
        switch self {
        case .empty, .forageFish:
            return self
        case let .fishCard(cardId):
            return .fishCard(try canonicalCardId(cardId, using: resolver))
        }
    }
}

private extension ConsumedFish {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> ConsumedFish {
        guard let cardId else {
            return self
        }
        var normalized = self
        normalized.cardId = try canonicalCardId(cardId, using: resolver)
        return normalized
    }
}

private extension DeckState {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> DeckState {
        DeckState(
            starterFishDrawPile: try starterFishDrawPile.map { try canonicalCardId($0, using: resolver) },
            fishDrawPile: try fishDrawPile.map { try canonicalCardId($0, using: resolver) },
            discardPile: try discardPile.map { try canonicalCardId($0, using: resolver) }
        )
    }
}

private extension PendingChoice {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> PendingChoice {
        var normalized = self
        normalized.source = try source.normalizedCardIdentities(using: resolver)
        normalized.compoundAbilityProgress = try compoundAbilityProgress?.normalizedCardIdentities(using: resolver)
        normalized.consumeFishFromHandProgress = try consumeFishFromHandProgress?.normalizedCardIdentities(using: resolver)
        normalized.playFishForFreeProgress = try playFishForFreeProgress?.normalizedCardIdentities(using: resolver)
        normalized.playFishFromHandProgress = try playFishFromHandProgress?.normalizedCardIdentities(using: resolver)
        return normalized
    }
}

private extension PendingChoiceSource {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> PendingChoiceSource {
        switch self {
        case .diveBonus, .coralReef, .endGameAbility, .allPlayers, .expansion, .placeholder:
            return self
        case let .fishAbility(cardId):
            return .fishAbility(try canonicalCardId(cardId, using: resolver))
        }
    }
}

private extension CompoundAbilityProgress {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> CompoundAbilityProgress {
        var normalized = self
        normalized.sourceCardId = try canonicalCardId(sourceCardId, using: resolver)
        return normalized
    }
}

private extension ConsumeFishFromHandProgress {
    func normalizedCardIdentities(using _: CardIdentityResolver) throws -> ConsumeFishFromHandProgress {
        self
    }
}

private extension PlayFishForFreeProgress {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> PlayFishForFreeProgress {
        var normalized = self
        if let selectedCardId {
            normalized.selectedCardId = try canonicalCardId(selectedCardId, using: resolver)
        }
        return normalized
    }
}

private extension PlayFishFromHandProgress {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> PlayFishFromHandProgress {
        var normalized = self
        if let selectedCardId {
            normalized.selectedCardId = try canonicalCardId(selectedCardId, using: resolver)
        }
        return normalized
    }
}

private extension DiveResolutionQueue {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> DiveResolutionQueue {
        var normalized = self
        normalized.steps = try steps.map { try $0.normalizedCardIdentities(using: resolver) }
        return normalized
    }
}

private extension DiveResolutionStep {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> DiveResolutionStep {
        var normalized = self
        normalized.source = try source.normalizedCardIdentities(using: resolver)
        normalized.pendingChoice = try pendingChoice.normalizedCardIdentities(using: resolver)
        return normalized
    }
}

private extension DiveResolutionStepSource {
    func normalizedCardIdentities(using resolver: CardIdentityResolver) throws -> DiveResolutionStepSource {
        switch self {
        case .printedDiveBonus, .coralReefOverlay, .bottomBonus:
            return self
        case let .fishAbility(cardId, address):
            return .fishAbility(cardId: try canonicalCardId(cardId, using: resolver), address: address)
        case let .compoundFishAbility(cardId, address):
            return .compoundFishAbility(cardId: try canonicalCardId(cardId, using: resolver), address: address)
        }
    }
}

private func canonicalCardId(_ cardId: CardID, using resolver: CardIdentityResolver) throws -> CardID {
    guard let canonicalId = resolver.canonicalId(for: cardId) else {
        throw CardIdentityMigrationError.unresolvedCardId(cardId)
    }
    return canonicalId
}

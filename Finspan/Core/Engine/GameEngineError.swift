import Foundation

enum GameEngineError: Error, Equatable {
    case invalidCommand(String)
}

enum GameRuleError: Error, Equatable {
    case unsupportedRequirement(Requirement)
    case unsupportedCost(Cost)
}

enum CommandValidationError: Error, Equatable {
    case invalidPhase(GamePhase)
    case notActivePlayer(expected: PlayerID?, actual: PlayerID)
    case gameNotPlaying
    case inactivePlayer(expected: PlayerID?, actual: PlayerID)
    case missingPlayerState(PlayerID)
    case cardNotInHand(CardID)
    case unknownCard(CardID)
    case targetSlotNotOwnedByPlayer
    case targetSlotNotFound(OceanSlotAddress)
    case targetSlotOccupied(OceanSlotAddress)
    case targetMustCoverShorterFish(OceanSlotAddress)
    case targetFishTooLongToCover(target: OceanSlotAddress, newFishLengthCm: Int, existingFishLengthCm: Int)
    case targetZoneNotAllowed(OceanZone)
    case requiredDiveSiteColorMismatch(expected: DiveSiteColor, actual: DiveSiteColor)
    case coralRequirementMustBeSunlit(OceanSlotAddress)
    case coralRequirementDiveSiteMismatch(expected: CoralRequirementDiveSite, actual: DiveSite)
    case coralReefMissing(DiveSite)
    case insufficientCoral(diveSite: DiveSite, required: Int, actual: Int)
    case paymentCardNotInHand(CardID)
    case paymentCannotDiscardPlayedCard(CardID)
    case paymentDiscardCountMismatch(expected: Int, actual: Int)
    case paymentResourceCountMismatch(kind: ResourceKind, expected: Int, actual: Int)
    case paymentResourceUnavailable(kind: ResourceKind, source: OceanSlotAddress)
    case unsupportedRequirement(Requirement)
    case unsupportedCost(Cost)
    case invalidDiveSite(DiveActionSite)
    case noAvailableDiver
    case pendingChoiceNotFound(PendingChoiceID)
    case pendingChoiceNotOwned(choiceId: PendingChoiceID, expected: PlayerID, actual: PlayerID)
    case pendingChoiceRequired(PendingChoiceID)
    case invalidPendingChoiceResolution(PendingChoiceID)
    case fishDrawPileEmpty
    case unresolvedPendingChoices(PlayerID)
    case passTurnNotAllowed
}

import Foundation

enum GameEngineError: Error, Equatable {
    case invalidCommand(String)
}

enum GameRuleError: Error, Equatable {
    case unsupportedRequirement(Requirement)
    case unsupportedCost(Cost)
}

enum CommandValidationError: Error, Equatable {
    case gameNotPlaying
    case inactivePlayer(expected: PlayerID?, actual: PlayerID)
    case missingPlayerState(PlayerID)
    case cardNotInHand(CardID)
    case unknownCard(CardID)
    case targetSlotNotOwnedByPlayer
    case targetSlotNotFound(OceanSlotAddress)
    case targetSlotOccupied(OceanSlotAddress)
    case targetZoneNotAllowed(OceanZone)
    case requiredDiveSiteColorMismatch(expected: DiveSiteColor, actual: DiveSiteColor)
    case paymentCardNotInHand(CardID)
    case paymentCannotDiscardPlayedCard(CardID)
    case paymentDiscardCountMismatch(expected: Int, actual: Int)
    case paymentResourceCountMismatch(kind: ResourceKind, expected: Int, actual: Int)
    case paymentResourceUnavailable(kind: ResourceKind, source: OceanSlotAddress)
    case unsupportedRequirement(Requirement)
    case unsupportedCost(Cost)
}

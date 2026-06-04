import Foundation

enum DiveBonusKind: String, Codable, Equatable, Sendable {
    case drawFish
    case placeEgg
    case hatchEgg
    case recoverFromDiscardOrDraw
    case moveYoungOrSchool
    case unsupported
}

enum DiveBonusPosition: Codable, Equatable, Sendable {
    case zone(OceanZone)
    case bottom
}

struct DiveBonusDefinition: Codable, Equatable, Sendable {
    var diveSite: DiveActionSite
    var position: DiveBonusPosition
    var kind: DiveBonusKind
    var amount: Int
}

struct DiveSiteBonusLayout: Codable, Equatable, Sendable {
    var bonusesBySite: [DiveActionSite: [DiveBonusDefinition]]

    func bonuses(for diveSite: DiveActionSite) -> [DiveBonusDefinition] {
        bonusesBySite[diveSite] ?? []
    }

    func oceanDiveSite(for diveSite: DiveActionSite) -> DiveSite? {
        switch diveSite {
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .green:
            return .green
        default:
            return nil
        }
    }
}

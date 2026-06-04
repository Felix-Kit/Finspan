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

    static let baseGame = DiveSiteBonusLayout(
        bonusesBySite: [
            .blue: [
                DiveBonusDefinition(diveSite: .blue, position: .zone(.sunlit), kind: .drawFish, amount: 1),
                DiveBonusDefinition(diveSite: .blue, position: .zone(.twilight), kind: .drawFish, amount: 1),
                DiveBonusDefinition(diveSite: .blue, position: .zone(.midnight), kind: .drawFish, amount: 1),
                DiveBonusDefinition(diveSite: .blue, position: .bottom, kind: .recoverFromDiscardOrDraw, amount: 1)
            ],
            .green: [
                DiveBonusDefinition(diveSite: .green, position: .zone(.sunlit), kind: .placeEgg, amount: 1),
                DiveBonusDefinition(diveSite: .green, position: .zone(.twilight), kind: .placeEgg, amount: 1),
                DiveBonusDefinition(diveSite: .green, position: .zone(.midnight), kind: .placeEgg, amount: 1),
                DiveBonusDefinition(diveSite: .green, position: .bottom, kind: .placeEgg, amount: 1)
            ],
            .purple: [
                DiveBonusDefinition(diveSite: .purple, position: .zone(.sunlit), kind: .hatchEgg, amount: 1),
                DiveBonusDefinition(diveSite: .purple, position: .zone(.twilight), kind: .hatchEgg, amount: 1),
                DiveBonusDefinition(diveSite: .purple, position: .zone(.midnight), kind: .moveYoungOrSchool, amount: 1),
                DiveBonusDefinition(diveSite: .purple, position: .bottom, kind: .moveYoungOrSchool, amount: 1)
            ]
        ]
    )

    static let sampleBaseGame = baseGame
}

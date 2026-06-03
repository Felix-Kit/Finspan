import Foundation

enum DiveBonusKind: String, Codable, Equatable, Sendable {
    case drawFish
    case placeEgg
    case hatchEgg
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
            return .coast
        case .purple:
            return .reef
        case .green:
            return .deep
        default:
            return nil
        }
    }

    static let sampleBaseGame = DiveSiteBonusLayout(
        bonusesBySite: Dictionary(
            uniqueKeysWithValues: DiveActionSite.baseGameSites.map { site in
                (
                    site,
                    [
                        DiveBonusDefinition(
                            diveSite: site,
                            position: .zone(.sunlit),
                            kind: .drawFish,
                            amount: 1
                        ),
                        DiveBonusDefinition(
                            diveSite: site,
                            position: .zone(.twilight),
                            kind: .placeEgg,
                            amount: 1
                        ),
                        DiveBonusDefinition(
                            diveSite: site,
                            position: .zone(.midnight),
                            kind: .hatchEgg,
                            amount: 1
                        ),
                        DiveBonusDefinition(
                            diveSite: site,
                            position: .bottom,
                            kind: .drawFish,
                            amount: 1
                        )
                    ]
                )
            }
        )
    )
}

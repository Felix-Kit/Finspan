import Foundation

extension DiveSiteBonusLayout {
    /// Authoritative printed dive site bonus layout for the Finspan base game.
    ///
    /// Future expansion overlays belong in `Ruleset` / `RuleModule` extensions,
    /// not in this base game layout.
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
                DiveBonusDefinition(diveSite: .green, position: .bottom, kind: .moveYoungOrSchool, amount: 1)
            ],
            .purple: [
                DiveBonusDefinition(diveSite: .purple, position: .zone(.sunlit), kind: .hatchEgg, amount: 1),
                DiveBonusDefinition(diveSite: .purple, position: .zone(.twilight), kind: .hatchEgg, amount: 1),
                DiveBonusDefinition(diveSite: .purple, position: .zone(.midnight), kind: .moveYoungOrSchool, amount: 1),
                DiveBonusDefinition(diveSite: .purple, position: .bottom, kind: .placeEgg, amount: 1)
            ]
        ]
    )
}

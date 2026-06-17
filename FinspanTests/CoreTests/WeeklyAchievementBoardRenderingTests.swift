import XCTest
@testable import Finspan

@MainActor
final class WeeklyAchievementBoardRenderingTests: XCTestCase {
    func testWeeklyGoalIconsResolveThroughGameTokenIconResolver() {
        let resolver = GameTokenIconResolver.shared
        let tokens: [WeeklyGoalIconToken] = [
            .egg,
            .young,
            .school,
            .fish,
            .smallFish,
            .mediumFish,
            .largeFish,
            .predator,
            .consumedFish,
            .card,
            .discard,
            .sun,
            .blueCoral,
            .purpleCoral,
            .greenCoral,
            .anyCoral,
            .completeReefBonus,
            .gameEnd
        ]

        let icons = tokens.map { resolver.icon(for: gameTokenIconKind(for: $0)) }

        XCTAssertEqual(icons.count, tokens.count)
        XCTAssertTrue(icons.allSatisfy(\.isResolved))
    }

    func testWeeklyGoalTilesCarryIconTokensInsteadOfTextOnlyFallbacks() {
        let goals = WeeklyGoalCatalog.baseSideBGoals + WeeklyGoalCatalog.sharksAndReefsSideBGoals

        XCTAssertFalse(goals.isEmpty)
        XCTAssertTrue(goals.allSatisfy { !$0.iconTokens.isEmpty })
    }

    private func gameTokenIconKind(for token: WeeklyGoalIconToken) -> GameTokenIconKind {
        switch token {
        case .egg:
            return .egg
        case .young:
            return .young
        case .school:
            return .school
        case .fish:
            return .fish
        case .smallFish:
            return .smallFish
        case .mediumFish:
            return .mediumFish
        case .largeFish:
            return .largeFish
        case .predator:
            return .predator
        case .consumedFish:
            return .consume
        case .card:
            return .card
        case .discard:
            return .discard
        case .sun:
            return .sun
        case .twilight:
            return .twilight
        case .night:
            return .night
        case .blueCoral:
            return .coral(.blue)
        case .purpleCoral:
            return .coral(.purple)
        case .greenCoral:
            return .coral(.green)
        case .anyCoral:
            return .anyCoral
        case .completeReefBonus:
            return .completeReefBonus
        case .gameEnd:
            return .gameEnd
        case .wave:
            return .wave
        }
    }
}

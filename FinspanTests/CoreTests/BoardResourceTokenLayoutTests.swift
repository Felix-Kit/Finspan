import XCTest
@testable import Finspan

@MainActor
final class FishCardResourceOverlayLayoutTests: XCTestCase {
    func testEveryVisualTokenFrameStaysInsideCardAndFishArtwork() {
        let layout = CardRenderMetrics.BoardResourceTokenLayout.self

        for index in 0..<layout.maxVisibleTokens {
            let frame = layout.visualFrame(at: index)
            XCTAssertTrue(layout.cardBounds.contains(frame))
            XCTAssertTrue(layout.artworkRegion.contains(frame))
        }
    }

    func testTokenFramesAvoidCriticalCardRegions() {
        let layout = CardRenderMetrics.BoardResourceTokenLayout.self
        let protectedRegions = [
            layout.abilityRegion,
            layout.pointsAndLengthRegion,
            layout.tagRegion,
            layout.nameRegion,
            layout.flavorRegion
        ]

        for index in 0..<layout.maxVisibleTokens {
            let frame = layout.visualFrame(at: index)
            XCTAssertTrue(protectedRegions.allSatisfy { !frame.intersects($0) })
        }
    }

    func testVisualTokensAreLargerAndUseCompactDistinctOffsets() {
        let layout = CardRenderMetrics.BoardResourceTokenLayout.self
        let frames = (0..<layout.maxVisibleTokens).map(layout.visualFrame(at:))

        XCTAssertGreaterThanOrEqual(layout.visualSize, 8.25)
        XCTAssertEqual(Set(frames.map { "\($0.x)-\($0.y)" }).count, layout.maxVisibleTokens)
        XCTAssertLessThan(frames.map(\.maxX).max() ?? 100, layout.abilityRegion.x)
    }
}

@MainActor
final class BoardResourceTokenHitTargetTests: XCTestCase {
    func testHitTargetsShareVisualCentersAndRemainInsideArtworkAndCard() {
        let layout = CardRenderMetrics.BoardResourceTokenLayout.self

        for index in 0..<layout.maxVisibleTokens {
            let visual = layout.visualFrame(at: index)
            let hitTarget = layout.hitTargetFrame(at: index)
            XCTAssertEqual(visual.x + visual.width / 2, hitTarget.x + hitTarget.width / 2, accuracy: 0.001)
            XCTAssertEqual(visual.y + visual.height / 2, hitTarget.y + hitTarget.height / 2, accuracy: 0.001)
            XCTAssertTrue(layout.cardBounds.contains(hitTarget))
            XCTAssertTrue(layout.artworkRegion.contains(hitTarget))
            XCTAssertFalse(hitTarget.intersects(layout.abilityRegion))
        }
    }

    func testEggAndYoungTokensStillStagePaymentSources() {
        let service = weeklyResourcePaymentService(hand: ["egg-cost", "young-cost"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: BoardResourcePaymentCatalog()
        )
        let sourceAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)

        viewModel.selectCard("egg-cost")
        viewModel.toggleResourcePayment(address: sourceAddress, kind: .egg, tokenIndex: 0)
        XCTAssertEqual(viewModel.selectedEggSources, [sourceAddress])

        viewModel.selectCard("young-cost")
        viewModel.toggleResourcePayment(address: sourceAddress, kind: .young, tokenIndex: 0)
        XCTAssertEqual(viewModel.selectedYoungSources, [sourceAddress])
    }

    func testSchoolTokenRemainsVisibleButCannotBecomeUnsupportedPayment() {
        let service = weeklyResourcePaymentService(hand: ["egg-cost"])
        let viewModel = GameBoardViewModel(
            roomService: service,
            cardCatalog: BoardResourcePaymentCatalog()
        )
        let sourceAddress = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
        viewModel.selectCard("egg-cost")

        let school = viewModel.oceanSlots
            .first { $0.address == sourceAddress }?
            .resourceTokens
            .first { $0.kind == .school }
        XCTAssertNotNil(school)
        XCTAssertEqual(school?.isSelectable, false)

        viewModel.toggleResourcePayment(address: sourceAddress, kind: .school, tokenIndex: 0)
        XCTAssertTrue(viewModel.selectedEggSources.isEmpty)
        XCTAssertTrue(viewModel.selectedYoungSources.isEmpty)
    }

    private func weeklyResourcePaymentService(hand: [CardID]) -> WeeklyDisplayRoomService {
        let service = WeeklyDisplayRoomService()
        var playerState = service.gameState.playerGameStates["player-1"]!
        playerState.hand = hand
        service.gameState.playerGameStates["player-1"] = playerState
        service.snapshot.state = service.gameState
        return service
    }
}

@MainActor
final class CardTokenOverlayLayoutTests: XCTestCase {
    func testOnlyBoardSlotCardReceivesBoardResourceTokens() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()
        let slotCard = viewModel.oceanSlots.first { !$0.cardFace.resourceTokens.isEmpty }?.cardFace

        XCTAssertNotNil(slotCard)
        XCTAssertTrue(slotCard?.resourceTokens.allSatisfy { $0.placement == .fishArtworkRegion } == true)
        XCTAssertTrue(viewModel.handViewState.cards.allSatisfy { $0.cardFace.resourceTokens.isEmpty })
        XCTAssertTrue(viewModel.discardPileViewState.topCards.allSatisfy { $0.resourceTokens.isEmpty })
    }

    func testBoardTokensUseResolvedAssetsWithoutBadgeFrames() {
        let viewModel = WeeklyDisplayTestFactory.makeViewModel()
        let tokens = viewModel.oceanSlots.flatMap(\.cardFace.resourceTokens)

        XCTAssertFalse(tokens.isEmpty)
        XCTAssertTrue(tokens.allSatisfy { $0.icon.isResolved })
        XCTAssertTrue(tokens.allSatisfy { !$0.usesBadgeFrame })
    }
}

private struct BoardResourcePaymentCatalog: CardCatalog {
    let starterFishCards: [Card] = []
    let fishCards: [Card] = [
        Card(
            id: "egg-cost",
            name: "Egg Cost",
            costs: [.resource(kind: .egg, count: 1)],
            allowedZones: [.sunlit],
            lengthCm: 20
        ),
        Card(
            id: "young-cost",
            name: "Young Cost",
            costs: [.resource(kind: .young, count: 1)],
            allowedZones: [.sunlit],
            lengthCm: 20
        )
    ]
}

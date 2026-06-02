import XCTest
@testable import Finspan

final class AuthoritativeEventFactoryTests: XCTestCase {

    func testFactoryWrapsDraftsWithAuthoritativeFields() {
        var factory = AuthoritativeEventFactory(
            roomId: "room-1",
            nextSequenceNumber: 10,
            randomSeed: 123,
            timestampProvider: { Date(timeIntervalSince1970: 500) }
        )

        let events = factory.makeEvents(
            from: [
                .playerReadyChanged(
                    PlayerReadyChangedEvent(playerId: "player-1", isReady: true)
                ),
                .gameStarted(GameStartedDraft(startingPlayerId: "player-1"))
            ],
            actorPlayerId: "player-1"
        )

        XCTAssertEqual(events.map(\.sequenceNumber), [10, 11])
        XCTAssertEqual(events.map(\.roomId), ["room-1", "room-1"])
        XCTAssertEqual(events.map(\.timestamp), [
            Date(timeIntervalSince1970: 500),
            Date(timeIntervalSince1970: 500)
        ])
        XCTAssertEqual(
            events.last?.payload,
            .gameStarted(GameStartedEvent(startingPlayerId: "player-1", randomSeed: 123))
        )
        XCTAssertEqual(factory.nextSequenceNumber, 12)
    }
}

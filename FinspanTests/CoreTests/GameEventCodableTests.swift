import XCTest
@testable import Finspan

final class GameEventCodableTests: XCTestCase {

    func testGameEventCanEncodeAndDecode() throws {
        let event = GameEvent(
            sequenceNumber: 12,
            roomId: "room-1",
            timestamp: Date(timeIntervalSince1970: 1_234),
            payload: .fishPlayed(
                FishPlayedEvent(
                    playerId: "player-1",
                    cardId: "fish-card-1"
                )
            )
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(GameEvent.self, from: data)

        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.sequenceNumber, 12)
        XCTAssertEqual(decoded.roomId, "room-1")
        XCTAssertEqual(decoded.timestamp, Date(timeIntervalSince1970: 1_234))
    }

    func testSnapshotCreatedEventCanEncodeAndDecode() throws {
        let event = GameEvent(
            sequenceNumber: 20,
            roomId: "room-1",
            timestamp: Date(timeIntervalSince1970: 2_000),
            payload: .snapshotCreated(
                SnapshotCreatedEvent(snapshotSequenceNumber: 19)
            )
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(GameEvent.self, from: data)

        XCTAssertEqual(decoded, event)
    }
}

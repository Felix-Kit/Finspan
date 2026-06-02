import XCTest
@testable import Finspan

final class GameRoomModelTests: XCTestCase {

    func testGameRoomStoresAuthoritativeRoomFacts() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let host = RoomPlayer(
            playerId: "player-host",
            displayName: "Host",
            seatIndex: SeatIndex(0),
            color: .blue,
            isReady: true,
            isConnected: true,
            role: .host
        )

        let room = GameRoom(
            roomId: "room-1",
            roomCode: "ABCD",
            hostPlayerId: host.playerId,
            players: [host],
            gameConfig: GameConfig(
                playerCount: 1,
                enabledExpansions: [.sharksAndReefs],
                rulesetVersion: .baseGameV1,
                randomSeed: 42
            ),
            currentSequence: 7,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        XCTAssertEqual(room.roomId, "room-1")
        XCTAssertEqual(room.hostPlayerId, "player-host")
        XCTAssertEqual(room.players.first?.role, .host)
        XCTAssertEqual(room.currentSequence, 7)
        XCTAssertEqual(room.gameConfig.randomSeed, 42)
        XCTAssertEqual(room.createdAt, createdAt)
        XCTAssertEqual(room.updatedAt, updatedAt)
    }

    func testHostIsOnlyAPlayerRole() {
        let host = RoomPlayer(playerId: "player-1", displayName: "A", role: .host)
        let spectator = RoomPlayer(
            playerId: "player-2",
            displayName: "B",
            isConnected: false,
            role: .spectator
        )

        XCTAssertEqual(host.role, .host)
        XCTAssertEqual(spectator.role, .spectator)
        XCTAssertNotEqual(host.playerId, "server")
    }

    func testGameRoomIsCodable() throws {
        let room = GameRoom(
            roomId: "room-1",
            roomCode: "WXYZ",
            hostPlayerId: "player-1",
            players: [
                RoomPlayer(
                    playerId: "player-1",
                    displayName: "A",
                    seatIndex: SeatIndex(0),
                    color: .green,
                    role: .host
                )
            ],
            gameConfig: GameConfig(playerCount: 1, randomSeed: 99),
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let data = try JSONEncoder().encode(room)
        let decoded = try JSONDecoder().decode(GameRoom.self, from: data)

        XCTAssertEqual(decoded, room)
    }
}

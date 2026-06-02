import Foundation

struct RoomPlayer: Identifiable, Codable, Equatable, Sendable {
    let playerId: PlayerID
    var displayName: String
    var seatIndex: SeatIndex?
    var color: PlayerColor?
    var isReady: Bool
    var isConnected: Bool
    var role: RoomRole

    var id: PlayerID { playerId }

    init(
        playerId: PlayerID,
        displayName: String,
        seatIndex: SeatIndex? = nil,
        color: PlayerColor? = nil,
        isReady: Bool = false,
        isConnected: Bool = true,
        role: RoomRole = .player
    ) {
        self.playerId = playerId
        self.displayName = displayName
        self.seatIndex = seatIndex
        self.color = color
        self.isReady = isReady
        self.isConnected = isConnected
        self.role = role
    }
}

import Foundation

struct RoomPlayer: Identifiable, Codable, Equatable, Sendable {
    let playerId: PlayerID
    var displayName: String
    var avatarSymbol: String
    var seatIndex: SeatIndex?
    var color: PlayerColor?
    var isReady: Bool
    var isConnected: Bool
    var role: RoomRole

    var id: PlayerID { playerId }

    init(
        playerId: PlayerID,
        displayName: String,
        avatarSymbol: String = PlayerProfile.defaultAvatarSymbol,
        seatIndex: SeatIndex? = nil,
        color: PlayerColor? = nil,
        isReady: Bool = false,
        isConnected: Bool = true,
        role: RoomRole = .player
    ) {
        self.playerId = playerId
        self.displayName = displayName
        self.avatarSymbol = avatarSymbol
        self.seatIndex = seatIndex
        self.color = color
        self.isReady = isReady
        self.isConnected = isConnected
        self.role = role
    }

    private enum CodingKeys: String, CodingKey {
        case playerId
        case displayName
        case avatarSymbol
        case seatIndex
        case color
        case isReady
        case isConnected
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try container.decode(PlayerID.self, forKey: .playerId)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarSymbol = try container.decodeIfPresent(String.self, forKey: .avatarSymbol)
            ?? PlayerProfile.defaultAvatarSymbol
        seatIndex = try container.decodeIfPresent(SeatIndex.self, forKey: .seatIndex)
        color = try container.decodeIfPresent(PlayerColor.self, forKey: .color)
        isReady = try container.decodeIfPresent(Bool.self, forKey: .isReady) ?? false
        isConnected = try container.decodeIfPresent(Bool.self, forKey: .isConnected) ?? true
        role = try container.decodeIfPresent(RoomRole.self, forKey: .role) ?? .player
    }
}

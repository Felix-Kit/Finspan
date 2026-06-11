import Combine
import Foundation

struct PlayerProfile: Codable, Equatable, Sendable {
    var playerId: PlayerID
    var nickname: String
    var avatarSymbol: String

    static let defaultAvatarSymbol = "fish.circle.fill"
    static let defaultNickname = "玩家"
}

@MainActor
final class PlayerProfileStore: ObservableObject {
    @Published private(set) var profile: PlayerProfile?

    private let defaults: UserDefaults
    private let profileKey: String

    init(
        defaults: UserDefaults = .standard,
        profileKey: String = "localPlayerProfile"
    ) {
        self.defaults = defaults
        self.profileKey = profileKey
        profile = Self.loadProfile(defaults: defaults, key: profileKey)
    }

    func save(nickname: String, avatarSymbol: String) {
        let cleanedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = PlayerProfile(
            playerId: self.profile?.playerId ?? "local-player",
            nickname: cleanedNickname.isEmpty ? PlayerProfile.defaultNickname : cleanedNickname,
            avatarSymbol: avatarSymbol.isEmpty ? PlayerProfile.defaultAvatarSymbol : avatarSymbol
        )
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: profileKey)
        }
    }

    func clear() {
        profile = nil
        defaults.removeObject(forKey: profileKey)
    }

    private static func loadProfile(defaults: UserDefaults, key: String) -> PlayerProfile? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(PlayerProfile.self, from: data)
    }
}

enum PlayerAvatarCatalog {
    static let symbols = [
        "fish.circle.fill",
        "water.waves",
        "sailboat.fill",
        "moon.stars.fill",
        "sparkles",
        "person.crop.circle.fill"
    ]
}

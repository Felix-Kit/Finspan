import Foundation

struct CompactResourceHUDState: Equatable {
    let entries: [CompactResourceHUDEntry]
    let accessibilityText: String
}

struct CompactResourceHUDEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let count: Int
    let icon: GameTokenIconAsset

    var countText: String {
        "x \(count)"
    }
}

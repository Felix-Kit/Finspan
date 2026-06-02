import Foundation

struct SeatIndex: Codable, Equatable, Comparable, Hashable, Sendable {
    let rawValue: Int

    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    static func < (lhs: SeatIndex, rhs: SeatIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

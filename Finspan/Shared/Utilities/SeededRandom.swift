import Foundation

struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        let initialState = UInt64(bitPattern: Int64(seed))
        state = initialState == 0 ? 0x9E37_79B9_7F4A_7C15 : initialState
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive.")
        return Int(nextUInt64() % UInt64(upperBound))
    }
}

struct SeededShuffle {
    static func shuffled<T>(_ values: [T], seed: Int) -> [T] {
        guard values.count > 1 else {
            return values
        }

        var random = SeededRandom(seed: seed)
        var result = values

        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let swapIndex = random.nextInt(upperBound: index + 1)
            result.swapAt(index, swapIndex)
        }

        return result
    }
}

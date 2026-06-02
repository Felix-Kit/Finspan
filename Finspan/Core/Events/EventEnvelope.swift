import Foundation

struct EventEnvelope: Codable, Equatable, Sendable {
    let event: GameEvent

    var sequence: EventID { event.sequenceNumber }

    init(event: GameEvent) {
        self.event = event
    }
}

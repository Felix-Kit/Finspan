import Foundation

struct EventReducer {
    func reduce(_ state: GameState, event: GameEvent) -> GameState {
        GameEngine().reduce(state: state, event: event)
    }
}

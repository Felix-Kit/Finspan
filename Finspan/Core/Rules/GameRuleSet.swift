import Foundation

struct GameRuleSet {
    func validate(_ command: PlayerCommand, in state: GameState) throws {
        switch command.payload {
        case let .createRoom(payload) where payload.gameConfig.playerCount < 1:
            throw GameEngineError.invalidCommand("A room needs at least one player.")
        case .createRoom,
             .joinRoom,
             .leaveRoom,
             .setReady,
             .startGame,
             .chooseSeat,
             .chooseColor,
             .playFish,
             .dive,
             .resolvePendingChoice,
             .resolveEffectNode,
             .skipEffectNode,
             .skipEffectExecution,
             .activateGameEndAbility,
             .finishGameEndAbilities,
             .chooseAbilityOption,
             .endTurn:
            return
        }
    }
}

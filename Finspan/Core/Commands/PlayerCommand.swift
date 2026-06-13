import Foundation

struct PlayerCommand: Codable, Equatable, Sendable {
    let commandId: CommandID
    let playerId: PlayerID
    let roomId: RoomID
    let payload: PlayerCommandPayload

    init(
        commandId: CommandID,
        playerId: PlayerID,
        roomId: RoomID,
        payload: PlayerCommandPayload
    ) {
        self.commandId = commandId
        self.playerId = playerId
        self.roomId = roomId
        self.payload = payload
    }
}

enum PlayerCommandPayload: Codable, Equatable, Sendable {
    case createRoom(CreateRoomCommand)
    case joinRoom(JoinRoomCommand)
    case leaveRoom(LeaveRoomCommand)
    case setReady(SetReadyCommand)
    case startGame(StartGameCommand)
    case chooseSeat(ChooseSeatCommand)
    case chooseColor(ChooseColorCommand)
    case playFish(PlayFishCommand)
    case dive(DiveCommand)
    case resolvePendingChoice(ResolvePendingChoiceCommand)
    case resolveEffectNode(ResolveEffectNodeCommand)
    case skipEffectNode(SkipEffectNodeCommand)
    case skipEffectExecution(SkipEffectExecutionCommand)
    case activateGameEndAbility(ActivateGameEndAbilityCommand)
    case finishGameEndAbilities(FinishGameEndAbilitiesCommand)
    case chooseAbilityOption(ChooseAbilityOptionCommand)
    case endTurn(EndTurnCommand)
}

struct CreateRoomCommand: Codable, Equatable, Sendable {
    var roomCode: String
    var displayName: String
    var avatarSymbol: String
    var gameConfig: GameConfig

    init(
        roomCode: String,
        displayName: String,
        avatarSymbol: String = PlayerProfile.defaultAvatarSymbol,
        gameConfig: GameConfig
    ) {
        self.roomCode = roomCode
        self.displayName = displayName
        self.avatarSymbol = avatarSymbol
        self.gameConfig = gameConfig
    }
}

struct JoinRoomCommand: Codable, Equatable, Sendable {
    var displayName: String
    var avatarSymbol: String

    init(
        displayName: String,
        avatarSymbol: String = PlayerProfile.defaultAvatarSymbol
    ) {
        self.displayName = displayName
        self.avatarSymbol = avatarSymbol
    }
}

struct LeaveRoomCommand: Codable, Equatable, Sendable {}

struct SetReadyCommand: Codable, Equatable, Sendable {
    var isReady: Bool
}

struct StartGameCommand: Codable, Equatable, Sendable {}

struct ChooseSeatCommand: Codable, Equatable, Sendable {
    var seatIndex: SeatIndex
}

struct ChooseColorCommand: Codable, Equatable, Sendable {
    var color: PlayerColor
}

struct PlayFishCommand: Codable, Equatable, Sendable {
    var cardId: CardID
    var targetSlot: OceanSlotAddress
    var payment: PlayFishPayment
}

struct PlayFishPayment: Codable, Equatable, Sendable {
    var discardedCardIds: [CardID]
    var eggSources: [OceanSlotAddress]
    var youngSources: [OceanSlotAddress]

    static let empty = PlayFishPayment(
        discardedCardIds: [],
        eggSources: [],
        youngSources: []
    )
}

struct DiveCommand: Codable, Equatable, Sendable {
    var diveSite: DiveActionSite
}

struct ResolvePendingChoiceCommand: Codable, Equatable, Sendable {
    var choiceId: PendingChoiceID
    var resolution: PendingChoiceResolution
}

struct ResolveEffectNodeCommand: Codable, Equatable, Sendable {
    var executionId: AbilityExecutionId
    var effectNodeId: EffectNodeId
    var sourcePlayerId: PlayerID
    var targetPlayerId: PlayerID?
    var payload: EffectResolutionPayload
}

struct SkipEffectNodeCommand: Codable, Equatable, Sendable {
    var executionId: AbilityExecutionId
    var effectNodeId: EffectNodeId
    var sourcePlayerId: PlayerID
    var targetPlayerId: PlayerID?
}

struct SkipEffectExecutionCommand: Codable, Equatable, Sendable {
    var executionId: AbilityExecutionId
    var sourcePlayerId: PlayerID
    var targetPlayerId: PlayerID?
}

struct ActivateGameEndAbilityCommand: Codable, Equatable, Sendable {
    var source: GameEndAbilitySource
}

struct FinishGameEndAbilitiesCommand: Codable, Equatable, Sendable {}

struct ChooseAbilityOptionCommand: Codable, Equatable, Sendable {
    var optionId: AbilityOptionID
}

struct EndTurnCommand: Codable, Equatable, Sendable {}

extension PlayerCommand {
    static func createRoom(
        commandId: CommandID,
        playerId: PlayerID,
        roomId: RoomID,
        roomCode: String,
        displayName: String,
        avatarSymbol: String = PlayerProfile.defaultAvatarSymbol,
        gameConfig: GameConfig
    ) -> PlayerCommand {
        PlayerCommand(
            commandId: commandId,
            playerId: playerId,
            roomId: roomId,
            payload: .createRoom(
                CreateRoomCommand(
                    roomCode: roomCode,
                    displayName: displayName,
                    avatarSymbol: avatarSymbol,
                    gameConfig: gameConfig
                )
            )
        )
    }
}

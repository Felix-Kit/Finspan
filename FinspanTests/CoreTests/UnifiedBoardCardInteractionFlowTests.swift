import XCTest
@testable import Finspan

final class UnifiedBoardCardInteractionFlowTests: XCTestCase {
    private let handCardId: CardID = "base.main.001"
    private let choiceId: PendingChoiceID = "choice-1"
    private let blueTopSlot = OceanSlotAddress(playerId: "player-1", diveSite: .blue, rowIndex: 0)
    private let purpleTwilightSlot = OceanSlotAddress(playerId: "player-1", diveSite: .purple, rowIndex: 3)

    func testPlayFishStagedFlowCanExpressHandCardAndEggCost() {
        let task = playFishTask(
            tokens: [
                token(id: "discard-cost", kind: .handCardCost, role: .costOrRequirement, state: .available),
                token(id: "egg-cost", kind: .egg, role: .costOrRequirement, state: .available)
            ],
            sources: [
                source(id: "hand-payment", kind: .handCard("base.main.002"), satisfies: ["discard-cost"]),
                source(id: "egg-payment", kind: .boardResource(address: blueTopSlot, resourceKind: .egg, tokenIndex: 0), satisfies: ["egg-cost"])
            ],
            targets: []
        )

        XCTAssertEqual(task.source, .handCard(handCardId))
        XCTAssertEqual(task.steps.first?.kind, .choosePaymentSource)
        XCTAssertEqual(task.steps.first?.tokens.map(\.role), [.costOrRequirement, .costOrRequirement])
        XCTAssertEqual(task.steps.first?.sources.flatMap(\.satisfiesTokenIds), ["discard-cost", "egg-cost"])
    }

    func testPlayFishCostTokensAreProgressNotFirstClickButtons() {
        let task = playFishTask(
            tokens: [token(id: "egg-cost", kind: .egg, role: .costOrRequirement, state: .available)],
            sources: [source(id: "egg-payment", kind: .boardResource(address: blueTopSlot, resourceKind: .egg, tokenIndex: 0), satisfies: ["egg-cost"])],
            targets: []
        )

        XCTAssertEqual(task.steps.first?.kind, .choosePaymentSource)
        XCTAssertEqual(task.steps.first?.tokens.first?.role, .costOrRequirement)
        XCTAssertEqual(task.steps.first?.sources.first?.state, .available)
    }

    func testPlayFishStagedFlowCanExpressNoCostTargetAndConfirm() {
        let targetStep = BoardCardInteractionStep(
            id: "target",
            kind: .chooseTargetSlot,
            tokens: [],
            sources: [],
            targets: [target(id: "blue-slot", kind: .slot(blueTopSlot), state: .selected)],
            state: .selected
        )
        let task = BoardCardInteractionTask(
            id: "play-no-cost",
            source: .handCard(handCardId),
            taxonomy: taxonomy(
                entry: [.cardAbilityIcon],
                continuation: [.boardTarget],
                reversibility: .stagedOnlyUndo,
                visibility: .ownVisibleSourceCard
            ),
            steps: [targetStep],
            controls: BoardCardInteractionControlState(
                forward: BoardCardInteractionControl(visibility: .visible, action: .confirmPlayFish, isEnabled: true),
                back: BoardCardInteractionControl(visibility: .visible, action: .stagedUndo, isEnabled: true),
                fallbackPanelVisible: false,
                compactHintText: nil
            ),
            hintText: nil
        )

        XCTAssertEqual(task.steps.first?.kind, .chooseTargetSlot)
        XCTAssertEqual(task.steps.first?.targets.first?.state, .selected)
        XCTAssertEqual(task.controls.forward.action, .confirmPlayFish)
        XCTAssertTrue(task.controls.forward.isEnabled)
    }

    func testAbilityFlowCanExpressRewardIconSelectionAndPlaceEggTarget() {
        let task = abilityTask(
            reward: token(id: "place-egg", kind: .egg, role: .reward, state: .selected),
            targetKind: .slot(blueTopSlot)
        )

        XCTAssertEqual(task.source, .sourceFishCard(cardId: "base.main.010", slot: blueTopSlot))
        XCTAssertEqual(task.steps.map(\.kind), [.chooseRewardToken, .chooseTargetSlot])
        XCTAssertEqual(task.steps.first?.tokens.first?.role, .reward)
        XCTAssertEqual(task.steps.last?.targets.first?.kind, .slot(blueTopSlot))
    }

    func testAbilityFlowCanExpressHatchEggTargetSelection() {
        let task = abilityTask(
            reward: token(id: "hatch", kind: .hatch, role: .reward, state: .selected),
            targetKind: .slot(blueTopSlot)
        )

        XCTAssertEqual(task.steps.first?.tokens.first?.kind, .hatch)
        XCTAssertEqual(task.steps.last?.kind, .chooseTargetSlot)
    }

    func testDiveFlowCanExpressTwilightCoralPayment() {
        let task = BoardCardInteractionTask(
            id: "twilight-coral",
            source: .reef(.purple),
            taxonomy: taxonomy(
                entry: [.boardZoneIcon],
                continuation: [.paymentFlow, .reefTarget],
                reversibility: .stagedOnlyUndo,
                visibility: .boardZoneOrDiveSite
            ),
            steps: [
                BoardCardInteractionStep(
                    id: "payment",
                    kind: .choosePaymentSource,
                    tokens: [token(id: "purple-coral", kind: .coral(.purple), role: .reward, state: .selected)],
                    sources: [source(id: "young-payment", kind: .boardResource(address: purpleTwilightSlot, resourceKind: .young, tokenIndex: 0), satisfies: ["purple-coral"])],
                    targets: [target(id: "purple-reef", kind: .reef(.purple), state: .available)],
                    state: .available
                )
            ],
            controls: skipControls(action: .skipDiveReward(choiceId: choiceId)),
            hintText: "紫色珊瑚支付幼鱼"
        )

        XCTAssertEqual(task.source, .reef(.purple))
        XCTAssertEqual(task.steps.first?.kind, .choosePaymentSource)
        XCTAssertEqual(task.steps.first?.sources.first?.kind, .boardResource(address: purpleTwilightSlot, resourceKind: .young, tokenIndex: 0))
        XCTAssertEqual(task.controls.forward.action, .skipDiveReward(choiceId: choiceId))
    }

    func testForwardControlCanExpressConfirmAndSkip() {
        let confirm = BoardCardInteractionControl(visibility: .visible, action: .confirmPlayFish, isEnabled: true)
        let skip = BoardCardInteractionControl(visibility: .visible, action: .skipCurrentEffect(choiceId: choiceId), isEnabled: true)

        XCTAssertEqual(confirm.action, .confirmPlayFish)
        XCTAssertEqual(skip.action, .skipCurrentEffect(choiceId: choiceId))
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertTrue(skip.isEnabled)
    }

    func testBackControlOnlyExpressesStagedUndo() {
        let controls = BoardCardInteractionControlState(
            forward: BoardCardInteractionControl(visibility: .visible, action: .confirmPlayFish, isEnabled: false),
            back: BoardCardInteractionControl(visibility: .visible, action: .stagedUndo, isEnabled: true),
            fallbackPanelVisible: false,
            compactHintText: nil
        )

        XCTAssertEqual(controls.back.action, .stagedUndo)
        XCTAssertNotEqual(controls.back.action, .resolvePendingEffect(choiceId: choiceId, intent: nil))
    }

    func testFallbackCasesCanBeRepresented() {
        let task = BoardCardInteractionTask(
            id: "discard-picker",
            source: .pendingEffectNode(choiceId: choiceId, nodeId: "recover"),
            taxonomy: taxonomy(
                entry: [.cardAbilityIcon],
                continuation: [.discardOverlay, .directCommit, .fallbackPanel],
                reversibility: .stagedOnlyUndo,
                visibility: .ownVisibleSourceCard,
                requiresFallback: true,
                requiresOverlay: true
            ),
            steps: [
                BoardCardInteractionStep(
                    id: "fallback",
                    kind: .fallback,
                    tokens: [token(id: "draw", kind: .draw, role: .reward, state: .fallbackRequired)],
                    sources: [],
                    targets: [],
                    state: .fallbackRequired
                )
            ],
            controls: BoardCardInteractionControlState(
                forward: BoardCardInteractionControl(visibility: .visible, action: .showFallback, isEnabled: true),
                back: BoardCardInteractionControl(visibility: .hidden, action: nil, isEnabled: false),
                fallbackPanelVisible: true,
                compactHintText: "使用右侧选择面板"
            ),
            hintText: nil
        )

        XCTAssertEqual(task.steps.first?.kind, .fallback)
        XCTAssertTrue(task.controls.fallbackPanelVisible)
        XCTAssertEqual(task.steps.first?.state, .fallbackRequired)
    }

    func testBaseGameAbilityCoverageRemainsFullyMapped() throws {
        let catalog = try CardCatalogFactory().makeCatalog(
            for: .baseGame,
            enabledExpansions: [.sharksAndReefs]
        )
        let cards = catalog.starterFishCards + catalog.fishCards
        let resolver = AbilityResolver()
        let definitions = cards.flatMap { resolver.abilityDefinitions(for: $0) }
        let unsupportedDefinitions = definitions.filter { $0.effects.contains(.unsupported) }
        let gameEndUnsupported = unsupportedDefinitions.filter { $0.trigger == .gameEnd }

        XCTAssertEqual(cards.count, 215)
        XCTAssertEqual(cards.filter { !$0.abilityIds.isEmpty }.count, 215)
        XCTAssertEqual(unsupportedDefinitions.count, 0)
        XCTAssertEqual(gameEndUnsupported.count, 0)
    }

    private func playFishTask(
        tokens: [BoardCardInteractionToken],
        sources: [BoardCardInteractionSourceOption],
        targets: [BoardCardInteractionTarget]
    ) -> BoardCardInteractionTask {
        BoardCardInteractionTask(
            id: "play-fish",
            source: .handCard(handCardId),
            taxonomy: taxonomy(
                entry: [.cardAbilityIcon],
                continuation: [.paymentFlow, .boardTarget],
                reversibility: .stagedOnlyUndo,
                visibility: .ownVisibleSourceCard
            ),
            steps: [
                BoardCardInteractionStep(
                    id: "payment",
                    kind: .choosePaymentSource,
                    tokens: tokens,
                    sources: sources,
                    targets: targets,
                    state: .available
                )
            ],
            controls: BoardCardInteractionControlState(
                forward: BoardCardInteractionControl(visibility: .visible, action: .confirmPlayFish, isEnabled: false),
                back: BoardCardInteractionControl(visibility: .visible, action: .stagedUndo, isEnabled: true),
                fallbackPanelVisible: false,
                compactHintText: nil
            ),
            hintText: nil
        )
    }

    private func abilityTask(
        reward: BoardCardInteractionToken,
        targetKind: BoardCardInteractionTargetKind
    ) -> BoardCardInteractionTask {
        BoardCardInteractionTask(
            id: "ability",
            source: .sourceFishCard(cardId: "base.main.010", slot: blueTopSlot),
            taxonomy: taxonomy(
                entry: [.cardAbilityIcon],
                continuation: [.boardTarget],
                reversibility: .stagedOnlyUndo,
                visibility: .ownVisibleSourceCard
            ),
            steps: [
                BoardCardInteractionStep(
                    id: "reward",
                    kind: .chooseRewardToken,
                    tokens: [reward],
                    sources: [],
                    targets: [],
                    state: .selected
                ),
                BoardCardInteractionStep(
                    id: "target",
                    kind: .chooseTargetSlot,
                    tokens: [],
                    sources: [],
                    targets: [target(id: "target", kind: targetKind, state: .available)],
                    state: .available
                )
            ],
            controls: skipControls(action: .skipRemainingFishAbility(choiceId: choiceId)),
            hintText: nil
        )
    }

    private func token(
        id: String,
        kind: BoardCardInteractionTokenKind,
        role: BoardCardInteractionTokenRole,
        state: BoardCardInteractionSelectionState
    ) -> BoardCardInteractionToken {
        BoardCardInteractionToken(id: id, kind: kind, role: role, state: state, count: 1, title: id)
    }

    private func source(
        id: String,
        kind: BoardCardInteractionSourceOptionKind,
        satisfies tokenIds: [String]
    ) -> BoardCardInteractionSourceOption {
        BoardCardInteractionSourceOption(id: id, kind: kind, state: .available, satisfiesTokenIds: tokenIds)
    }

    private func target(
        id: String,
        kind: BoardCardInteractionTargetKind,
        state: BoardCardInteractionSelectionState
    ) -> BoardCardInteractionTarget {
        BoardCardInteractionTarget(id: id, kind: kind, state: state)
    }

    private func skipControls(action: BoardCardInteractionAction) -> BoardCardInteractionControlState {
        BoardCardInteractionControlState(
            forward: BoardCardInteractionControl(visibility: .visible, action: action, isEnabled: true),
            back: BoardCardInteractionControl(visibility: .visible, action: .stagedUndo, isEnabled: true),
            fallbackPanelVisible: false,
            compactHintText: nil
        )
    }

    private func taxonomy(
        entry: [InlineEntrySurface],
        continuation: [ContinuationSurface],
        reversibility: CommitReversibility,
        visibility: SourceVisibility,
        requiresFallback: Bool = false,
        requiresOverlay: Bool = false,
        canStartInline: Bool = true
    ) -> BoardCardInteractionTaxonomy {
        BoardCardInteractionTaxonomy(
            inlineEntrySurfaces: entry,
            continuationSurfaces: continuation,
            commitReversibility: reversibility,
            sourceVisibility: visibility,
            requiresFallback: requiresFallback,
            requiresOverlay: requiresOverlay,
            canStartInline: canStartInline
        )
    }
}

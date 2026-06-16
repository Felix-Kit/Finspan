import XCTest
@testable import Finspan

final class AbilityHitGroupTests: XCTestCase {
    func testArrowDownAbilityIconsHighlightAsAGroup() throws {
        let presentation = CardAbilityPresentationBuilder().build(
            rawAbilityText: "(all players) [FishEgg][ArrowDown][Predator] on each [AllPlayers]",
            triggerTitle: CardFaceTriggerCopy.ifActivated,
            triggerStyle: CardTriggerStyleResolver.shared.style(for: CardFaceTriggerCopy.ifActivated)
        )

        let group = try XCTUnwrap(presentation.firstIconGroup(layout: .arrowFlow))
        XCTAssertEqual(group.icons.map(\.icon.assetName), ["FishEgg", "ArrowDown", "Predator"])
        XCTAssertTrue(group.icons.allSatisfy { $0.placement == .arrowFlow })
        XCTAssertNil(presentation.firstStandaloneIcon(named: "ArrowDown"))
    }

    func testCardInlineTapIsNotRequiredForBottomDockMVP() throws {
        let source = try readProjectFile("Finspan/Features/GameBoard/GameBoardView.swift")
        let token = BottomRewardDockToken(
            id: "placeEgg",
            title: "放置鱼卵",
            subtitle: "选择棋盘目标",
            icon: GameTokenIconResolver.shared.icon(for: .egg),
            countText: nil,
            isSelectable: true,
            isSelected: false,
            isCompleted: false,
            isUnsupported: false,
            fallbackReason: nil,
            continuationSurfaces: [.boardTarget],
            action: .selectRewardToken("placeEgg")
        )

        XCTAssertEqual(token.action, .selectRewardToken("placeEgg"))
        XCTAssertFalse(source.contains("InteractiveCardAbilityOverlay"))
        XCTAssertFalse(source.contains("cardAbilityTap"))
    }

    private func readProjectFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}

private extension CardAbilityPresentation {
    func firstIconGroup(layout: CardAbilityIconGroupLayout) -> CardAbilityIconGroup? {
        blocks.flatMap(\.elements).firstIconGroup(layout: layout)
    }

    func firstStandaloneIcon(named assetName: String) -> CardAbilityIcon? {
        blocks.flatMap(\.elements).firstStandaloneIcon(named: assetName)
    }
}

private extension Array where Element == CardAbilityElement {
    func firstIconGroup(layout: CardAbilityIconGroupLayout) -> CardAbilityIconGroup? {
        for element in self {
            switch element {
            case let .iconGroup(group) where group.layout == layout:
                return group
            case let .horizontalRow(elements):
                if let group = elements.firstIconGroup(layout: layout) {
                    return group
                }
            case .text, .icon, .points, .iconGroup:
                continue
            }
        }
        return nil
    }

    func firstStandaloneIcon(named assetName: String) -> CardAbilityIcon? {
        for element in self {
            switch element {
            case let .icon(icon) where icon.icon.assetName == assetName:
                return icon
            case let .horizontalRow(elements):
                if let icon = elements.firstStandaloneIcon(named: assetName) {
                    return icon
                }
            case .text, .icon, .points, .iconGroup:
                continue
            }
        }
        return nil
    }
}

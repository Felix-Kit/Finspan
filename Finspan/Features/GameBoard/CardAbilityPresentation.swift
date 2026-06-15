import Foundation

enum CardAbilityBlockKind: String, Equatable {
    case main
    case alsoIf
}

enum CardAbilityBlockLayout: String, Equatable {
    case standard
    case squished
    case alsoIf
}

enum CardAbilityElement: Equatable {
    case text(CardAbilityText)
    case icon(CardAbilityIcon)
    case iconGroup(CardAbilityIconGroup)
    case points(CardAbilityPoints)
    case horizontalRow([CardAbilityElement])
}

struct CardAbilityText: Equatable {
    let text: String
    var isBold: Bool = false
}

struct CardAbilityIcon: Equatable {
    let icon: FishCardFaceIconViewState
    let placement: CardAbilityIconPlacement
    let style: CardAbilityIconStyle
}

enum CardAbilityIconPlacement: String, Equatable {
    case normal
    case arrowFlow
    case allPlayersBottom
    case coralGroup
    case horizontalRow
}

enum CardAbilityIconStyle: String, Equatable {
    case normal
    case allPlayersShadow
}

struct CardAbilityIconGroup: Equatable {
    let icons: [CardAbilityIcon]
    let layout: CardAbilityIconGroupLayout
    let cssClassSummary: String
}

enum CardAbilityIconGroupLayout: String, Equatable {
    case vertical
    case arrowFlow
    case horizontal
    case coralHorizontal
}

struct CardAbilityPoints: Equatable {
    let pointsText: String
    let waveIcon: FishCardFaceIconViewState
}

struct CardAbilityBlock: Equatable {
    let kind: CardAbilityBlockKind
    let layout: CardAbilityBlockLayout
    let backgroundAsset: CardAssetReference?
    let backgroundAssetPrefix: String?
    let elements: [CardAbilityElement]

    var hasBrushBackground: Bool {
        backgroundAsset != nil
    }
}

struct CardAbilityPresentation: Equatable {
    let triggerTitle: String?
    let blocks: [CardAbilityBlock]
    let blockGapCqw: Double
    let isFlatFallback: Bool

    static let empty = CardAbilityPresentation(
        triggerTitle: nil,
        blocks: [],
        blockGapCqw: 2,
        isFlatFallback: false
    )

    var alsoIfBlockCount: Int {
        blocks.filter { $0.kind == .alsoIf }.count
    }

    var hasAllPlayersShadow: Bool {
        blocks.contains { block in
            block.elements.containsAllPlayersShadow
        }
    }

    var tokenPlacementSummary: [String] {
        blocks.flatMap { block in
            block.elements.tokenPlacementSummary
        }
    }
}

struct CardAbilityPresentationBuilder {
    private let tokenResolver: AbilityTokenAssetResolver
    private let symbolResolver: CardSymbolAssetResolver

    init(
        tokenResolver: AbilityTokenAssetResolver = .shared,
        symbolResolver: CardSymbolAssetResolver = .shared
    ) {
        self.tokenResolver = tokenResolver
        self.symbolResolver = symbolResolver
    }

    func build(
        rawAbilityText: String,
        triggerTitle: String?,
        triggerStyle: CardTriggerStyle
    ) -> CardAbilityPresentation {
        let trimmed = rawAbilityText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }

        if triggerTitle == CardFaceTriggerCopy.ifActivated,
           let alsoIfRange = trimmed.range(of: "also, if") {
            let mainText = String(trimmed[..<alsoIfRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let alsoIfText = String(trimmed[alsoIfRange.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let mainBlock = CardAbilityBlock(
                kind: .main,
                layout: .squished,
                backgroundAsset: triggerStyle.stripAsset,
                backgroundAssetPrefix: triggerStyle.stripAssetPrefix,
                elements: [triggerElement(triggerTitle)] + parseElements(mainText)
            )
            let alsoIfBlock = CardAbilityBlock(
                kind: .alsoIf,
                layout: .alsoIf,
                backgroundAsset: triggerStyle.stripAsset,
                backgroundAssetPrefix: triggerStyle.stripAssetPrefix,
                elements: parseElements(alsoIfText)
            )
            return CardAbilityPresentation(
                triggerTitle: triggerTitle,
                blocks: [mainBlock, alsoIfBlock],
                blockGapCqw: CardAbilityPanelMetrics.live.blockGapCqw,
                isFlatFallback: false
            )
        }

        let elements = [triggerElement(triggerTitle)] + parseElements(trimmed)
        return CardAbilityPresentation(
            triggerTitle: triggerTitle,
            blocks: [
                CardAbilityBlock(
                    kind: .main,
                    layout: .standard,
                    backgroundAsset: triggerStyle.stripAsset,
                    backgroundAssetPrefix: triggerStyle.stripAssetPrefix,
                    elements: elements
                )
            ],
            blockGapCqw: CardAbilityPanelMetrics.live.blockGapCqw,
            isFlatFallback: false
        )
    }

    private func triggerElement(_ triggerTitle: String?) -> CardAbilityElement {
        .text(CardAbilityText(text: triggerTitle ?? "", isBold: true))
    }

    private func parseElements(_ text: String) -> [CardAbilityElement] {
        guard !text.isEmpty else {
            return []
        }

        var elements: [CardAbilityElement] = []
        var iconRun: [CardAbilityIcon] = []
        var textBuffer = ""
        var index = text.startIndex

        func flushText() {
            let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                elements.append(.text(CardAbilityText(text: trimmed)))
            }
            textBuffer = ""
        }

        func flushIcons() {
            appendIconRun(iconRun, to: &elements)
            iconRun = []
        }

        while index < text.endIndex {
            let character = text[index]
            guard character == "[" else {
                textBuffer.append(character)
                index = text.index(after: index)
                continue
            }

            guard let close = text[index...].firstIndex(of: "]") else {
                textBuffer.append(character)
                index = text.index(after: index)
                continue
            }

            flushText()
            let token = String(text[text.index(after: index)..<close])
            index = text.index(after: close)

            if let row = parsePlusRow(startingWith: token, in: text, index: &index) {
                flushIcons()
                elements.append(.horizontalRow(row))
            } else if let points = pointsElement(for: token, leadingText: textBuffer) {
                flushIcons()
                elements.append(.points(points))
                textBuffer = ""
            } else {
                iconRun.append(abilityIcon(for: token, placement: .normal))
            }

            let nextCharacter = index < text.endIndex ? text[index] : nil
            if nextCharacter != "[" {
                flushIcons()
            }
        }

        flushText()
        flushIcons()
        return elements
    }

    private func parsePlusRow(
        startingWith firstToken: String,
        in text: String,
        index: inout String.Index
    ) -> [CardAbilityElement]? {
        var probe = index
        skipWhitespace(in: text, index: &probe)
        guard probe < text.endIndex,
              text[probe] == "+"
        else {
            return nil
        }

        var tokens = [firstToken]
        while probe < text.endIndex {
            skipWhitespace(in: text, index: &probe)
            guard probe < text.endIndex,
                  text[probe] == "+"
            else {
                break
            }
            probe = text.index(after: probe)
            skipWhitespace(in: text, index: &probe)
            guard probe < text.endIndex,
                  text[probe] == "[",
                  let close = text[probe...].firstIndex(of: "]")
            else {
                break
            }
            tokens.append(String(text[text.index(after: probe)..<close]))
            probe = text.index(after: close)
        }

        guard tokens.count > 1 else {
            return nil
        }
        index = probe
        return tokens.map { token in
            .icon(abilityIcon(for: token, placement: .horizontalRow))
        }
    }

    private func skipWhitespace(in text: String, index: inout String.Index) {
        while index < text.endIndex,
              text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    private func pointsElement(for token: String, leadingText: String) -> CardAbilityPoints? {
        guard token == "Wave" else {
            return nil
        }
        return CardAbilityPoints(
            pointsText: leadingText.trimmingCharacters(in: .whitespacesAndNewlines),
            waveIcon: symbolResolver.icon(named: "Wave", fallbackText: "分", accessibilityText: "分数")
        )
    }

    private func appendIconRun(
        _ icons: [CardAbilityIcon],
        to elements: inout [CardAbilityElement]
    ) {
        guard !icons.isEmpty else {
            return
        }

        let allPlayers = icons.filter { $0.icon.assetName == "AllPlayers" }
        let nonAllPlayers = icons.filter { $0.icon.assetName != "AllPlayers" }

        if !nonAllPlayers.isEmpty {
            if nonAllPlayers.count == 1 {
                elements.append(.icon(nonAllPlayers[0]))
            } else {
                elements.append(.iconGroup(iconGroup(for: nonAllPlayers)))
            }
        }

        for icon in allPlayers {
            elements.append(
                .icon(
                    CardAbilityIcon(
                        icon: icon.icon,
                        placement: .allPlayersBottom,
                        style: .allPlayersShadow
                    )
                )
            )
        }
    }

    private func iconGroup(for icons: [CardAbilityIcon]) -> CardAbilityIconGroup {
        let assetNames = icons.map(\.icon.assetName)
        let hasArrow = assetNames.contains("ArrowDown")
        let allCoral = assetNames.allSatisfy(Self.isCoralIcon)
        let layout: CardAbilityIconGroupLayout
        let placement: CardAbilityIconPlacement

        if allCoral {
            layout = .coralHorizontal
            placement = .coralGroup
        } else if hasArrow {
            layout = .arrowFlow
            placement = .arrowFlow
        } else {
            layout = .vertical
            placement = .normal
        }

        let styledIcons = icons.map { icon in
            CardAbilityIcon(
                icon: icon.icon,
                placement: placement,
                style: icon.style
            )
        }
        return CardAbilityIconGroup(
            icons: styledIcons,
            layout: layout,
            cssClassSummary: cssClassSummary(for: assetNames)
        )
    }

    private func cssClassSummary(for assetNames: [String]) -> String {
        Dictionary(grouping: assetNames) { $0 }
            .map { "\($0.key)-\($0.value.count)" }
            .sorted()
            .joined(separator: " ")
    }

    private static func isCoralIcon(_ assetName: String) -> Bool {
        ["AnyCoral", "BlueCoral", "GreenCoral", "PurpleCoral"].contains(assetName)
    }

    private func abilityIcon(
        for token: String,
        placement: CardAbilityIconPlacement
    ) -> CardAbilityIcon {
        let icon = tokenResolver.icon(
            for: token,
            fallbackText: fallbackText(for: token),
            accessibilityText: accessibilityText(for: token)
        )
        let style: CardAbilityIconStyle = icon.assetName == "AllPlayers" ? .allPlayersShadow : .normal
        let resolvedPlacement: CardAbilityIconPlacement = icon.assetName == "AllPlayers" ? .allPlayersBottom : placement
        return CardAbilityIcon(
            icon: icon,
            placement: resolvedPlacement,
            style: style
        )
    }

    private func fallbackText(for token: String) -> String {
        switch token {
        case "AllPlayers":
            return "全员"
        case "ArrowDown":
            return "向下"
        case "FishEgg":
            return "卵"
        case "FishHatch":
            return "孵"
        case "YoungFish":
            return "幼"
        case "SchoolFish", "School":
            return "群"
        case "Predator":
            return "捕"
        case "BlueCoral":
            return "蓝珊瑚"
        case "PurpleCoral":
            return "紫珊瑚"
        case "GreenCoral":
            return "绿珊瑚"
        case "AnyCoral":
            return "任意珊瑚"
        default:
            return "?"
        }
    }

    private func accessibilityText(for token: String) -> String {
        switch token {
        case "AllPlayers":
            return "所有玩家"
        case "ArrowDown":
            return "向下"
        case "FishEgg":
            return "鱼卵"
        case "FishHatch":
            return "孵化"
        case "Predator":
            return "捕食者"
        default:
            return token
        }
    }
}

extension Array where Element == CardAbilityElement {
    var containsAllPlayersShadow: Bool {
        contains { element in
            switch element {
            case let .icon(icon):
                return icon.style == .allPlayersShadow
            case let .iconGroup(group):
                return group.icons.contains { $0.style == .allPlayersShadow }
            case let .horizontalRow(elements):
                return elements.containsAllPlayersShadow
            case .text, .points:
                return false
            }
        }
    }

    var tokenPlacementSummary: [String] {
        flatMap { element -> [String] in
            switch element {
            case let .icon(icon):
                return ["\(icon.icon.assetName):\(icon.placement.rawValue):\(icon.style.rawValue)"]
            case let .iconGroup(group):
                return group.icons.map { "\($0.icon.assetName):\(group.layout.rawValue):\($0.placement.rawValue):\($0.style.rawValue)" }
            case let .horizontalRow(elements):
                return elements.tokenPlacementSummary
            case .text, .points:
                return []
            }
        }
    }
}

import SwiftUI

enum GameTokenIconKind: Equatable, Hashable {
    case fish
    case smallFish
    case mediumFish
    case largeFish
    case egg
    case young
    case school
    case coral(DiveSite)
    case anyCoral
    case completeReefBonus
    case draw
    case discard
    case card
    case consume
    case predator
    case hatch
    case move
    case arrow
    case wave
    case sun
    case twilight
    case night
    case gameEnd
    case zone(DiveActionSite)
}

struct GameTokenIconAsset: Equatable {
    let kind: GameTokenIconKind
    let icon: FishCardFaceIconViewState
    let boardAssetName: String?

    var asset: CardAssetReference? {
        icon.asset
    }

    var isResolved: Bool {
        boardAssetName != nil || (icon.asset != nil && icon.missingAsset == nil)
    }
}

final class GameTokenIconResolver: @unchecked Sendable {
    static let shared = GameTokenIconResolver()

    private let symbolResolver: CardSymbolAssetResolver

    init(symbolResolver: CardSymbolAssetResolver = .shared) {
        self.symbolResolver = symbolResolver
    }

    func icon(for kind: GameTokenIconKind) -> GameTokenIconAsset {
        let metadata = iconMetadata(for: kind)
        return GameTokenIconAsset(
            kind: kind,
            icon: symbolResolver.icon(
                named: metadata.assetName,
                fallbackText: metadata.fallbackText,
                accessibilityText: metadata.accessibilityText
            ),
            boardAssetName: physicalPieceAssetName(for: kind)
        )
    }

    func lookup(for kind: GameTokenIconKind) -> CardAssetLookup {
        symbolResolver.lookup(named: iconMetadata(for: kind).assetName)
    }

    private func iconMetadata(
        for kind: GameTokenIconKind
    ) -> (assetName: String, fallbackText: String, accessibilityText: String) {
        switch kind {
        case .fish:
            return ("FishFromHand", "鱼", "鱼牌")
        case .smallFish:
            return ("FishLengthSmall", "小", "小型鱼")
        case .mediumFish:
            return ("FishLengthMedium", "中", "中型鱼")
        case .largeFish:
            return ("FishLengthLarge", "大", "大型鱼")
        case .egg:
            return ("FishEgg", "卵", "鱼卵")
        case .young:
            return ("YoungFish", "幼", "幼鱼")
        case .school:
            return ("SchoolFish", "群", "鱼群")
        case .coral(.blue):
            return ("BlueCoral", "蓝珊瑚", "蓝色珊瑚")
        case .coral(.purple):
            return ("PurpleCoral", "紫珊瑚", "紫色珊瑚")
        case .coral(.green):
            return ("GreenCoral", "绿珊瑚", "绿色珊瑚")
        case .anyCoral:
            return ("AnyCoral", "珊瑚", "任意珊瑚")
        case .completeReefBonus:
            return ("AnyCoral", "礁", "完成珊瑚礁奖励")
        case .draw:
            return ("DrawCard", "抽牌", "抽牌")
        case .discard:
            return ("Discard", "弃", "弃牌")
        case .card:
            return ("DrawCard", "卡", "卡牌")
        case .consume:
            return ("ConsumeFish1", "吞", "覆盖鱼")
        case .predator:
            return ("Predator", "捕", "捕食者标签")
        case .hatch:
            return ("FishHatch", "孵", "孵化")
        case .move:
            return ("SchoolFeederMove", "移", "移动资源")
        case .arrow:
            return ("ArrowDown", "箭头", "箭头")
        case .wave:
            return ("Wave", "分", "分数")
        case .sun:
            return ("Sun", "光", "透光带")
        case .twilight:
            return ("Dusk", "暮", "暮光带")
        case .night:
            return ("Night", "夜", "深海带")
        case .gameEnd:
            return ("Wave", "终", "游戏结束")
        case .zone(.blue):
            return ("FlipperBlue", "蓝", "蓝色潜水点")
        case .zone(.purple):
            return ("FlipperPurple", "紫", "紫色潜水点")
        case .zone(.green):
            return ("FlipperGreen", "绿", "绿色潜水点")
        case .zone:
            return ("AnyCoral", "潜水", "潜水点")
        }
    }

    private func physicalPieceAssetName(for kind: GameTokenIconKind) -> String? {
        switch kind {
        case .egg:
            return "board_token_egg_orange"
        case .young:
            return "board_token_young_yellow"
        default:
            return nil
        }
    }
}

struct GameTokenIconView: View {
    let icon: GameTokenIconAsset
    let size: CGFloat

    var body: some View {
        Group {
            if let boardAssetName = icon.boardAssetName,
               let image = BoardImageAssetResolver.image(named: boardAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else if let image = rasterImage(for: icon.asset) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(icon.icon.accessibilityText))
    }

    @ViewBuilder
    private var fallback: some View {
#if DEBUG
        ZStack {
            RoundedRectangle(cornerRadius: max(size * 0.12, 2))
                .fill(Color.red.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: max(size * 0.12, 2))
                        .stroke(Color.red, lineWidth: max(1, size * 0.08))
                )
            Text("?")
                .font(.system(size: max(size * 0.62, 7), weight: .black, design: .rounded))
                .foregroundStyle(.red)
        }
#else
        Color.clear
#endif
    }

    private func rasterImage(for asset: CardAssetReference?) -> UIImage? {
        guard let asset,
              asset.fileExtension.lowercased() != "svg"
        else {
            return nil
        }
        return UIImage(contentsOfFile: asset.url.path)
    }
}

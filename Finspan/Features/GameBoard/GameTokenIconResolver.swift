import SwiftUI

enum GameTokenIconKind: Equatable, Hashable {
    case fish
    case egg
    case young
    case school
    case coral(DiveSite)
    case anyCoral
    case draw
    case discard
    case consume
    case hatch
    case move
    case arrow
    case zone(DiveActionSite)
}

struct GameTokenIconAsset: Equatable {
    let kind: GameTokenIconKind
    let icon: FishCardFaceIconViewState

    var asset: CardAssetReference? {
        icon.asset
    }

    var isResolved: Bool {
        icon.asset != nil && icon.missingAsset == nil
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
            )
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
        case .draw:
            return ("DrawCard", "抽牌", "抽牌")
        case .discard:
            return ("Discard", "弃", "弃牌")
        case .consume:
            return ("ConsumeFish1", "吞", "覆盖鱼")
        case .hatch:
            return ("FishHatch", "孵", "孵化")
        case .move:
            return ("SchoolFeederMove", "移", "移动资源")
        case .arrow:
            return ("ArrowDown", "箭头", "箭头")
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
}

struct GameTokenIconView: View {
    let icon: GameTokenIconAsset
    let size: CGFloat

    var body: some View {
        Group {
            if let image = rasterImage(for: icon.asset) {
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

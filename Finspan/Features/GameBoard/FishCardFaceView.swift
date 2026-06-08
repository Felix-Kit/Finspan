import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FishCardFaceView: View {
    let viewState: FishCardFaceViewState

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let unit = width / 100

            ZStack {
                cardBackground
                starterLikePlaceholderLayer(unit: unit)

                if viewState.kind == .fishCard || viewState.kind == .forageFish {
                    fishImage(unit: unit)
                } else {
                    placeholder(unit: unit)
                }

                nameArea(unit: unit)
                costArea(unit: unit)
                zoneArea(unit: unit)
                pointsArea(unit: unit)
                lengthArea(unit: unit)
                tagArea(unit: unit)
                abilityArea(unit: unit)
            }
            .clipShape(RoundedRectangle(cornerRadius: width * CardRenderMetrics.cornerRadiusRatio))
            .overlay(
                RoundedRectangle(cornerRadius: width * CardRenderMetrics.cornerRadiusRatio)
                    .stroke(borderColor, lineWidth: max(1, unit * 0.35))
            )
        }
        .aspectRatio(viewState.aspectRatio, contentMode: .fit)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if let image = localImage(prefix: viewState.backgroundAssetPrefix, extensions: ["webp", "png"], directories: backgroundDirectories) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(fallbackBackgroundColor)
        }
    }

    @ViewBuilder
    private func starterLikePlaceholderLayer(unit: CGFloat) -> some View {
        if viewState.kind == .empty {
            RoundedRectangle(cornerRadius: unit * 4)
                .fill(Color(.secondarySystemBackground).opacity(0.72))
                .padding(unit * 2.2)
        }
    }

    private func nameArea(unit: CGFloat) -> some View {
        VStack(spacing: unit * 0.25) {
            Text(viewState.displayName)
                .font(.system(size: unit * CardRenderMetrics.CardFaceLayout.titleFontSize, weight: .heavy))
                .multilineTextAlignment(.center)
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: unit * 48)

            Text(viewState.scientificName ?? AppStrings.GameBoard.cardFaceNoScientificName)
                .font(.system(size: unit * CardRenderMetrics.CardFaceLayout.latinFontSize, weight: .regular, design: .serif))
                .italic()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.primary.opacity(0.82))
                .frame(maxWidth: unit * 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, unit * CardRenderMetrics.CardFaceLayout.nameTop)
    }

    private func costArea(unit: CGFloat) -> some View {
        iconCapsule(
            icons: viewState.costIcons,
            unit: unit,
            axis: .horizontal,
            iconSize: unit * CardRenderMetrics.CardFaceLayout.costIconHeight,
            maxIcons: 5
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, unit * CardRenderMetrics.CardFaceLayout.costTop)
    }

    private func zoneArea(unit: CGFloat) -> some View {
        VStack(spacing: unit) {
            if zoneDistributionNeedsTopSpacer {
                Spacer(minLength: 0)
            }
            ForEach(Array(viewState.zoneIcons.prefix(4).enumerated()), id: \.offset) { _, icon in
                iconImage(icon, size: unit * CardRenderMetrics.CardFaceLayout.zoneIconHeight)
            }
            if zoneDistributionNeedsBottomSpacer {
                Spacer(minLength: 0)
            }
        }
        .frame(minWidth: unit * 6.5)
        .frame(height: unit * CardRenderMetrics.CardFaceLayout.zonesHeight)
        .padding(.leading, unit * 3)
        .padding(.trailing, unit * 1.5)
        .padding(.vertical, unit)
        .background(sidebarBackground(unit: unit))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, unit * CardRenderMetrics.CardFaceLayout.zonesTop)
    }

    private func pointsArea(unit: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(printedPointsNumber)
                .font(.system(size: unit * CardRenderMetrics.CardFaceLayout.pointsFontSize, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            iconImage(
                FishCardFaceIconViewState(assetName: "Wave", fallbackText: "分", accessibilityText: "分数"),
                size: unit * 7
            )
            .offset(x: -unit * 2.5, y: unit * 2)
        }
        .frame(height: unit * 7, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, unit * CardRenderMetrics.CardFaceLayout.pointsLeft)
        .padding(.top, unit * CardRenderMetrics.CardFaceLayout.pointsTop)
    }

    private func lengthArea(unit: CGFloat) -> some View {
        VStack(spacing: unit * 0.6) {
            Text(lengthDisplayText)
                .font(.system(size: unit * CardRenderMetrics.CardFaceLayout.lengthFontSize, weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .multilineTextAlignment(.center)
                .lineSpacing(-unit * 1.25)
            iconImage(viewState.sizeClassIcon, size: unit * CardRenderMetrics.CardFaceLayout.lengthIconHeight)
                .opacity(0.5)
        }
        .frame(width: unit * CardRenderMetrics.CardFaceLayout.lengthWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, unit * CardRenderMetrics.CardFaceLayout.lengthLeft)
        .padding(.top, unit * CardRenderMetrics.CardFaceLayout.lengthTop)
    }

    private func tagArea(unit: CGFloat) -> some View {
        HStack(spacing: unit * 0.8) {
            ForEach(Array(viewState.tagIcons.prefix(5).enumerated()), id: \.offset) { _, icon in
                iconImage(icon, size: unit * 4.4)
            }
        }
        .frame(maxWidth: unit * 28, alignment: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, unit * 4.2)
        .padding(.trailing, unit * 17)
    }

    private func abilityArea(unit: CGFloat) -> some View {
        VStack(spacing: unit * 1.1) {
            if let trigger = viewState.abilityTriggerText {
                Text(trigger)
                    .font(.system(size: unit * CardRenderMetrics.CardFaceLayout.abilityFontSize, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            abilitySegments(unit: unit)
        }
        .padding(.horizontal, abilityHorizontalPadding(unit: unit))
        .padding(.top, unit * 3)
        .padding(.bottom, unit * 5)
        .frame(width: unit * CardRenderMetrics.CardFaceLayout.abilityWidth)
        .frame(minHeight: unit * CardRenderMetrics.CardFaceLayout.abilityMinHeight)
        .background(abilityBackground(unit: unit))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, unit * abilityTopOffset)
        .padding(.trailing, abilityTrailingPadding(unit: unit))
    }

    @ViewBuilder
    private func abilitySegments(unit: CGFloat) -> some View {
        let segments = viewState.abilitySegments.isEmpty
            ? FishCardAbilityTokenParser.parse(viewState.abilityText)
            : viewState.abilitySegments
        let rows = abilityRows(for: Array(segments.prefix(12)))

        VStack(spacing: unit * 0.9) {
            ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { _, row in
                if row.allSatisfy(\.isIcon) {
                    VStack(spacing: unit * 0.4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, segment in
                            if case let .icon(icon) = segment {
                                iconImage(icon, size: abilityIconSize(icon, unit: unit))
                                    .offset(y: abilityIconVerticalOffset(icon, unit: unit))
                            }
                        }
                    }
                } else if case let .text(text) = row.first {
                    Text(text)
                        .font(.system(size: unit * abilityTextFontSize, weight: .semibold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.42)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(viewState.kind == .placeholder ? .secondary : .primary)
                }
            }
        }
    }

    private func abilityRows(for segments: [FishCardAbilitySegment]) -> [[FishCardAbilitySegment]] {
        var rows: [[FishCardAbilitySegment]] = []
        var iconRun: [FishCardAbilitySegment] = []

        for segment in segments {
            switch segment {
            case .icon:
                iconRun.append(segment)
            case .text:
                if !iconRun.isEmpty {
                    rows.append(iconRun)
                    iconRun = []
                }
                rows.append([segment])
            }
        }

        if !iconRun.isEmpty {
            rows.append(iconRun)
        }
        return rows
    }

    private var zoneDistributionNeedsTopSpacer: Bool {
        guard viewState.zoneIcons.count == 1 else {
            return false
        }
        let assetName = viewState.zoneIcons[0].assetName
        return assetName == "Night" || assetName == "Dusk"
    }

    private var zoneDistributionNeedsBottomSpacer: Bool {
        guard viewState.zoneIcons.count == 1 else {
            return false
        }
        let assetName = viewState.zoneIcons[0].assetName
        return assetName == "Sun" || assetName == "Dusk"
    }

    private var printedPointsNumber: String {
        let digits = viewState.printedPointsText.filter(\.isNumber)
        return digits.isEmpty ? "0" : String(digits)
    }

    private var lengthDisplayText: String {
        let digits = viewState.lengthText.filter(\.isNumber)
        return digits.isEmpty ? "-\ncm" : "\(digits)\ncm"
    }

    private var abilityTopOffset: CGFloat {
        switch viewState.abilityPanelStyle {
        case .yellowBrush:
            return 9
        case .tanBrush:
            return 17
        case .none:
            return 17
        }
    }

    private var abilityTextFontSize: CGFloat {
        switch viewState.abilityPanelStyle {
        case .none:
            return 3.45
        case .tanBrush, .yellowBrush:
            return CardRenderMetrics.CardFaceLayout.abilityFontSize
        }
    }

    private func abilityHorizontalPadding(unit: CGFloat) -> CGFloat {
        switch viewState.abilityPanelStyle {
        case .none:
            return unit * 1.5
        case .tanBrush, .yellowBrush:
            return unit * 3.0
        }
    }

    private func abilityTrailingPadding(unit: CGFloat) -> CGFloat {
        switch viewState.abilityPanelStyle {
        case .none:
            return unit * 6
        case .tanBrush, .yellowBrush:
            return 0
        }
    }

    private func abilityIconSize(_ icon: FishCardFaceIconViewState, unit: CGFloat) -> CGFloat {
        switch icon.assetName {
        case "ArrowDown":
            return unit * CardRenderMetrics.CardFaceLayout.abilityArrowHeight
        case "SchoolFeederMove", "FishLengthSmall", "FishLengthMedium", "FishLengthLarge", "ConsumeFish", "ConsumeFish1", "ConsumeFish2", "ConsumeFish3":
            return unit * 12
        case "YoungFish":
            return unit * 6.5
        case "FishFromHand":
            return unit * 7.2
        case "AllPlayers":
            return unit * 10
        default:
            return unit * CardRenderMetrics.CardFaceLayout.abilityIconHeight
        }
    }

    private func abilityIconVerticalOffset(_ icon: FishCardFaceIconViewState, unit: CGFloat) -> CGFloat {
        switch icon.assetName {
        case "ArrowDown":
            return -unit * 2.5
        default:
            return 0
        }
    }

    @ViewBuilder
    private func abilityBackground(unit: CGFloat) -> some View {
        if let prefix = viewState.abilityStripAssetPrefix,
           let image = localImage(prefix: prefix, extensions: ["png", "webp"], directories: backgroundDirectories) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: unit * 1.3))
        } else if viewState.abilityPanelStyle == .tanBrush {
            RoundedRectangle(cornerRadius: unit * 1.2)
                .fill(Color(red: 0.72, green: 0.46, blue: 0.24).opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 1.2)
                        .stroke(Color(red: 0.78, green: 0.58, blue: 0.36).opacity(0.3), lineWidth: max(1, unit * 0.3))
                )
        } else if viewState.abilityPanelStyle == .yellowBrush {
            RoundedRectangle(cornerRadius: unit * 1.2)
                .fill(Color(red: 0.96, green: 0.77, blue: 0.22).opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 1.2)
                        .stroke(Color(red: 0.88, green: 0.65, blue: 0.14).opacity(0.34), lineWidth: max(1, unit * 0.3))
                )
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func fishImage(unit: CGFloat) -> some View {
        if let image = localFishImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text(viewState.displayName))
                .frame(
                    maxWidth: unit * CardRenderMetrics.CardFaceLayout.silhouetteMaxWidth,
                    maxHeight: unit * CardRenderMetrics.CardFaceLayout.silhouetteMaxHeight
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, unit * CardRenderMetrics.CardFaceLayout.silhouetteLeft)
                .padding(.top, unit * CardRenderMetrics.CardFaceLayout.silhouetteTop)
        } else {
            placeholder(unit: unit)
                .frame(
                    width: unit * CardRenderMetrics.CardFaceLayout.silhouetteMaxWidth,
                    height: unit * CardRenderMetrics.CardFaceLayout.silhouetteMaxHeight
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, unit * CardRenderMetrics.CardFaceLayout.silhouetteLeft)
                .padding(.top, unit * CardRenderMetrics.CardFaceLayout.silhouetteTop)
        }
    }

    private func placeholder(unit: CGFloat) -> some View {
        VStack(spacing: unit * 0.8) {
            Image(systemName: placeholderSymbol)
                .font(.system(size: unit * 8, weight: .semibold))
            Text(placeholderText)
                .font(.system(size: unit * 3.2, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .padding(unit * 2)
        .background(
            RoundedRectangle(cornerRadius: unit * 2)
                .fill(Color.white.opacity(0.46))
        )
    }

    private func iconCapsule(
        icons: [FishCardFaceIconViewState],
        unit: CGFloat,
        axis: Axis,
        iconSize: CGFloat,
        maxIcons: Int
    ) -> some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: unit * 0.85) {
                    iconList(icons: icons, iconSize: iconSize, maxIcons: maxIcons)
                }
            } else {
                VStack(spacing: unit * 0.85) {
                    iconList(icons: icons, iconSize: iconSize, maxIcons: maxIcons)
                }
            }
        }
        .padding(.leading, unit * 2.8)
        .padding(.trailing, unit * 1.3)
        .padding(.vertical, unit * 1)
        .background(
            sidebarBackground(unit: unit)
        )
    }

    private func sidebarBackground(unit: CGFloat) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: unit * 5,
            topTrailingRadius: unit * 5
        )
        .fill(Color.white.opacity(0.70))
    }

    @ViewBuilder
    private func iconList(
        icons: [FishCardFaceIconViewState],
        iconSize: CGFloat,
        maxIcons: Int
    ) -> some View {
        let visibleIcons = icons.prefix(maxIcons)
        ForEach(Array(visibleIcons.enumerated()), id: \.offset) { _, icon in
            iconImage(icon, size: iconSize)
        }
    }

    @ViewBuilder
    private func iconImage(_ icon: FishCardFaceIconViewState, size: CGFloat) -> some View {
        if let url = localAssetURL(prefix: icon.assetName, extensions: ["svg", "png", "webp"], directories: iconDirectories),
           url.pathExtension.lowercased() == "svg" {
            Image(url.lastPathComponent, bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(Text(icon.accessibilityText))
        } else if let image = localImage(prefix: icon.assetName, extensions: ["png", "webp"], directories: iconDirectories) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(Text(icon.accessibilityText))
        } else {
            Text(icon.fallbackText)
                .font(.system(size: max(size * 0.52, 7), weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(0.72)))
                .accessibilityLabel(Text(icon.accessibilityText))
        }
    }

    private var localFishImage: UIImage? {
        guard viewState.kind == .fishCard,
              let prefix = viewState.localFishImagePrefix
        else {
            return nil
        }
        return localImage(prefix: prefix, extensions: ["webp", "png"], directories: fishDirectories)
    }

    private func localImage(
        prefix: String,
        extensions: [String],
        directories: [String]
    ) -> UIImage? {
        guard let url = localAssetURL(prefix: prefix, extensions: extensions, directories: directories) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func localAssetURL(
        prefix: String,
        extensions: [String],
        directories: [String]
    ) -> URL? {
        for directory in directories {
            for fileExtension in extensions {
                if let exact = Bundle.main.url(
                    forResource: prefix,
                    withExtension: fileExtension,
                    subdirectory: directory
                ) {
                    return exact
                }
                if let prefixed = Bundle.main.urls(
                    forResourcesWithExtension: fileExtension,
                    subdirectory: directory
                )?.first(where: { $0.lastPathComponent.hasPrefix("\(prefix).") }) {
                    return prefixed
                }
            }
        }
        return nil
    }

    private var placeholderSymbol: String {
        switch viewState.kind {
        case .empty:
            return "square.dashed"
        case .forageFish:
            return "fish"
        case .fishCard:
            return "photo"
        case .placeholder:
            return "questionmark.square"
        }
    }

    private var placeholderText: String {
        switch viewState.kind {
        case .empty:
            return AppStrings.GameBoard.empty
        case .forageFish:
            return AppStrings.GameBoard.forageFish
        case .fishCard:
            return AppStrings.GameBoard.cardFaceLocalAssetMissing
        case .placeholder:
            return AppStrings.GameBoard.cardFaceUnknownCard
        }
    }

    private var fallbackBackgroundColor: Color {
        switch viewState.kind {
        case .empty:
            return Color(.secondarySystemBackground).opacity(0.62)
        case .forageFish:
            return Color.cyan.opacity(0.12)
        case .fishCard:
            return Color(red: 0.96, green: 0.93, blue: 0.82)
        case .placeholder:
            return Color(.tertiarySystemBackground)
        }
    }

    private var borderColor: Color {
        switch viewState.kind {
        case .empty:
            return .secondary.opacity(0.28)
        case .forageFish:
            return .cyan.opacity(0.42)
        case .fishCard:
            return .black.opacity(0.68)
        case .placeholder:
            return .secondary.opacity(0.36)
        }
    }

    private var backgroundDirectories: [String] {
        [
            "Resources/CardAssets/backgrounds",
            "CardAssets/backgrounds",
            "backgrounds"
        ]
    }

    private var fishDirectories: [String] {
        [
            "Resources/CardAssets/fish",
            "CardAssets/fish",
            "fish"
        ]
    }

    private var iconDirectories: [String] {
        [
            "Resources/CardAssets/icons",
            "CardAssets/icons",
            "icons"
        ]
    }
}

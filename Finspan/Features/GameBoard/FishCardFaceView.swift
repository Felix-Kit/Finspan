import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FishCardFaceView: View {
    let viewState: FishCardFaceViewState
#if DEBUG
    @State private var showsIconRenderStatus = false
#endif

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
                resourceTokenArea(unit: unit)
                tagArea(unit: unit)
                flavorArea(unit: unit)
                abilityArea(unit: unit)
                expansionBadgeLayer(unit: unit)
                starterCornerDecorationsLayer(unit: unit)
#if DEBUG
                debugIconRenderStatusLayer(unit: unit)
#endif
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
        if let image = rasterImage(for: viewState.backgroundAsset) {
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
                .font(CardFontStyleResolver.shared.font(.title, size: unit * CardRenderMetrics.CardFaceLayout.titleFontSize))
                .fontWeight(.heavy)
                .multilineTextAlignment(.center)
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: unit * 48)

            Text(viewState.scientificName ?? AppStrings.GameBoard.cardFaceNoScientificName)
                .font(CardFontStyleResolver.shared.font(.latin, size: unit * CardRenderMetrics.CardFaceLayout.latinFontSize))
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
                .font(CardFontStyleResolver.shared.font(.title, size: unit * CardRenderMetrics.CardFaceLayout.pointsFontSize))
                .fontWeight(.heavy)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            iconImage(
                viewState.pointsIcon,
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
                .font(CardFontStyleResolver.shared.font(.title, size: unit * CardRenderMetrics.CardFaceLayout.lengthFontSize))
                .fontWeight(.heavy)
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

    @ViewBuilder
    private func resourceTokenArea(unit: CGFloat) -> some View {
        if !viewState.resourceTokens.isEmpty {
            ZStack {
                ForEach(Array(viewState.resourceTokens.prefix(5).enumerated()), id: \.element.id) { offset, token in
                    GameTokenIconView(icon: token.icon, size: unit * 7.5)
                        .scaleEffect(token.isSelectedForPayment ? 1.12 : 1)
                        .shadow(
                            color: token.isSelectedForPayment ? Color.red.opacity(0.85) : Color.black.opacity(0.16),
                            radius: token.isSelectedForPayment ? unit * 1.2 : unit * 0.35
                        )
                        .offset(
                            x: unit * CGFloat(offset % 2) * 4.8,
                            y: unit * CGFloat(offset / 2) * 5.2
                        )
                }
            }
            .frame(width: unit * 14, height: unit * 18, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, unit * 4.5)
            .padding(.top, unit * 65)
            .accessibilityHidden(true)
        }
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

    @ViewBuilder
    private func flavorArea(unit: CGFloat) -> some View {
        if let flavorText = viewState.flavorText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !flavorText.isEmpty {
            Text(flavorText)
                .font(CardFontStyleResolver.shared.font(.body, size: unit * CardRenderMetrics.CardFaceLayout.descriptionFontSize))
                .italic()
                .lineLimit(3)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary.opacity(0.82))
                .frame(
                    width: unit * CardRenderMetrics.CardFaceLayout.descriptionWidth,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, unit * CardRenderMetrics.CardFaceLayout.descriptionLeft)
                .padding(.top, unit * CardRenderMetrics.CardFaceLayout.descriptionTop)
        }
    }

    private func abilityArea(unit: CGFloat) -> some View {
        let panelMetrics = CardAbilityPanelMetrics.live

        return VStack(spacing: unit * panelMetrics.blockGapCqw) {
            ForEach(Array(viewState.abilityPresentation.blocks.enumerated()), id: \.offset) { _, block in
                abilityBlock(block, unit: unit)
            }
        }
        .frame(
            width: unit * panelMetrics.widthCqw,
            height: unit * panelMetrics.heightCqw,
            alignment: .center
        )
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, unit * panelMetrics.topPaddingCqw)
        .padding(.trailing, unit * panelMetrics.trailingPaddingCqw)
    }

    @ViewBuilder
    private func abilityBlock(_ block: CardAbilityBlock, unit: CGFloat) -> some View {
        let contentElements = block.elements.filter { !$0.isAllPlayersBottomIcon }
        let bottomIcons = block.elements.allPlayersBottomIcons
        let blockMetrics = CardAbilityBlockMetrics.live(
            for: block.layout,
            panelStyle: viewState.abilityPanelStyle
        )

        ZStack(alignment: .center) {
            VStack(spacing: unit * blockMetrics.contentGapCqw) {
                ForEach(Array(contentElements.prefix(12).enumerated()), id: \.offset) { _, element in
                    abilityElement(element, blockLayout: block.layout, unit: unit)
                }
            }
            .padding(.horizontal, unit * blockMetrics.horizontalPaddingCqw)
            .padding(.top, unit * blockMetrics.topPaddingCqw)
            .padding(.bottom, unit * blockMetrics.bottomPaddingCqw)

            ForEach(Array(bottomIcons.enumerated()), id: \.offset) { _, icon in
                abilityIcon(icon, unit: unit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, unit * CardAbilityArrowFlowMetrics.live.allPlayersBottomCqw)
            }
        }
        .frame(width: unit * CardAbilityPanelMetrics.live.widthCqw)
        .frame(minHeight: unit * blockMetrics.minTotalHeightCqw)
        .background {
            abilityBlockBackground(block, unit: unit)
        }
        .clipped()
    }

    private func abilityElement(
        _ element: CardAbilityElement,
        blockLayout: CardAbilityBlockLayout,
        unit: CGFloat
    ) -> AnyView {
        switch element {
        case let .text(text):
            if !text.text.isEmpty {
                return AnyView(Text(text.text)
                    .font(CardFontStyleResolver.shared.font(.title, size: unit * abilityTextFontSize(for: blockLayout)))
                    .fontWeight(text.isBold ? .heavy : .semibold)
                    .lineLimit(blockLayout == .alsoIf ? 4 : 3)
                    .minimumScaleFactor(0.42)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(viewState.kind == .placeholder ? .secondary : .primary)
                    .frame(maxWidth: unit * 25))
            }
            return AnyView(EmptyView())
        case let .icon(icon):
            return AnyView(abilityIcon(icon, unit: unit))
        case let .iconGroup(group):
            return AnyView(abilityIconGroup(group, unit: unit))
        case let .points(points):
            return AnyView(HStack(alignment: .top, spacing: -unit * 1.8) {
                if !points.pointsText.isEmpty {
                    Text(points.pointsText)
                        .font(CardFontStyleResolver.shared.font(.title, size: unit * 7.2))
                        .fontWeight(.heavy)
                }
                iconImage(points.waveIcon, size: unit * 7)
                    .offset(y: unit * 1.2)
            })
        case let .horizontalRow(elements):
            return AnyView(HStack(spacing: unit * 0.7) {
                ForEach(Array(elements.enumerated()), id: \.offset) { _, child in
                    abilityElement(child, blockLayout: blockLayout, unit: unit)
                }
            }
            .frame(maxWidth: unit * 26, alignment: .center))
        }
    }

    @ViewBuilder
    private func abilityIconGroup(_ group: CardAbilityIconGroup, unit: CGFloat) -> some View {
        switch group.layout {
        case .arrowFlow:
            VStack(spacing: unit * CardAbilityArrowFlowMetrics.live.effectiveStackSpacingCqw) {
                ForEach(Array(group.icons.enumerated()), id: \.offset) { _, icon in
                    abilityIcon(icon, unit: unit)
                }
            }
            .frame(maxWidth: unit * 18, alignment: .center)
        case .coralHorizontal, .horizontal:
            HStack(spacing: unit * 0.45) {
                ForEach(Array(group.icons.enumerated()), id: \.offset) { _, icon in
                    abilityIcon(icon, unit: unit)
                }
            }
            .frame(maxWidth: unit * 24, alignment: .center)
        case .vertical:
            VStack(spacing: unit * 0.9) {
                ForEach(Array(group.icons.enumerated()), id: \.offset) { _, icon in
                    abilityIcon(icon, unit: unit)
                }
            }
            .frame(maxWidth: unit * 18, alignment: .center)
        }
    }

    private func abilityIcon(_ icon: CardAbilityIcon, unit: CGFloat) -> some View {
        CardFaceIconAssetView(
            icon: icon.icon,
            size: abilityIconSize(icon.icon, unit: unit),
            style: icon.style
        )
        .offset(y: abilityIconVerticalOffset(icon.icon, unit: unit))
    }

    @ViewBuilder
    private func abilityBlockBackground(_ block: CardAbilityBlock, unit: CGFloat) -> some View {
        if let image = rasterImage(for: block.backgroundAsset) {
            CardAbilityBrushBackgroundView(image: image, unit: unit)
        } else if block.backgroundAssetPrefix == nil {
            Color.clear
        } else {
#if DEBUG
            RoundedRectangle(cornerRadius: unit * 1.2)
                .stroke(Color.red.opacity(0.7), lineWidth: max(1, unit * 0.24))
#else
            Color.clear
#endif
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

    private func abilityTextFontSize(for layout: CardAbilityBlockLayout) -> CGFloat {
        CGFloat(CardAbilityBlockMetrics.live(
            for: layout,
            panelStyle: viewState.abilityPanelStyle
        ).textFontSizeCqw)
    }

    @ViewBuilder
    private func expansionBadgeLayer(unit: CGFloat) -> some View {
        if let icon = viewState.expansionBadgeIcon {
            iconImage(icon, size: unit * 3.0)
                .opacity(0.9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, unit * 2)
                .padding(.trailing, unit * 1.5)
        }
    }

    @ViewBuilder
    private func starterCornerDecorationsLayer(unit: CGFloat) -> some View {
        if viewState.hasStarterCornerDecorations {
            let size = unit * 7.5
            ZStack {
                CardCornerTriangle(corner: .topLeft)
                    .fill(Color(red: 0.44, green: 0.44, blue: 0.46))
                    .frame(width: size, height: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                CardCornerTriangle(corner: .bottomRight)
                    .fill(Color(red: 0.44, green: 0.44, blue: 0.46))
                    .frame(width: size, height: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private func abilityIconSize(_ icon: FishCardFaceIconViewState, unit: CGFloat) -> CGFloat {
        switch icon.assetName {
        case "ArrowDown":
            return unit * CardAbilityArrowFlowMetrics.live.arrowHeightCqw
        case "SchoolFeederMove", "FishLengthSmall", "FishLengthMedium", "FishLengthLarge", "ConsumeFish", "ConsumeFish1", "ConsumeFish2", "ConsumeFish3":
            return unit * 12
        case "YoungFish":
            return unit * 6.5
        case "FishFromHand":
            return unit * 7.2
        case "AllPlayers":
            return unit * CardAbilityArrowFlowMetrics.live.allPlayersHeightCqw
        default:
            return unit * CardAbilityArrowFlowMetrics.live.defaultIconHeightCqw
        }
    }

    private func abilityIconVerticalOffset(_ icon: FishCardFaceIconViewState, unit: CGFloat) -> CGFloat {
        switch icon.assetName {
        case "ArrowDown":
            return unit * CardAbilityArrowFlowMetrics.live.arrowVerticalOffsetCqw
        default:
            return 0
        }
    }

    @ViewBuilder
    private func fishImage(unit: CGFloat) -> some View {
        if let image = rasterImage(for: viewState.localFishImageAsset) {
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
        CardFaceIconAssetView(icon: icon, size: size)
    }

    private func rasterImage(for asset: CardAssetReference?) -> UIImage? {
        guard let asset,
              asset.fileExtension.lowercased() != "svg"
        else {
            return nil
        }
        return UIImage(contentsOfFile: asset.url.path)
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

#if DEBUG
    private func debugIconRenderStatusLayer(unit: CGFloat) -> some View {
        let summary = CardIconRenderabilityAnalyzer.debugSummary(for: viewState)

        return VStack(alignment: .trailing, spacing: unit * 0.7) {
            Button {
                showsIconRenderStatus.toggle()
            } label: {
                Text(summary.failedIconCount > 0 || summary.missingAssetCount > 0 ? "!" : "i")
                    .font(.system(size: max(unit * 3.2, 8), weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: unit * 5, height: unit * 5)
                    .background(
                        Circle().fill(
                            summary.failedIconCount > 0 || summary.missingAssetCount > 0
                                ? Color.red.opacity(0.88)
                                : Color.black.opacity(0.58)
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Card icon render status"))

            if showsIconRenderStatus {
                debugIconRenderStatusPanel(summary: summary, unit: unit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, unit * 1.5)
        .padding(.trailing, unit * 1.5)
    }

    private func debugIconRenderStatusPanel(
        summary: FishCardIconRenderDebugSummary,
        unit: CGFloat
    ) -> some View {
        let failedNames = summary.failedIconNames.isEmpty
            ? "none"
            : summary.failedIconNames.prefix(5).joined(separator: ", ")
        let typeText = summary.renderAssetTypes.isEmpty ? "none" : summary.renderAssetTypes.joined(separator: "/")

        return VStack(alignment: .leading, spacing: unit * 0.35) {
            Text(summary.cardId)
                .font(.system(size: max(unit * 1.8, 7), weight: .bold, design: .monospaced))
            Text("source \(summary.sourceId)  \(typeText)")
            Text("icons \(summary.iconCount)  failed \(summary.failedIconCount)")
            Text("missing \(summary.missingAssetCount)  fish \(summary.fishImageFound ? "yes" : "no")")
            Text("flavor \(summary.flavorTextFound ? "yes" : "no")")
            Text("blocks \(summary.abilityBlockCount)  alsoIf \(summary.alsoIfBlockCount)")
            Text("brush \(summary.triggerBrushMode)  allPlayersShadow \(summary.hasAllPlayersShadow ? "yes" : "no")")
            Text("brushAsset \(summary.abilityBlockBackgrounds.prefix(2).joined(separator: "/"))")
                .lineLimit(1)
            Text("brush \(summary.brushOrientation)  mode \(summary.brushContentMode)")
            Text("bg \(summary.brushBackgroundPosition)  repeat \(summary.brushBackgroundRepeat)")
                .lineLimit(1)
            Text("panel \(summary.abilityPanelFrame)")
                .lineLimit(1)
            if let liveFrame = summary.liveMeasuredAbilityFrame {
                Text("live \(liveFrame)")
                    .lineLimit(1)
            }
            if let delta = summary.swiftAbilityFrameDelta {
                Text("delta \(delta)")
                    .lineLimit(1)
            }
            if let before = summary.swiftBeforeAbilityFrame {
                Text("before \(before)")
                    .lineLimit(1)
            }
            Text("arrow \(summary.arrowFlowMetrics)")
                .lineLimit(2)
            Text("gap \(summary.alsoIfGapCqw)cqw")
            Text("badge \(summary.hasExpansionLogo ? "yes" : "no")  starter \(summary.hasStarterCorner ? "yes" : "no")")
            Text("blockTypes \(summary.abilityBlockTypes.prefix(3).joined(separator: ","))")
                .lineLimit(2)
            Text("failed \(failedNames)")
                .lineLimit(3)
        }
        .font(.system(size: max(unit * 1.45, 6.5), weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(unit * 1.1)
        .frame(width: unit * 27, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: unit * 1.1)
                .fill(Color.black.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: unit * 1.1)
                .stroke(summary.failedIconCount > 0 ? Color.red : Color.green, lineWidth: max(1, unit * 0.18))
        )
    }
#endif

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

}

private struct CardAbilityBrushBackgroundView: View {
    let image: UIImage
    let unit: CGFloat

    private let metrics = CardAbilityBrushMetrics.live

    var body: some View {
        GeometryReader { proxy in
            let frameSize = proxy.size
            let imageSize = image.size
            let imageAspectRatio = max(imageSize.width, 1) / max(imageSize.height, 1)
            let frameAspectRatio = max(frameSize.width, 1) / max(frameSize.height, 1)
            let scaledWidth = frameAspectRatio > imageAspectRatio
                ? frameSize.width
                : frameSize.height * imageAspectRatio
            let scaledHeight = frameAspectRatio > imageAspectRatio
                ? frameSize.width / imageAspectRatio
                : frameSize.height

            Image(uiImage: image)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .frame(width: scaledWidth, height: scaledHeight, alignment: .topLeading)
                .frame(width: frameSize.width, height: frameSize.height, alignment: .topLeading)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: unit * metrics.cornerRadiusCqw))
    }
}

private struct CardFaceIconAssetView: View {
    let icon: FishCardFaceIconViewState
    let size: CGFloat
    var style: CardAbilityIconStyle = .normal

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
        .shadow(
            color: style == .allPlayersShadow ? Color(red: 0.25, green: 0.25, blue: 0.25).opacity(0.78) : .clear,
            radius: style == .allPlayersShadow ? max(size * 0.12, 1) : 0,
            x: 0,
            y: 0
        )
        .accessibilityLabel(Text(icon.accessibilityText))
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

private enum CardCornerPosition {
    case topLeft
    case bottomRight
}

private struct CardCornerTriangle: Shape {
    let corner: CardCornerPosition

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}

private extension CardAbilityElement {
    var isAllPlayersBottomIcon: Bool {
        if case let .icon(icon) = self {
            return icon.placement == .allPlayersBottom
        }
        return false
    }
}

private extension Array where Element == CardAbilityElement {
    var allPlayersBottomIcons: [CardAbilityIcon] {
        compactMap { element in
            if case let .icon(icon) = element,
               icon.placement == .allPlayersBottom {
                return icon
            }
            return nil
        }
    }
}

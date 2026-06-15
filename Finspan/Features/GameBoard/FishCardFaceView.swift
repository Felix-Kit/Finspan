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
                tagArea(unit: unit)
                flavorArea(unit: unit)
                abilityArea(unit: unit)
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
        VStack(spacing: unit * 1.1) {
            if let trigger = viewState.abilityTriggerText {
                Text(trigger)
                    .font(CardFontStyleResolver.shared.font(.title, size: unit * CardRenderMetrics.CardFaceLayout.abilityFontSize))
                    .fontWeight(.heavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            abilitySegments(unit: unit)
        }
        .padding(.horizontal, abilityHorizontalPadding(unit: unit))
        .padding(.top, unit * 3)
        .padding(.bottom, unit * 5)
        .frame(width: unit * CardRenderMetrics.CardFaceLayout.abilityPanelWidth)
        .frame(minHeight: unit * CardRenderMetrics.CardFaceLayout.abilityMinHeight)
        .background {
            abilityBackground(unit: unit)
                .frame(width: unit * CardRenderMetrics.CardFaceLayout.triggerStripWidth)
                .clipped()
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, unit * abilityTopOffset)
        .padding(.trailing, abilityTrailingPadding(unit: unit))
    }

    @ViewBuilder
    private func abilitySegments(unit: CGFloat) -> some View {
        let segments = viewState.abilitySegments
        let rows = abilityRows(for: Array(segments.prefix(12)))

        VStack(spacing: unit * 0.9) {
            ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { _, row in
                if row.allSatisfy(\.isIcon) {
                    HStack(spacing: unit * 0.55) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, segment in
                            if case let .icon(icon) = segment {
                                iconImage(icon, size: abilityIconSize(icon, unit: unit))
                                    .offset(y: abilityIconVerticalOffset(icon, unit: unit))
                            }
                        }
                    }
                    .frame(maxWidth: unit * 26, alignment: .center)
                } else if case let .text(text) = row.first {
                    Text(text)
                        .font(CardFontStyleResolver.shared.font(.title, size: unit * abilityTextFontSize))
                        .fontWeight(.semibold)
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
        if let image = rasterImage(for: viewState.abilityStripAsset) {
            Image(uiImage: image)
                .resizable(
                    capInsets: EdgeInsets(
                        top: unit * 2,
                        leading: unit * 2,
                        bottom: unit * 2,
                        trailing: unit * 2
                    ),
                    resizingMode: .stretch
                )
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
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

private struct CardFaceIconAssetView: View {
    let icon: FishCardFaceIconViewState
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

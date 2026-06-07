import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FishCardFaceView: View {
    let viewState: FishCardFaceViewState

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(background)

            if let color = viewState.requiredDiveSiteColor {
                Rectangle()
                    .fill(diveSiteAccent(color).opacity(0.82))
                    .frame(width: 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                header
                content
                footer
            }
            .padding(8)
        }
        .aspectRatio(viewState.aspectRatio, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(viewState.costText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(viewState.displayName)
                    .font(.caption.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(viewState.scientificName ?? AppStrings.GameBoard.cardFaceNoScientificName)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Spacer(minLength: 0)

            if !viewState.printedPointsText.isEmpty {
                Text(viewState.printedPointsText)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.indigo.opacity(0.82)))
            }
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 8) {
            fishImage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                if let trigger = viewState.abilityTriggerText {
                    Text(trigger)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(viewState.abilityText)
                    .font(.caption2)
                    .lineLimit(4)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(viewState.kind == .placeholder ? .secondary : .primary)
            }
            .padding(6)
            .frame(width: 96, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.62))
            )
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            label(viewState.lengthText)
            label(viewState.allowedZonesText)
            label(viewState.tagsText)
        }
    }

    @ViewBuilder
    private var fishImage: some View {
        if let image = localFishImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text(viewState.displayName))
        } else {
            VStack(spacing: 4) {
                Image(systemName: placeholderSymbol)
                    .font(.title3.weight(.semibold))
                Text(placeholderText)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.35))
            )
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.55)))
    }

    private var localFishImage: UIImage? {
        guard viewState.kind == .fishCard,
              let prefix = viewState.localFishImagePrefix,
              let url = localFishImageURL(prefix: prefix)
        else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func localFishImageURL(prefix: String) -> URL? {
        let directories = [
            "Resources/CardAssets/fish",
            "CardAssets/fish",
            "fish"
        ]
        for directory in directories {
            if let exact = Bundle.main.url(
                forResource: prefix,
                withExtension: "webp",
                subdirectory: directory
            ) {
                return exact
            }
            if let prefixed = Bundle.main.urls(
                forResourcesWithExtension: "webp",
                subdirectory: directory
            )?.first(where: { $0.lastPathComponent.hasPrefix("\(prefix).") }) {
                return prefixed
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

    private var background: Color {
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
            return .brown.opacity(0.42)
        case .placeholder:
            return .secondary.opacity(0.36)
        }
    }

    private var cornerRadius: CGFloat {
        8
    }

    private func diveSiteAccent(_ color: DiveSiteColor) -> Color {
        switch color {
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .green:
            return .green
        }
    }
}

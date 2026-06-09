import SwiftUI

struct FinalScoreView: View {
    let viewState: FinalScoreViewState

    @State private var animateScoreBars = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewState.title)
                        .font(.largeTitle.weight(.bold))
                    Text(viewState.winnerText)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.green)
                }

                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewState.playerRows) { row in
                        playerScoreRow(row)
                    }
                }

                legend
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animateScoreBars = true
            }
        }
    }

    private func playerScoreRow(_ row: FinalScorePlayerRowViewState) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(row.isWinner ? Color.green.opacity(0.2) : Color(.secondarySystemBackground))
                Text(row.avatarText)
                    .font(.title2.weight(.bold))
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.playerDisplayName)
                            .font(.headline)
                        Text(row.playerColorText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(row.totalText)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }

                scoreBar(row)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 6) {
                    ForEach(row.segments) { segment in
                        Text(AppStrings.GameBoard.finalScorePointsText(title: segment.title, points: segment.points))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(row.isWinner ? Color.green.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
    }

    private func scoreBar(_ row: FinalScorePlayerRowViewState) -> some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let totalWidthRatio = clampedRatio(row.totalWidthRatioRelativeToMaxTotal)
            let animationProgress = animateScoreBars ? 1.0 : 0.0

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(.tertiarySystemFill))

                ZStack(alignment: .leading) {
                    ForEach(row.segments.indices, id: \.self) { index in
                        let segment = row.segments[index]
                        let segmentWidthRatio = clampedRatio(segment.widthRatioRelativeToMaxTotal)
                        let precedingWidthRatio = clampedRatio(
                            row.segments.prefix(index).reduce(0) {
                                $0 + $1.widthRatioRelativeToMaxTotal
                            }
                        )

                        Rectangle()
                            .fill(color(for: segment.displayColorKey))
                            .frame(
                                width: availableWidth * segmentWidthRatio * animationProgress
                            )
                            .offset(x: availableWidth * precedingWidthRatio * animationProgress)
                    }
                }
                .frame(
                    width: availableWidth * totalWidthRatio * animationProgress,
                    alignment: .leading
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .frame(height: 18)
    }

    private func clampedRatio(_ ratio: Double) -> Double {
        min(max(ratio, 0), 1)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.GameBoard.finalScoreLegend)
                .font(.title2.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(viewState.legendItems) { item in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: item.displayColorKey))
                            .frame(width: 18, height: 12)
                        Text(item.title)
                            .font(.callout)
                        Spacer()
                    }
                }
            }
        }
    }

    private func color(for style: ScoreBarColorStyle) -> Color {
        switch style {
        case .weeklyAchievements:
            return .teal
        case .fishPrintedPoints:
            return .blue
        case .gameEndAbilityPoints:
            return .purple
        case .eggsAndYoung:
            return .yellow
        case .schools:
            return .green
        case .consumedFish:
            return .gray
        case .coral:
            return .pink
        case .completeReefBonus:
            return .orange
        }
    }
}

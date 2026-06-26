import SwiftUI

struct BoardLayoutCalibrationOverlay: View {
    let layout: BoardLayout
    let showsLabels: Bool

    var body: some View {
        GeometryReader { proxy in
            let boardRect = BoardLayoutMapper.boardImageRect(
                in: proxy.size,
                imageAspectRatio: CGFloat(layout.imageAspectRatio)
            )
            ZStack(alignment: .topLeading) {
                boardOutline(boardRect)

                ForEach(layout.slots) { slot in
                    calibrationRect(
                        slot.slotRect,
                        boardRect: boardRect,
                        color: .cyan,
                        lineWidth: 1.2
                    )
                    calibrationRect(
                        slot.cardRect,
                        boardRect: boardRect,
                        color: .green,
                        lineWidth: 1.1
                    )
                    calibrationRect(
                        slot.hitRect,
                        boardRect: boardRect,
                        color: .orange,
                        lineWidth: 1,
                        dash: [5, 3]
                    )
                    calibrationRect(
                        slot.highlightRect,
                        boardRect: boardRect,
                        color: .yellow,
                        lineWidth: 1,
                        dash: [2, 3]
                    )

                    if showsLabels {
                        slotLabel(slot, boardRect: boardRect)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func boardOutline(_ rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.white.opacity(0.42), lineWidth: 1.2)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    private func calibrationRect(
        _ normalizedRect: BoardNormalizedRect,
        boardRect: CGRect,
        color: Color,
        lineWidth: CGFloat,
        dash: [CGFloat] = []
    ) -> some View {
        let rect = BoardLayoutMapper.mapBoardNormalizedRect(
            normalizedRect,
            into: boardRect
        )
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(
                color.opacity(0.78),
                style: StrokeStyle(lineWidth: lineWidth, dash: dash)
            )
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color.opacity(0.045))
            )
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    private func slotLabel(
        _ slot: BoardLayoutSlot,
        boardRect: CGRect
    ) -> some View {
        let point = BoardLayoutMapper.mapBoardNormalizedPoint(
            BoardNormalizedPoint(x: slot.slotRect.x, y: slot.slotRect.y),
            into: boardRect
        )
        return Text(slot.slotId)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.black.opacity(0.54)))
            .offset(x: point.x + 3, y: point.y + 3)
    }
}

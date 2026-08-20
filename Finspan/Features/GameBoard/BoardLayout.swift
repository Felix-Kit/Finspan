import CoreGraphics
import Foundation

struct BoardNormalizedPoint: Codable, Equatable {
    let x: Double
    let y: Double
}

struct BoardNormalizedRect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    enum CodingKeys: String, CodingKey {
        case x
        case y
        case width = "w"
        case height = "h"
    }

    var maxX: Double { x + width }
    var maxY: Double { y + height }
}

struct BoardLayoutSlot: Identifiable, Codable, Equatable {
    var id: String { slotId }

    let slotId: String
    let slotRect: BoardNormalizedRect
    let cardRect: BoardNormalizedRect
    let hitRect: BoardNormalizedRect
    let highlightRect: BoardNormalizedRect
    let resourceAnchor: BoardNormalizedPoint
    let coralAnchor: BoardNormalizedPoint
    let diverAnchor: BoardNormalizedPoint
}

struct BoardLayout: Codable, Equatable {
    let id: String
    let imageAspectRatio: Double
    let backgroundAssetName: String?
    let includesPrintedForageFish: Bool?
    let coralOverlayAssetName: String?
    let coralOverlayRect: BoardNormalizedRect?
    let slots: [BoardLayoutSlot]

    func slot(id: String) -> BoardLayoutSlot? {
        slots.first { $0.slotId == id }
    }

    static let baseGamePlayerMatImageAspectRatio = 1850.0 / 3454.0

    static var placeholderBaseGame: BoardLayout {
        BoardLayout(
            id: "base.player-mat.fallback.v1",
            imageAspectRatio: baseGamePlayerMatImageAspectRatio,
            backgroundAssetName: nil,
            includesPrintedForageFish: false,
            coralOverlayAssetName: nil,
            coralOverlayRect: nil,
            slots: playerMatSlots()
        )
    }

    static func slotId(for address: OceanSlotAddress) -> String {
        let zoneId: String
        let zoneIndex: Int
        switch address.rowIndex {
        case 0...2:
            zoneId = "sunlit"
            zoneIndex = address.rowIndex
        case 3:
            zoneId = "twilight"
            zoneIndex = 0
        default:
            zoneId = "midnight"
            zoneIndex = address.rowIndex - 4
        }
        return "\(address.diveSite.rawValue).\(zoneId).\(zoneIndex)"
    }

    private static func playerMatSlots() -> [BoardLayoutSlot] {
        DiveSite.allCases.flatMap { diveSite in
            (0..<6).map { rowIndex in
                playerMatSlot(diveSite: diveSite, rowIndex: rowIndex)
            }
        }
    }

    private static func playerMatSlot(
        diveSite: DiveSite,
        rowIndex: Int
    ) -> BoardLayoutSlot {
        let boardWidth = 1850.0
        let boardHeight = 3454.0
        let columnIndex = DiveSite.allCases.firstIndex(of: diveSite) ?? 0
        let xPixels = [77.0, 663.0, 1249.0][columnIndex]
        let coralCenterXPixels = [365.021531, 847.016746, 1352.523923][columnIndex]
        let yPixels = [561.0, 965.0, 1365.0, 1909.0, 2459.0, 2859.0][rowIndex]
        let slotHeightPixels = rowIndex == 0 ? 388.0 : 387.0
        let slotRect = BoardNormalizedRect(
            x: xPixels / boardWidth,
            y: yPixels / boardHeight,
            width: 583.0 / boardWidth,
            height: slotHeightPixels / boardHeight
        )
        // The physical slot outline is slightly taller than the printed fish-card ratio.
        // Preserve the full slot for hit testing while centering a card-sized render inside it.
        let cardRect = BoardNormalizedRect(
            x: xPixels / boardWidth,
            y: (yPixels + 3.0) / boardHeight,
            width: 583.0 / boardWidth,
            height: 382.0 / boardHeight
        )
        let hitRect = BoardNormalizedRect(
            x: (xPixels - 6.0) / boardWidth,
            y: (yPixels - 5.0) / boardHeight,
            width: 595.0 / boardWidth,
            height: (slotHeightPixels + 10.0) / boardHeight
        )
        let highlightRect = BoardNormalizedRect(
            x: (xPixels + 2.0) / boardWidth,
            y: (yPixels + 2.0) / boardHeight,
            width: 579.0 / boardWidth,
            height: (slotHeightPixels - 4.0) / boardHeight
        )
        return BoardLayoutSlot(
            slotId: slotId(for: OceanSlotAddress(playerId: "layout", diveSite: diveSite, rowIndex: rowIndex)),
            slotRect: slotRect,
            cardRect: cardRect,
            hitRect: hitRect,
            highlightRect: highlightRect,
            // Resource pieces are live game tokens placed over the fish / slot artwork.
            // They do not attempt to align with a printed marker in a raster board.
            resourceAnchor: BoardNormalizedPoint(
                x: cardRect.x + cardRect.width * 0.46,
                y: cardRect.y + cardRect.height * 0.42
            ),
            coralAnchor: BoardNormalizedPoint(
                x: coralCenterXPixels / boardWidth,
                y: 1800.064815 / boardHeight
            ),
            diverAnchor: BoardNormalizedPoint(x: slotRect.x + slotRect.width * 0.12, y: slotRect.y + slotRect.height * 0.50)
        )
    }
}

enum BoardSlotArtworkPolicy {
    static func shouldRenderCardFace(
        kind: FishCardFaceKind,
        includesPrintedForageFish: Bool
    ) -> Bool {
        switch kind {
        case .empty:
            return false
        case .forageFish:
            return !includesPrintedForageFish
        case .fishCard, .placeholder:
            return true
        }
    }

    static func shouldRenderSeparateResourceTokens(
        kind: FishCardFaceKind,
        includesPrintedForageFish: Bool
    ) -> Bool {
        switch kind {
        case .empty:
            return true
        case .forageFish:
            return includesPrintedForageFish
        case .fishCard, .placeholder:
            return false
        }
    }
}

struct BoardSlotResourceTokenFrame: Equatable {
    let visualRect: CGRect
    let hitRect: CGRect
}

enum BoardSlotResourceTokenLayout {
    static let maxVisibleTokens = 5
    static let visualSizeToCardWidth: CGFloat = 0.155
    static let hitSizeToVisualSize: CGFloat = 1.28

    private static let offsetFactors: [(x: CGFloat, y: CGFloat)] = [
        (0, 0),
        (0.58, 0.18),
        (-0.42, 0.52),
        (0.18, 0.76),
        (0.76, 0.68)
    ]

    static func frame(
        at index: Int,
        anchor: CGPoint,
        cardRect: CGRect
    ) -> BoardSlotResourceTokenFrame {
        let visualSize = cardRect.width * visualSizeToCardWidth
        let offset = offsetFactors[min(max(index, 0), offsetFactors.count - 1)]
        let center = CGPoint(
            x: anchor.x + visualSize * offset.x,
            y: anchor.y + visualSize * offset.y
        )
        let visualRect = constrainedSquare(
            centeredAt: center,
            size: visualSize,
            inside: cardRect
        )
        let hitSize = visualSize * hitSizeToVisualSize
        let hitPadding = max(0, (hitSize - visualSize) / 2)
        let hitRect = visualRect
            .insetBy(dx: -hitPadding, dy: -hitPadding)
            .intersection(cardRect)
        return BoardSlotResourceTokenFrame(
            visualRect: visualRect,
            hitRect: hitRect
        )
    }

    private static func constrainedSquare(
        centeredAt center: CGPoint,
        size: CGFloat,
        inside bounds: CGRect
    ) -> CGRect {
        let constrainedSize = min(size, bounds.width, bounds.height)
        let halfSize = constrainedSize / 2
        let centerX = min(max(center.x, bounds.minX + halfSize), bounds.maxX - halfSize)
        let centerY = min(max(center.y, bounds.minY + halfSize), bounds.maxY - halfSize)
        return CGRect(
            x: centerX - halfSize,
            y: centerY - halfSize,
            width: constrainedSize,
            height: constrainedSize
        )
    }
}

struct BoardCoralTokenFrame: Equatable {
    let visualRect: CGRect
}

/// Maps earned coral pieces onto the six printed coral spaces in the S&R strip.
/// The layout stays in normalized board coordinates so it follows the same
/// aspect-fit transform as cards, hit targets, highlights, and the reef artwork.
enum BoardCoralTokenLayout {
    static let maxVisibleTokens = 6
    static let tokenSizeToBoardWidth: CGFloat = 56.0 / 1_850.0
    static let tokenSpacingToBoardWidth: CGFloat = 72.215311 / 1_850.0

    static func frames(
        coralCount: Int,
        reefCenter: BoardNormalizedPoint,
        boardRect: CGRect
    ) -> [BoardCoralTokenFrame] {
        let visibleCount = min(max(coralCount, 0), maxVisibleTokens)
        guard visibleCount > 0 else { return [] }

        let center = BoardLayoutMapper.mapBoardNormalizedPoint(
            reefCenter,
            into: boardRect
        )
        let tokenSize = boardRect.width * tokenSizeToBoardWidth
        let spacing = boardRect.width * tokenSpacingToBoardWidth
        let firstCenterX = center.x - spacing * CGFloat(maxVisibleTokens - 1) / 2

        return (0..<visibleCount).map { index in
            let tokenCenter = CGPoint(
                x: firstCenterX + spacing * CGFloat(index),
                y: center.y
            )
            return BoardCoralTokenFrame(
                visualRect: CGRect(
                    x: tokenCenter.x - tokenSize / 2,
                    y: tokenCenter.y - tokenSize / 2,
                    width: tokenSize,
                    height: tokenSize
                )
            )
        }
    }
}

enum BoardLayoutMapper {
    static func boardImageRect(
        in containerSize: CGSize,
        imageAspectRatio: CGFloat
    ) -> CGRect {
        guard containerSize.width > 0,
              containerSize.height > 0,
              imageAspectRatio > 0
        else {
            return .zero
        }

        let containerAspectRatio = containerSize.width / containerSize.height
        if containerAspectRatio > imageAspectRatio {
            let height = containerSize.height
            let width = height * imageAspectRatio
            return CGRect(
                x: (containerSize.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        }

        let width = containerSize.width
        let height = width / imageAspectRatio
        return CGRect(
            x: 0,
            y: (containerSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    static func mapBoardNormalizedRect(
        _ rect: BoardNormalizedRect,
        into boardImageRect: CGRect
    ) -> CGRect {
        CGRect(
            x: boardImageRect.minX + boardImageRect.width * rect.x,
            y: boardImageRect.minY + boardImageRect.height * rect.y,
            width: boardImageRect.width * rect.width,
            height: boardImageRect.height * rect.height
        )
    }

    static func mapBoardNormalizedPoint(
        _ point: BoardNormalizedPoint,
        into boardImageRect: CGRect
    ) -> CGPoint {
        CGPoint(
            x: boardImageRect.minX + boardImageRect.width * point.x,
            y: boardImageRect.minY + boardImageRect.height * point.y
        )
    }
}

enum BoardLayoutStore {
    static func load(
        named resourceName: String = "player_mat_layout",
        bundle: Bundle = .main
    ) -> BoardLayout? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BoardLayout.self, from: data)
        } catch {
            return nil
        }
    }
}

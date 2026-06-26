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
    let slots: [BoardLayoutSlot]

    func slot(id: String) -> BoardLayoutSlot? {
        slots.first { $0.slotId == id }
    }

    static let baseGamePlaceholderImageAspectRatio = 16.0 / 9.0

    static var placeholderBaseGame: BoardLayout {
        BoardLayout(
            id: "base.placeholder.manual.v1",
            imageAspectRatio: baseGamePlaceholderImageAspectRatio,
            slots: placeholderSlots()
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

    private static func placeholderSlots() -> [BoardLayoutSlot] {
        DiveSite.allCases.flatMap { diveSite in
            (0..<6).map { rowIndex in
                placeholderSlot(diveSite: diveSite, rowIndex: rowIndex)
            }
        }
    }

    private static func placeholderSlot(
        diveSite: DiveSite,
        rowIndex: Int
    ) -> BoardLayoutSlot {
        let columnIndex = Double(DiveSite.allCases.firstIndex(of: diveSite) ?? 0)
        let x = 0.055 + columnIndex * 0.315
        let y = 0.095 + Double(rowIndex) * 0.123
        let slotRect = BoardNormalizedRect(x: x, y: y, width: 0.255, height: 0.104)
        let cardRect = BoardNormalizedRect(x: x + 0.014, y: y + 0.008, width: 0.227, height: 0.088)
        let hitRect = BoardNormalizedRect(x: x - 0.008, y: y - 0.006, width: 0.271, height: 0.116)
        let highlightRect = BoardNormalizedRect(x: x + 0.004, y: y + 0.004, width: 0.247, height: 0.096)
        return BoardLayoutSlot(
            slotId: slotId(for: OceanSlotAddress(playerId: "layout", diveSite: diveSite, rowIndex: rowIndex)),
            slotRect: slotRect,
            cardRect: cardRect,
            hitRect: hitRect,
            highlightRect: highlightRect,
            resourceAnchor: BoardNormalizedPoint(x: cardRect.x + cardRect.width * 0.46, y: cardRect.y + cardRect.height * 0.42),
            coralAnchor: BoardNormalizedPoint(x: slotRect.x + slotRect.width * 0.85, y: slotRect.y + slotRect.height * 0.55),
            diverAnchor: BoardNormalizedPoint(x: slotRect.x + slotRect.width * 0.12, y: slotRect.y + slotRect.height * 0.50)
        )
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
        named resourceName: String = "placeholder_board_layout",
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

import Foundation

/// Playable development-only ocean layout.
///
/// This preserves the current 18-slot sample board until the authoritative
/// base game ocean mat positions and printed forage fish data are available.
enum SampleOceanLayout {
    nonisolated static let rowIndices = Array(0...5)

    nonisolated static func baseGameInitial(for playerId: PlayerID) -> OceanState {
        let startingResourceSummary = [
            ResourceQuantity(kind: .egg, amount: 2),
            ResourceQuantity(kind: .young, amount: 1)
        ]
        let forageFishLayout = baseForageFish()

        return OceanState(
            resources: startingResourceSummary,
            slots: DiveSite.allCases.flatMap { diveSite in
                rowIndices.map { rowIndex in
                    let address = OceanSlotAddress(
                        playerId: playerId,
                        diveSite: diveSite,
                        rowIndex: rowIndex
                    )
                    let forageFish = forageFishLayout.first { fish in
                        fish.diveSite == diveSite && fish.rowIndex == rowIndex
                    }
                    // Setup pieces remain part of deterministic ocean state. Presentation places
                    // them as live tokens over their fish / slot artwork rather than relying on
                    // a printed marker in the board raster.
                    let slotResources = (forageFish.map(startingResources) ?? [])
                        + startingOpenSlotResources(diveSite: diveSite, rowIndex: rowIndex)
                    return OceanSlot(
                        address: address,
                        diveSiteColor: diveSiteColor(for: diveSite),
                        content: forageFish.map(OceanSlotContent.forageFish) ?? .empty,
                        resources: slotResources,
                        consumedFish: []
                    )
                }
            }
        )
    }

    nonisolated static func baseForageFish() -> [ForageFish] {
        [
            ForageFish(
                forageFishId: "sample-forage-blue-row-4",
                name: "Glasshead Grenadier",
                lengthCm: 9,
                diveSite: .blue,
                rowIndex: 4
            ),
            ForageFish(
                forageFishId: "sample-forage-purple-row-3",
                name: "Showy Bristlemouth",
                lengthCm: 3,
                diveSite: .purple,
                rowIndex: 3
            ),
            ForageFish(
                forageFishId: "sample-forage-green-row-1",
                name: "Catalina Goby",
                lengthCm: 1,
                diveSite: .green,
                rowIndex: 1
            )
        ]
    }

    nonisolated private static func diveSiteColor(for diveSite: DiveSite) -> DiveSiteColor {
        switch diveSite {
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .green:
            return .green
        }
    }

    nonisolated private static func startingResources(for fish: ForageFish) -> [ResourceQuantity] {
        switch (fish.diveSite, fish.rowIndex) {
        case (.blue, 4):
            return [ResourceQuantity(kind: .egg, amount: 1)]
        case (.green, 1):
            return [ResourceQuantity(kind: .egg, amount: 1)]
        default:
            return []
        }
    }

    nonisolated private static func startingOpenSlotResources(
        diveSite: DiveSite,
        rowIndex: Int
    ) -> [ResourceQuantity] {
        guard diveSite == .purple, rowIndex == 2 else {
            return []
        }
        return [ResourceQuantity(kind: .young, amount: 1)]
    }
}

/// Future entry point for authoritative base game ocean mat data.
///
/// Keep verified base game positions separate from `SampleOceanLayout` so the
/// sample playable loop can remain stable while real data is introduced.
enum BaseGameOceanLayout {}

import XCTest
@testable import Finspan

final class InlineAbilityInteractionTests: XCTestCase {
    func testRecoverFromDiscardOrDrawCanStartInlineWithDiscardOverlayOrDrawCommit() throws {
        let record = try auditRecord(cardId: "base.main.012")

        XCTAssertEqual(record["canStartInline"] as? Bool, true)
        XCTAssertContains(record, "inlineEntrySurface", "cardAbilityIcon")
        XCTAssertContains(record, "continuationSurface", "discardOverlay")
        XCTAssertContains(record, "continuationSurface", "directCommit")
        XCTAssertEqual(record["commitReversibility"] as? String, "stagedOnlyUndo")
        XCTAssertEqual(record["requiresOverlay"] as? Bool, true)
    }

    func testConsumeFishFromHandCanStartInlineWithHandPickerAndBoardTarget() throws {
        let record = try auditRecord(cardId: "base.main.034")

        XCTAssertEqual(record["canStartInline"] as? Bool, true)
        XCTAssertContains(record, "inlineEntrySurface", "cardAbilityIcon")
        XCTAssertContains(record, "continuationSurface", "handPicker")
        XCTAssertContains(record, "continuationSurface", "boardTarget")
        XCTAssertEqual(record["commitReversibility"] as? String, "stagedOnlyUndo")
    }

    func testPlayFishForFreeAndFromHandCanStartInlineIntoPlayFishFlow() throws {
        let freePlay = try auditRecord(cardId: "sr.main.150")
        let paidPlay = try auditRecord(cardId: "base.main.002")

        XCTAssertEqual(freePlay["canStartInline"] as? Bool, true)
        XCTAssertContains(freePlay, "continuationSurface", "handPicker")
        XCTAssertContains(freePlay, "continuationSurface", "playFishFlow")
        XCTAssertFalse((freePlay["continuationSurface"] as? [String] ?? []).contains("paymentFlow"))

        XCTAssertEqual(paidPlay["canStartInline"] as? Bool, true)
        XCTAssertContains(paidPlay, "continuationSurface", "handPicker")
        XCTAssertContains(paidPlay, "continuationSurface", "playFishFlow")
        XCTAssertContains(paidPlay, "continuationSurface", "paymentFlow")
    }

    func testDrawFishCanStartInlineWithDirectCommitAndNoCommittedUndo() throws {
        let record = try auditRecord(cardId: "base.main.010")

        XCTAssertEqual(record["canStartInline"] as? Bool, true)
        XCTAssertContains(record, "inlineEntrySurface", "cardAbilityIcon")
        XCTAssertContains(record, "continuationSurface", "directCommit")
        XCTAssertEqual(record["commitReversibility"] as? String, "noCommittedUndo")
        XCTAssertEqual(record["requiresOverlay"] as? Bool, false)
    }

    func testGameEndScoringCanStartInlineThroughGameEndDock() throws {
        let record = try auditRecord(cardId: "base.main.001")

        XCTAssertEqual(record["canStartInline"] as? Bool, true)
        XCTAssertContains(record, "inlineEntrySurface", "gameEndDock")
        XCTAssertContains(record, "inlineEntrySurface", "cardAbilityIcon")
        XCTAssertContains(record, "continuationSurface", "directCommit")
        XCTAssertEqual(record["commitReversibility"] as? String, "noCommittedUndo")
        XCTAssertEqual(record["sourceVisibility"] as? String, "gameEndSourceCard")
    }

    func testAllPlayersUsesCardIconForSourceAndIncomingDockForTargets() throws {
        let record = try auditRecord(cardId: "base.main.050")

        XCTAssertEqual(record["canStartInline"] as? Bool, true)
        XCTAssertContains(record, "inlineEntrySurface", "cardAbilityIcon")
        XCTAssertContains(record, "inlineEntrySurface", "incomingRewardDock")
        XCTAssertContains(record, "sourceVisibilityOptions", "ownVisibleSourceCard")
        XCTAssertContains(record, "sourceVisibilityOptions", "externalPendingReward")
        XCTAssertEqual(record["commitReversibility"] as? String, "noCommittedUndo")
    }

    func testAuditSummaryKeepsAbilityCoverageStable() throws {
        let report = try auditReport()
        let stats = try XCTUnwrap(report["stats"] as? [String: Any])
        let legacy = try XCTUnwrap(stats["legacyCategories"] as? [String: Any])
        let entry = try XCTUnwrap(stats["inlineEntrySurface"] as? [String: Any])
        let continuation = try XCTUnwrap(stats["continuationSurface"] as? [String: Any])
        let reversibility = try XCTUnwrap(stats["commitReversibility"] as? [String: Any])

        XCTAssertEqual(stats["total"] as? Int, 215)
        XCTAssertEqual(intValue(legacy["D.notEnoughMetadata"]), 0)
        XCTAssertGreaterThan(intValue(entry["cardAbilityIcon"]), 0)
        XCTAssertGreaterThan(intValue(entry["incomingRewardDock"]), 0)
        XCTAssertGreaterThan(intValue(entry["gameEndDock"]), 0)
        XCTAssertGreaterThan(intValue(continuation["directCommit"]), 0)
        XCTAssertGreaterThan(intValue(continuation["discardOverlay"]), 0)
        XCTAssertGreaterThan(intValue(continuation["handPicker"]), 0)
        XCTAssertGreaterThan(intValue(reversibility["noCommittedUndo"]), 0)
        XCTAssertGreaterThan(intValue(reversibility["stagedOnlyUndo"]), 0)
    }

    private func auditRecord(cardId: String) throws -> [String: Any] {
        let report = try auditReport()
        let records = try XCTUnwrap(report["records"] as? [[String: Any]])
        return try XCTUnwrap(records.first { $0["cardId"] as? String == cardId })
    }

    private func auditReport() throws -> [String: Any] {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        url.appendPathComponent("tools/generated/card_rendering/inline_ability_interaction_audit.json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func XCTAssertContains(
        _ record: [String: Any],
        _ key: String,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let values = record[key] as? [String] ?? []
        XCTAssertTrue(values.contains(expected), "\(key) did not contain \(expected): \(values)", file: file, line: line)
    }

    private func intValue(_ value: Any?) -> Int {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return 0
    }
}

#!/usr/bin/env python3
"""Audit weekly achievement tile scoring coverage from the Swift catalog."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Finspan/Core/Scoring/WeeklyGoalDefinitions.swift"
GOAL_PATTERN = re.compile(
    r'goal\("(?P<id>[^"]+)".*?,\s*(?P<implemented>true|false),\s*"[^"]+"'
    r'(?P<review>,\s*needsReview:\s*true)?\),?'
)


def main() -> int:
    text = SOURCE.read_text(encoding="utf-8")
    side_b = [
        {
            "id": match.group("id"),
            "implemented": match.group("implemented") == "true",
            "needs_review": match.group("review") is not None,
        }
        for match in GOAL_PATTERN.finditer(text)
    ]

    # sideAGoals(for:) produces three fixed tiles for each of the two board sets.
    fixed_side_a_count = 6
    implemented_count = fixed_side_a_count + sum(item["implemented"] for item in side_b)
    unimplemented = [item["id"] for item in side_b if not item["implemented"]]
    needs_review = [item["id"] for item in side_b if item["needs_review"]]
    total = fixed_side_a_count + len(side_b)

    print("# Weekly Goal Scoring Audit")
    print()
    print(f"- Total weekly goal tiles: {total}")
    print(f"- Implemented scoring count: {implemented_count}")
    print(f"- Unimplemented scoring count: {len(unimplemented)}")
    print(f"- Needs review count: {len(needs_review)}")
    print(f"- Unimplemented tile ids: {', '.join(unimplemented) if unimplemented else 'none'}")
    print(f"- Needs review tile ids: {', '.join(needs_review) if needs_review else 'none'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-Finspan.xcodeproj}"
SCHEME="${SCHEME:-Finspan}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,id=F79B4A88-38AC-4D26-BACD-625C06BAE4BF}"

xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  "$@"

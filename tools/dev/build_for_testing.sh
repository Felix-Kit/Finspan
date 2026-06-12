#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-Finspan.xcodeproj}"
SCHEME="${SCHEME:-Finspan}"
DEFAULT_IPAD_A16_UDID="07315B4E-5852-4580-8047-069A099726BB"

resolve_destination() {
  if [[ -n "${DESTINATION:-}" ]]; then
    printf '%s\n' "$DESTINATION"
    return 0
  fi

  local destinations
  destinations="$(xcodebuild -showdestinations -project "$PROJECT" -scheme "$SCHEME" 2>/dev/null)"

  if grep -Fq "id:$DEFAULT_IPAD_A16_UDID" <<<"$destinations"; then
    printf 'platform=iOS Simulator,id=%s\n' "$DEFAULT_IPAD_A16_UDID"
    return 0
  fi

  local ipad_a16_id
  ipad_a16_id="$(
    awk '
      /platform:iOS Simulator/ && /name:iPad \(A16\)/ {
        if (match($0, /id:[^,}]*/)) {
          print substr($0, RSTART + 3, RLENGTH - 3)
          exit
        }
      }
    ' <<<"$destinations"
  )"
  if [[ -n "$ipad_a16_id" ]]; then
    printf 'platform=iOS Simulator,id=%s\n' "$ipad_a16_id"
    return 0
  fi

  local any_ipad_id
  any_ipad_id="$(
    awk '
      /platform:iOS Simulator/ && /name:iPad/ {
        if (match($0, /id:[^,}]*/)) {
          print substr($0, RSTART + 3, RLENGTH - 3)
          exit
        }
      }
    ' <<<"$destinations"
  )"
  if [[ -n "$any_ipad_id" ]]; then
    printf 'platform=iOS Simulator,id=%s\n' "$any_ipad_id"
    return 0
  fi

  printf '%s\n' "Unable to find a usable iPad simulator destination for scheme $SCHEME." >&2
  return 1
}

DESTINATION="$(resolve_destination)"
printf 'Using build destination: %s\n' "$DESTINATION"

xcodebuild build-for-testing \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION"

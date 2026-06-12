# Development Commands

Finspan local development defaults to the lightweight iPad (A16) simulator:

```bash
platform=iOS Simulator,id=07315B4E-5852-4580-8047-069A099726BB
```

`tools/dev/build_for_testing.sh` and `tools/dev/test_focused.sh` now resolve destinations this way:

1. Use `DESTINATION` if you explicitly set one.
2. Otherwise prefer the known iPad (A16) UDID above when it exists.
3. If that UDID is missing on the current machine, auto-discover another available iPad (A16).
4. If no iPad (A16) exists, fall back to the first available iPad simulator.

The scripts print `Using build destination: ...` or `Using test destination: ...` before running `xcodebuild`, which is the fastest way to confirm what the test host actually tried to boot.

Do not default routine builds or focused tests to iPad Pro 13-inch (M5). Use the M5 simulator only when a large-screen UI verification specifically needs it.

## Build For Testing

```bash
tools/dev/build_for_testing.sh
```

## Focused Tests

```bash
tools/dev/test_focused.sh -only-testing:FinspanTests/GameEngineTests/testEuropeanAnchovyGameEndPlacesEggOnEachTopRowFish
```

## Temporary Destination Override

```bash
DESTINATION='platform=iOS Simulator,name=iPad Pro 13-inch (M5)' tools/dev/build_for_testing.sh
```

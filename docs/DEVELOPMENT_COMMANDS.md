# Development Commands

Finspan local development defaults to the lightweight iPad (A16) simulator:

```bash
platform=iOS Simulator,id=F79B4A88-38AC-4D26-BACD-625C06BAE4BF
```

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

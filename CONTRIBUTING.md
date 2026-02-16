# Contributing

## Prerequisites
- Xcode 16+ (or newer)
- Swift 6 toolchain
- `xcodegen` (for regenerating the app project from `project.yml`)

## Local setup
```bash
swift build
swift test
xcodegen generate
```

## Run iOS tests locally
```bash
SIM_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $2; exit}')"
xcodebuild \
  -project HomeScreenOptimizerApp.xcodeproj \
  -scheme HomeScreenOptimizeriOS \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  test
```

## Pull requests
- Keep changes scoped and include tests for new behavior.
- If `project.yml` is updated, regenerate and commit changes in `HomeScreenOptimizerApp.xcodeproj`.
- Ensure `swift test` and iOS simulator tests pass before opening a PR.

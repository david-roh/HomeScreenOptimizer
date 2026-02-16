# Home Screen Optimizer

This repository contains the MVP foundation for an iOS home-screen layout optimizer.

## Current implementation
- Modular Swift Package architecture.
- Core domain models and persistence repositories.
- Screenshot import session pipeline (domain layer).
- OCR extraction + post-processing + grid slot mapping for imported screenshots.
- Inline OCR correction controls for app-name and slot adjustments.
- Onboarding profile builder, goal weighting, and reachability calibration mini-test.
- Manual usage input (minutes/day) with per-profile persistence.
- Screen Time screenshot OCR import to auto-fill manual usage inputs.
- Reachability-aware layout planner with generated manual move guide.
- iOS SwiftUI shell app target with simulator support.
- CI workflow with build and tests.

## Run locally
```bash
swift build
swift test
swift run HSOPrototype
```

## Run iOS app in simulator
```bash
xcodegen generate
open HomeScreenOptimizerApp.xcodeproj
```

Then in Xcode:
1. Select scheme `HomeScreenOptimizeriOS`.
2. Select an iPhone simulator (for example `iPhone 17`).
3. Press Run (`⌘R`).
4. Run tests with `⌘U`.

## Key docs
- Backlog: `IMPLEMENTATION_BACKLOG.md`
- Sprint state: `SPRINT_TRACKER.md`
- Migration strategy: `docs/MIGRATIONS.md`

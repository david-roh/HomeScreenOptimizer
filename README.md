# Home Screen Optimizer
[![CI](https://github.com/david-roh/HomeScreenOptimizer/actions/workflows/ci.yml/badge.svg)](https://github.com/david-roh/HomeScreenOptimizer/actions/workflows/ci.yml)

This repository contains the MVP foundation for an iOS home-screen layout optimizer.

## Current implementation
- Modular Swift Package architecture.
- Core domain models and persistence repositories.
- Screenshot import session pipeline (domain layer).
- OCR extraction + post-processing + grid slot mapping for imported screenshots.
- Inline OCR correction controls for app-name and slot adjustments.
- Onboarding profile builder, goal weighting, and reachability calibration mini-test.
- Manual usage input (minutes/day) with per-profile persistence.
- Native Screen Time API connector (FamilyControls + DeviceActivity report extension) that can import usage without screenshot OCR.
- Screen Time screenshot OCR import to auto-fill manual usage inputs.
- Screen Time duration parser now supports localized/variant time formats.
- Reachability-aware layout planner with generated manual move guide.
- Guided apply checklist with per-profile progress persistence.
- Recommendation history persistence with rerun score/move comparison.
- Local analytics event logging for guide generation and guided-apply progress.
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

### Native Screen Time notes
- The app now includes a Device Activity Report extension and app-group bridge for native usage snapshots.
- You still need Apple Family Controls entitlement approval on your developer account for full on-device/live-data behavior outside local simulator signing.

## CI
- Workflow: [CI](https://github.com/david-roh/HomeScreenOptimizer/actions/workflows/ci.yml)
- Runs on push/PR:
  - Swift package build + tests + prototype smoke run.
  - iOS simulator test job (unit tests + UI smoke test) with artifacted `.xcresult`.

## Key docs
- Backlog: `IMPLEMENTATION_BACKLOG.md`
- Sprint state: `SPRINT_TRACKER.md`
- Migration strategy: `docs/MIGRATIONS.md`

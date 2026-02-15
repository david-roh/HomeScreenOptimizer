# Sprint Tracker

## Sprint 1 (Week 1-2)

### E1-T1 Project bootstrap
- Status: DONE
- Notes:
  - Swift Package scaffolded with module targets.
  - CI workflow added (`swift build`, `swift test`, optional swiftlint).

### E1-T2 Core data models
- Status: DONE
- Notes:
  - Models implemented in `Sources/Core/Models`.
  - Serialization tests added.

### E1-T3 Local persistence layer
- Status: DONE
- Notes:
  - File and in-memory repositories implemented for profiles and layout plans.
  - Migration envelope and profile migrator in place.

### E2-T1 Screenshot import pipeline
- Status: IN_PROGRESS
- Notes:
  - Session model, file-backed repository, and coordinator implemented.
  - Add/reorder/remove/resume logic covered by tests.
  - Basic app UI can start/reset sessions and add/remove screenshots via PhotosPicker.

### E4-T1 Onboarding profile setup
- Status: DONE
- Notes:
  - Onboarding answer model + profile builder implemented.
  - Default naming and weight normalization tested.
  - App UI wired for context, handedness, grip mode, and goal weights.

## Next immediate tasks
1. Complete E2-T1 by adding page reorder UX in the iOS app screen.
2. Start E2-T2 OCR extraction implementation with Vision.
3. Add E7-T1 preview shell to visualize before/after layouts.

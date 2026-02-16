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
- Status: DONE
- Notes:
  - Session model, file-backed repository, and coordinator implemented.
  - Add/reorder/remove/resume logic covered by tests.
  - Basic app UI can start/reset sessions and add/remove screenshots via PhotosPicker.
  - Latest session auto-resumes on app launch.

### E2-T2 OCR and grid extraction
- Status: IN_PROGRESS
- Notes:
  - Vision OCR extractor wired in the iOS app.
  - OCR post-processing and quality scoring implemented.
  - Grid mapper converts located OCR labels into page/row/column slots.

### E4-T1 Onboarding profile setup
- Status: DONE
- Notes:
  - Onboarding answer model + profile builder implemented.
  - Default naming and weight normalization tested.
  - App UI wired for context, handedness, grip mode, and goal weights.

### E4-T2 Reachability calibration mini-test
- Status: DONE
- Notes:
  - In-app calibration flow captures timed tap samples across key grid targets.
  - Calibrated reachability map is attached to newly saved profiles.
  - Calibration logic covered by unit tests.

### E5-T2 Initial assignment solver
- Status: IN_PROGRESS
- Notes:
  - Reachability-aware planner implemented with calibrated-map override.
  - Deterministic ranking of apps and slots now produces a recommended layout plan.
  - Planner behavior covered by optimizer unit tests.

### E7-T1 Results preview UI
- Status: IN_PROGRESS
- Notes:
  - Recommendation guide section added in app UI.
  - Displays score delta, current/recommended slot previews, and manual move sequence.

## Next immediate tasks
1. Build E2-T3 manual correction tools (inline rename and slot edits for OCR mistakes).
2. Add E3-T2 fallback usage import from Screen Time screenshots.
3. Add E7-T2 guided apply checklist with progress tracking while users move icons.

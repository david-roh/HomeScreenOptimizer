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

### E2-T3 Manual correction interface
- Status: IN_PROGRESS
- Notes:
  - Inline OCR correction UI added for app-name edits and slot page/row/column adjustments.
  - Duplicate-slot conflict warning shown before guide generation.
  - iOS unit tests added for correction behaviors in `RootViewModel`.

### E3-T2 Usage fallback import
- Status: IN_PROGRESS
- Notes:
  - Manual usage entry fields (minutes/day) added to recommendation flow.
  - Usage snapshots persist per profile via file-backed repository.
  - Normalized manual usage now feeds planner utility scoring.
  - Screen Time screenshot OCR import now auto-fills usage minutes.

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

### E7-T2 Guided apply checklist
- Status: IN_PROGRESS
- Notes:
  - Checklist UI now supports per-step completion toggles.
  - "Mark Next Complete" and reset-progress controls added.
  - Progress persists per profile and restores after profile switching/app relaunch.

### E7-T3 Recommendation history
- Status: IN_PROGRESS
- Notes:
  - Recommended plans are now persisted as per-profile history snapshots.
  - App shows recent history rows with timestamp and aggregate score.
  - Current run can be compared against previous runs for score and move-count delta.

## Next immediate tasks
1. Expand Screen Time parser with locale/time-format variations and correction UI.
2. Add analytics event hooks for guided-apply start/progress/completion.
3. Add guide completion export/share summary for user follow-through.

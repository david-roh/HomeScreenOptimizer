# Home Screen Optimizer - Implementation Backlog

## Planning Assumptions
- Platform: iOS consumer app (App Store compliant), no private APIs.
- Scope: intelligent planner + guided manual rearrangement workflow.
- Architecture: SwiftUI + MVVM + local-first persistence.
- Team assumption: 1-3 engineers, 8-week MVP target.

## Status Legend
- `TODO`: not started
- `IN_PROGRESS`: currently being built
- `BLOCKED`: waiting on dependency/decision
- `DONE`: implemented and accepted

## Priority Legend
- `P0`: ship blocker
- `P1`: core MVP
- `P2`: strong value but deferrable

## Epic E1 - Foundation and App Skeleton
Goal: establish app shell, modules, storage, and instrumentation.

### E1-T1 - Project bootstrap
- Priority: `P0`
- Status: `TODO`
- Description: Create Xcode project, module folders, build settings, linting, and CI pipeline.
- Acceptance criteria:
1. App builds locally and in CI for Debug/Release.
2. CI runs unit tests and SwiftLint on pull requests.
3. Module folders exist: `Ingestion`, `Usage`, `Optimizer`, `Profiles`, `Guide`, `Simulation`, `Privacy`, `Core`.
- Dependencies: none

### E1-T2 - Core data models
- Priority: `P0`
- Status: `TODO`
- Description: Define shared models and schema with migration strategy.
- Acceptance criteria:
1. Models implemented: `AppItem`, `Slot`, `LayoutAssignment`, `LayoutPlan`, `MoveStep`, `Profile`, `ScoreBreakdown`.
2. Schema migration strategy documented and covered by tests.
3. Serialization round-trip tests pass for all models.
- Dependencies: E1-T1

### E1-T3 - Local persistence layer
- Priority: `P0`
- Status: `TODO`
- Description: Implement local DB repository interfaces and adapters.
- Acceptance criteria:
1. CRUD operations implemented for profiles, layouts, and sessions.
2. Persistence is fully offline and on-device.
3. Repository integration tests pass with seed fixtures.
- Dependencies: E1-T2

### E1-T4 - Analytics and diagnostics
- Priority: `P1`
- Status: `TODO`
- Description: Add event tracking abstraction and local debug dashboard.
- Acceptance criteria:
1. Events logged for key funnel points (import start, plan generated, guided apply started/completed).
2. Logging can be disabled from debug settings.
3. No PII sent externally in MVP.
- Dependencies: E1-T1

## Epic E2 - Layout Ingestion and Verification
Goal: capture user current home-screen layout from screenshots with correction flow.

### E2-T1 - Screenshot import pipeline
- Priority: `P0`
- Status: `TODO`
- Description: Implement multi-image picker and page ordering.
- Acceptance criteria:
1. User can import one or more home-screen screenshots.
2. Imported pages can be reordered and removed before processing.
3. Session state survives app restart.
- Dependencies: E1-T3

### E2-T2 - OCR and grid extraction
- Priority: `P0`
- Status: `TODO`
- Description: Use Vision OCR to extract app names and map to grid coordinates.
- Acceptance criteria:
1. OCR output includes confidence scores per label.
2. Grid detection supports common iPhone page layouts.
3. Extraction quality report visible to user (high/medium/low confidence).
- Dependencies: E2-T1

### E2-T3 - Manual correction interface
- Priority: `P0`
- Status: `TODO`
- Description: Build UI to fix misdetected app names/slots quickly.
- Acceptance criteria:
1. User can rename app labels inline.
2. User can drag/drop app tiles between slots/pages.
3. Changes are persisted and versioned as a correction set.
- Dependencies: E2-T2

### E2-T4 - Folder/dock/widget representation
- Priority: `P1`
- Status: `TODO`
- Description: Model non-standard slots and constraints.
- Acceptance criteria:
1. Dock slots are captured and editable.
2. Folder placeholders supported in layout model.
3. Unknown widget areas can be marked as locked slots.
- Dependencies: E2-T3

## Epic E3 - Usage and Behavior Intake
Goal: collect usage signals needed for optimization.

### E3-T1 - Screen Time permission and connector
- Priority: `P1`
- Status: `TODO`
- Description: Integrate FamilyControls/DeviceActivity pathway where available and permitted.
- Acceptance criteria:
1. Permission flow implemented with explanatory UI.
2. Usage signal adapter produces normalized per-app scores.
3. Permission denied state handled gracefully.
- Dependencies: E1-T1

### E3-T2 - Usage fallback import
- Priority: `P1`
- Status: `TODO`
- Description: Screenshot-based usage import if API pathway unavailable.
- Acceptance criteria:
1. User can import Screen Time screenshots.
2. OCR pipeline extracts app usage durations with confidence.
3. User can manually edit extracted durations.
- Dependencies: E2-T2

### E3-T3 - Task-flow sequence inference
- Priority: `P1`
- Status: `TODO`
- Description: Generate pairwise transition matrix from available behavior signals.
- Acceptance criteria:
1. Transition matrix normalized and persisted by profile.
2. Low-confidence transitions are flagged and down-weighted.
3. Unit tests validate matrix generation on sample datasets.
- Dependencies: E3-T1, E3-T2

## Epic E4 - Personalization and Profiles
Goal: model hand preference, reachability, and context profiles.

### E4-T1 - Onboarding profile setup
- Priority: `P0`
- Status: `TODO`
- Description: Capture handedness, grip style, and goals during onboarding.
- Acceptance criteria:
1. User can choose left/right/alternating hand preference.
2. One-hand vs two-hand usage mode supported.
3. Goal sliders saved to profile defaults.
- Dependencies: E1-T3

### E4-T2 - Reachability calibration mini-test
- Priority: `P1`
- Status: `TODO`
- Description: Interactive tap test to build per-user reach heatmap.
- Acceptance criteria:
1. Calibration finishes in under 45 seconds.
2. Reach map stored as normalized slot weights.
3. Skip option available with sensible defaults.
- Dependencies: E4-T1

### E4-T3 - Context profile management
- Priority: `P1`
- Status: `TODO`
- Description: Support Workday, Weekend, and one custom profile.
- Acceptance criteria:
1. User can create/select profile contexts.
2. Each profile stores independent weights and target layout.
3. Switching profiles triggers re-simulation without data loss.
- Dependencies: E4-T1

## Epic E5 - Optimization Engine
Goal: generate high-quality recommended layouts under constraints.

### E5-T1 - Scoring function implementation
- Priority: `P0`
- Status: `TODO`
- Description: Implement weighted objective for utility, flow, aesthetics, and move cost.
- Acceptance criteria:
1. Score components computed independently and as aggregate.
2. Default weights configurable at runtime.
3. Unit tests validate deterministic scoring with fixtures.
- Dependencies: E2-T4, E3-T3, E4-T2

### E5-T2 - Initial assignment solver
- Priority: `P0`
- Status: `TODO`
- Description: Build assignment stage (e.g., Hungarian or min-cost matching).
- Acceptance criteria:
1. Produces valid one-app-per-slot assignments.
2. Honors locked/forbidden slot constraints.
3. Solves standard layout in under 500 ms on target devices.
- Dependencies: E5-T1

### E5-T3 - Local search refinement
- Priority: `P1`
- Status: `TODO`
- Description: Improve assignment via swap/block neighborhood search.
- Acceptance criteria:
1. Refinement improves or preserves baseline score.
2. Search capped by time/iteration budget.
3. Convergence metrics exposed for debug.
- Dependencies: E5-T2

### E5-T4 - Multi-objective presets
- Priority: `P1`
- Status: `TODO`
- Description: Presets for Utility, Aesthetic, Flow, and Hybrid modes.
- Acceptance criteria:
1. Preset switching updates weights immediately.
2. Preset descriptions explain tradeoffs clearly.
3. Preset choice persisted per profile.
- Dependencies: E5-T1

## Epic E6 - Aesthetic Engines
Goal: include mathematically driven visual arrangement options.

### E6-T1 - Color-gradient arrangement
- Priority: `P2`
- Status: `TODO`
- Description: Score app order by icon color vectors against gradient templates.
- Acceptance criteria:
1. Dominant color extraction works on app icons.
2. Gradient coherence score available in simulator.
3. Works across at least 3 gradient directions.
- Dependencies: E5-T1

### E6-T2 - Symmetry and minimalism patterns
- Priority: `P2`
- Status: `TODO`
- Description: Optional symmetry and sparse-layout scoring.
- Acceptance criteria:
1. Symmetry score supports horizontal and radial variants.
2. Minimalism mode can reserve blank-friendly regions.
3. Constraint conflicts handled with user-visible warnings.
- Dependencies: E5-T1

### E6-T3 - Category block layout
- Priority: `P2`
- Status: `TODO`
- Description: Group by user-defined category with contiguous zones.
- Acceptance criteria:
1. Users can map apps to categories quickly.
2. Category zone boundaries remain stable across reruns.
3. Category objective integrates with move-cost penalty.
- Dependencies: E5-T3

## Epic E7 - What-If Simulator and Results UX
Goal: make recommendations understandable and comparable.

### E7-T1 - Results preview UI
- Priority: `P0`
- Status: `TODO`
- Description: Build before/after page previews with highlighted changes.
- Acceptance criteria:
1. Current and recommended layouts shown side by side.
2. Changed apps visibly tagged.
3. User can inspect per-page and all-pages views.
- Dependencies: E5-T2

### E7-T2 - Score breakdown and deltas
- Priority: `P1`
- Status: `TODO`
- Description: Show reachability, effort, aesthetic, and move-count deltas.
- Acceptance criteria:
1. Four core metrics displayed with clear directionality.
2. Tooltips explain each metric in plain language.
3. Metrics recalc after weight/profile changes.
- Dependencies: E7-T1, E5-T1

### E7-T3 - Alternative plan generation
- Priority: `P1`
- Status: `TODO`
- Description: Provide 2-3 nearby alternatives (e.g., lower move cost vs higher utility).
- Acceptance criteria:
1. At least two alternative plans generated per run.
2. Alternatives differ materially in objective tradeoffs.
3. User can set any alternative as active plan.
- Dependencies: E5-T3, E7-T1

## Epic E8 - Guided Rearrangement Workflow
Goal: reduce user effort in applying the layout.

### E8-T1 - Move-plan generation
- Priority: `P0`
- Status: `TODO`
- Description: Convert target layout into minimal practical move sequence.
- Acceptance criteria:
1. Move list generated with deterministic order.
2. Conflicts/cycles handled via temporary holding slot strategy.
3. Move count benchmarked vs naive plan.
- Dependencies: E5-T2

### E8-T2 - Step-by-step execution UI
- Priority: `P0`
- Status: `TODO`
- Description: Interactive checklist with current move and next move preview.
- Acceptance criteria:
1. User can mark step done, undo, skip.
2. State persists across app backgrounding and relaunch.
3. Completion percent and remaining time are shown.
- Dependencies: E8-T1

### E8-T3 - Resume and partial completion support
- Priority: `P1`
- Status: `TODO`
- Description: Reconcile real-world drift if user deviates mid-process.
- Acceptance criteria:
1. User can rescan current state and rebase remaining steps.
2. Completed moves preserved where valid.
3. Rebase operation completes in under 2 seconds.
- Dependencies: E8-T2, E2-T3

## Epic E9 - Privacy, Trust, and Compliance
Goal: ensure user trust and App Store-safe positioning.

### E9-T1 - Privacy dashboard
- Priority: `P0`
- Status: `TODO`
- Description: Centralized view of permissions, stored data, and controls.
- Acceptance criteria:
1. Dashboard lists all collected data classes.
2. User can revoke data sources from inside app guidance.
3. Export and delete options available.
- Dependencies: E1-T3

### E9-T2 - Delete-all and reset flows
- Priority: `P0`
- Status: `TODO`
- Description: Full local data wipe and app reset.
- Acceptance criteria:
1. One action removes all persisted user data.
2. Confirmation flow prevents accidental wipes.
3. Post-reset app returns to clean onboarding state.
- Dependencies: E1-T3

### E9-T3 - App Review compliance copy
- Priority: `P0`
- Status: `TODO`
- Description: Ensure messaging avoids claims of automatic icon rearrangement.
- Acceptance criteria:
1. In-app copy reviewed for platform-safe phrasing.
2. App Store metadata avoids prohibited claims.
3. Review checklist included in release template.
- Dependencies: none

## Epic E10 - QA, Beta, and Launch Readiness
Goal: validate quality and ship to TestFlight/App Store.

### E10-T1 - Unit/integration test suite
- Priority: `P0`
- Status: `TODO`
- Description: Cover optimizer, ingestion, and move planner paths.
- Acceptance criteria:
1. 80%+ coverage for optimizer core package.
2. Snapshot/integration tests for key screens pass.
3. Regression suite runs in CI under 10 minutes.
- Dependencies: E1-T1, E5-T1, E8-T1

### E10-T2 - Manual QA matrix
- Priority: `P1`
- Status: `TODO`
- Description: Device, profile, and edge-case matrix for exploratory testing.
- Acceptance criteria:
1. Matrix covers device sizes and handedness combinations.
2. Includes folder-heavy, widget-heavy, and low-confidence OCR cases.
3. Defect triage SLA defined for beta.
- Dependencies: E7-T1, E8-T2

### E10-T3 - TestFlight rollout plan
- Priority: `P1`
- Status: `TODO`
- Description: Beta recruitment, feedback taxonomy, and release gates.
- Acceptance criteria:
1. Tester cohorts and invite flow configured.
2. In-app feedback channels connected to issue tracker.
3. Launch gate metrics defined and signed off.
- Dependencies: E10-T1, E10-T2

## Cross-Epic Dependencies (Critical Path)
1. E1-T1 -> E1-T2 -> E1-T3
2. E2-T1 -> E2-T2 -> E2-T3
3. E3-T1/E3-T2 -> E3-T3
4. E4-T1 -> E4-T2
5. E5-T1 -> E5-T2 -> E5-T3
6. E7-T1 + E8-T1 -> E8-T2
7. E9-T1/E9-T2 + E10-T1 -> launch readiness

## Recommended Sprint Plan (8 Weeks)

### Sprint 1 (Week 1-2)
- Target tickets: E1-T1, E1-T2, E1-T3, E2-T1, E4-T1
- Exit criteria:
1. App shell stable with persistence.
2. Basic onboarding and screenshot import functional.

### Sprint 2 (Week 3-4)
- Target tickets: E2-T2, E2-T3, E3-T1, E3-T2, E5-T1
- Exit criteria:
1. Layout + usage signals captured.
2. Scoring function returns deterministic outputs.

### Sprint 3 (Week 5-6)
- Target tickets: E3-T3, E4-T2, E5-T2, E5-T3, E7-T1, E8-T1
- Exit criteria:
1. End-to-end recommendation + move plan generated.
2. Results preview and move queue available.

### Sprint 4 (Week 7-8)
- Target tickets: E8-T2, E8-T3, E7-T2, E9-T1, E9-T2, E9-T3, E10-T1, E10-T2, E10-T3
- Exit criteria:
1. Guided apply flow production-ready.
2. Privacy/compliance complete.
3. TestFlight launch candidate approved.

## MVP Gate Checklist
- [ ] Onboard -> import -> recommend -> guided apply works without crashes.
- [ ] Plan generation for typical layout under 3 minutes from cold start.
- [ ] Move count is lower than naive baseline for benchmark fixtures.
- [ ] Permission denied and low-confidence OCR paths are user-friendly.
- [ ] Delete-all reset verified.
- [ ] App copy and store metadata pass compliance review.

## Open Decisions to Resolve Before Coding Starts
1. Persistence choice finalization: `CoreData` vs `SQLite + lightweight ORM`.
2. Analytics policy: fully local logs vs opt-in remote telemetry.
3. OCR strategy for app name normalization (Apple bundle name dictionary source).
4. Initial aesthetic mode set for launch (recommend: color gradient + symmetry only).
5. Minimum iOS version target.

# Schema Migrations

## Current schema
- Schema version is stored in `PersistedEnvelope.schemaVersion`.
- Current version: `1`.
- Envelope format:

```json
{
  "schemaVersion": 1,
  "persistedAt": "2026-02-15T00:00:00Z",
  "payload": []
}
```

## Migration strategy
1. Attempt to decode current envelope format.
2. If decode fails, run domain-specific migrator.
3. Persist migrated data back in current envelope format on next write.

## Implemented migrators
- `ProfileSchemaMigrator`
  - Supports:
    - raw legacy array (no envelope)
    - envelope with `schemaVersion = 0`
  - Legacy fields mapped:
    - `dominantHand` -> `handedness`
    - default `gripMode = oneHand`
    - default `goalWeights = GoalWeights.default`

## Adding a new schema version
1. Add enum case to `SchemaVersion`.
2. Add migration type for each affected model.
3. Add fixture-based migration tests.
4. Keep backward migration support for at least one previous version.

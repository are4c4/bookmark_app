# Historical database fixtures

These fixtures preserve small, deterministic database checkpoints for migration/preservation regression tests. They contain synthetic data only and deliberately avoid real Vault paths, personal URLs, names, or media bytes.

## Retained checkpoints

- `legacyV8` — pre-workspace Bookmark/People/Photo/Saved View data. This exercises the long v8 → current migration chain, lifecycle defaults, relation-role normalization, saved-view evolution, and managed-path compatibility references.
- `objectEraV16` — the schemaVersion-16 Object-first era with additive/lazy Object Body and Relation-index tables. It preserves canonical Object identity, ordered Body blocks, serialized/indexed Relation order, and Database View configuration across restart.

The fixture SQL is intentionally stored in `historical_database_fixtures.dart` rather than generated from today's Drift schema. That makes an old checkpoint useful: later schema/model changes cannot silently rewrite history before the regression test runs.

## Adding a checkpoint

1. Add a new `HistoricalDatabaseCheckpoint` enum value and a new frozen setup function. Do not mutate an accepted old checkpoint merely to make a new migration pass.
2. Use only deterministic synthetic values and path-independent relative managed-file references.
3. Seed the contracts that actually existed at that checkpoint; do not back-port newer tables just to increase assertion count.
4. Add focused assertions in `historical_database_fixture_test.dart` for identity/lifecycle, Body, Relations, Views and media compatibility where those contracts existed.
5. Prove both first-open migration and a second already-migrated reopen. A migration defect discovered here belongs to the owning migration Issue and single-writer lease; do not change production migration semantics in the fixture PR.

These tests run through the normal Flutter test path, so migration-sensitive PRs receive the same authoritative CI coverage without a second migration runner.

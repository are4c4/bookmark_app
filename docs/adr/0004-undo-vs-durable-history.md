# ADR-0004: Local Undo is not durable History

- Status: Accepted
- Date: 2026-09-14
- Related Issues: #1064
- Related docs: `docs/product_architecture.md`, `docs/architecture.md`

## Context

The app needs both fast reversible editing and restart-safe historical recovery. Those needs look similar because both involve older state, but they have different lifetime, integrity, storage, and conflict requirements.

An editor Undo stack can keep transient commands or in-memory snapshots optimized for the current interaction session. Durable History must survive restart, preserve explicit Object/revision identity, coordinate Relation state and managed-byte retention, and fail closed when restoration conflicts with newer/corrupt state.

## Decision

Local Undo and durable History are separate contracts.

Undo is an interaction mechanism: short-lived, locally scoped, and allowed to depend on the active editor/session. Durable History is persisted, restart-safe historical evidence with explicit revision identity and restore semantics. Durable History must compose the owning Object, Relation, and managed-byte boundaries instead of treating an Undo stack as archival authority.

## Alternatives considered

### Persist the Undo stack and call it History

This reuses editor machinery, but transient commands/controllers are not a stable persistence contract and do not automatically capture cross-subsystem integrity or restart semantics.

### Build one universal event log before concrete history requirements are proven

A single event-sourced authority could be powerful, but it would redesign working persistence across Object/Relation/File subsystems and add broad complexity before the required restore contracts are known.

## Consequences / constraints

- clearing/restarting an editor may legitimately discard Undo while durable History remains intact;
- durable checkpoints use explicit Object/revision identity and immutable historical payloads rather than mutable editor state;
- Relation history/restore integrity stays behind the Relation-owned boundary; Object history must not serialize a competing edge authority;
- Image/File byte retention/deletion authority stays with storage/managed-file ownership rather than the Object history layer;
- restore is an explicit conflict-aware operation, not equivalent to pressing Undo after a restart;
- UI may present Undo and History together, but their persistence and correctness guarantees must remain distinct.

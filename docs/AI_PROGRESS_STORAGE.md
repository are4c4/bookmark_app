# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Check Primitive/Refactor ownership before changing shared storage helpers.

## Lane goal
Own the physical data-location lifecycle independently from Object/Relation product semantics so Vault/file portability and app delivery can progress in parallel.

## Primary active issues
- #242 — user-selectable Vault folders and safe create/open/switch/move lifecycle.
- #218 — installable macOS delivery/packaging validation and follow-up.
- #484/#489/#495 only where filesystem/Vault contracts are dependencies of primitive File/Image behavior.

## Owns
- Profile/Vault directory lifecycle and persisted locations.
- Vault create/open/switch/move validation.
- profile-relative/Vault-relative path portability.
- backup/restore/profile duplication and filesystem recovery.
- missing/offline storage-location handling.
- app release/install packaging and delivery plumbing.
- filesystem-level managed-storage helpers shared by primitives when not identity/product-specific.

## Boundary with Primitive lane
- Storage lane owns where/how managed bytes live and survive Vault lifecycle.
- Primitive lane owns what Image/File/Weblink Objects mean, their identity, and domain mutation rules.
- Never add a second Image/File ownership model in Storage merely for Vault support.

## Current implementation checkpoint
The existing Profile layout is already Vault-like (`database.sqlite`, profile metadata, photos, attachments), but custom persisted directory paths are not yet fully authoritative. macOS release packaging is effectively implemented and locally launch-validated; remaining work is small compared with #242.

## Initial next actions
1. Add/load regressions for stored custom Profile/Vault directory paths and legacy fallback.
2. Make custom valid directory paths authoritative without silently creating replacement empty Vaults.
3. Add read-only current Vault path + Finder reveal before create/open/switch UX.
4. Audit backup/restore and managed Image/File paths before any move semantics.
5. Coordinate shared file-backed capability requirements with Primitive lane before introducing new storage abstractions.

## Safety
- Never silently replace a missing Vault with a new empty database.
- Never delete/move source Vault data before target validation and successful reopen.
- Preserve external file references; do not silently copy/rebase them.
- Keep SQLite concurrency limitations explicit for cloud-synced folders.

## Handoff checklist
Record active Issue, branch/PR/commit, filesystem operations changed, data-safety validation, Primitive/Refactor dependencies, hotspot ownership, next actions, and stop reason.

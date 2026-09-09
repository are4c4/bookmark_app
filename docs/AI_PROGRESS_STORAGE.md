# AI Progress — Storage, Vault & Delivery Lane

> Durable Lane F handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed-storage contracts shared by primitives, preservation validation and app delivery plumbing without taking over Object/Relation/native media identity semantics.

## Architecture contract
A Vault is one local Object universe containing database state and managed files. Objects/Relations/Databases/Views remain logical data inside it.

- Objects are not owned by filesystem folders or Databases.
- Image/File Object identity belongs to D; filesystem placement/ownership belongs to F.
- Removing an Object from a Database, archiving it or trashing it must not by itself physically delete managed bytes.
- Permanent physical deletion requires explicit final lifecycle action plus proven active-Vault ownership/shared-reference safety.
- Destructive legacy Bookmark/People/Photo schema retirement requires preservation evidence after caller-zero/parity; F validates preservation but does not define semantic migration mappings.

## Completed preservation checkpoints

### #951 — Photo→Image preservation validation
The focused preservation checkpoint is completed. Its evidence proved the supported Photo→Image preservation matrix through the intended real-machine validation path. Treat that completion as evidence for the validated transition, not as blanket authority to delete historical Photo/Bookmark/People data later.

### #242 — Vault v1 real-machine validation
The focused Vault v1 real-machine validation checkpoint is completed. Create/Open/Switch/Move/Recovery validation is therefore no longer an active Lane F stop gate. Future destructive migration still requires preservation evidence appropriate to that migration and the normal single-writer/destructive-approval process.

## Current durable roadmap anchor

### #1063 — open export / portability
Backup/restore preserves an application Vault for recovery; portable export is a separate user-facing capability. Resume Lane F from live #1063 and currently open focused F Issues rather than treating completed preservation/export slices as active work.

Keep export work aligned with the Object-first portability contract: preserve stable Object identity, typed Property/Relation/Body data and managed/external byte semantics without claiming lossy Markdown/CSV projections are round-trip complete. F owns filesystem/package safety and byte inclusion policy; logical Object/Property/Relation/Body/Database/View serialization remains with the owning lanes.

## Completed focused Storage contracts

### #1128 — package path and managed-byte export boundary
The first focused F-owned #1063 slice is integrated and establishes the filesystem trust boundary without taking over logical Object/Relation/Database serialization.

- Portable package members must be clean relative forward-slash paths; absolute/drive-qualified, traversal, dot/empty-segment and backslash-ambiguous paths fail closed.
- Automatic byte inclusion requires explicit `vault-managed-copy-v1` ownership plus an existing regular non-symlink Vault-relative managed source.
- Path location alone is never managed-byte ownership authority, including for files that happen to sit inside the Vault.
- Intermediate symlink parents, symlinked managed roots, missing/offline Vaults, missing/non-file sources and escaping paths fail closed.
- Unowned absolute references remain external reference-only by default and are not silently probed, copied or rebased.
- This boundary is read-only with respect to the source Vault. Later serializers/package writers consume the validated plan instead of reimplementing containment or inferring ownership.

### #1132 — Vault restore archive preflight
The focused restore-preservation hardening is integrated. Restore now proves the complete archive namespace before mutating its target.

- Every ZIP member is validated before target deletion/creation or extraction.
- Symbolic-link entries are rejected; Bookmark Vault backup format has no supported symlink requirement.
- Empty/NUL, absolute/drive-qualified, backslash-ambiguous, traversal, dot and empty path segments fail closed.
- Exact/case-folded member aliases and file/descendant namespace conflicts fail before target mutation.
- Exactly one regular top-level `database.sqlite` is required before extraction.
- Invalid preflight input leaves an existing target untouched; extraction-stage cleanup/rollback remains best-effort without replacing the original failure.
- App-generated regular-file Vault backups remain supported, and no schema/migration/Object/Relation semantics changed.

## Current focused portability work

### #1146 — explicitly owned Image bytes under `photos/...`
D/#1141 is integrated by PR #1143 (`c7c06e27e859640899c62bcb1c0b20d12a8c869e`), so Lane F is actively implementing the downstream filesystem-planner slice in PR #1159 on `feature/portable-export-image-bytes-1146`.

The active contract is intentionally narrow:
- accept explicit `vault-managed-copy-v1` provenance only under the closed Vault managed roots `attachments/...` and `photos/...`;
- preserve existing File `attachments/...` behavior while allowing canonical managed Image `photos/...` bytes;
- validate the selected managed root, intermediate parents and source as real non-symlink filesystem entries;
- prove the resolved source remains inside the selected managed root;
- keep unowned relative references fail-closed and unowned absolute references external-reference-only;
- keep path traversal, absolute/drive-qualified, backslash-ambiguous and unsupported-root input fail-closed;
- remain read-only with respect to the source Vault;
- do not introduce Image identity logic, historical ownership backfill, logical Object serialization, package manifests or byte relocation.

Focused regressions cover managed `photos/...` success, unowned photo rejection, missing/offline/non-file photo sources, photo nested/source/root symlinks, preserved `attachments/...` behavior and unchanged external-reference semantics. GitHub Actions is authoritative for format/Analyze/full-test/merge-gate validation.

## Integrated foundation that remains authoritative
- configurable user-selected Vault roots;
- create/open/switch/rename/duplicate/remove-from-list lifecycle;
- fail-closed missing/offline Vault behavior;
- safe Move with checkpoint/copy/validate/registry/reopen/rollback sequence;
- Vault-relative managed paths and compatibility rebasing rules;
- external absolute references preserved rather than silently copied/rebased/deleted;
- backup/restore/duplication portability;
- managed-file copy/rollback and ownership-gated physical delete boundaries;
- read-only Vault preservation manifest/compare tooling and documented validation procedure;
- release packaging/basic real-Mac launch path.

## Object-first migration implications
Current Bookmark/People retirement work must not delete historical data merely because Weblink/Person generic UX becomes normal. When A/B/C/D/G eventually prove replacement parity and caller-zero, any destructive schema/data cleanup is a separate single-writer migration with fresh preservation evidence appropriate to that retirement. Completion of #242/#951 does not waive that requirement.

F should not:
- decide how conflicting legacy Bookmark rows merge onto one Weblink;
- redesign Person identity/groups/roles;
- implement Tag hierarchy;
- infer Image/File Object identity or ownership from paths;
- create a parallel sync protocol from cloud-synced folders;
- define canonical graph serialization for another lane merely to make #1063 progress;
- create a package writer that invents missing logical serialization/reconstruction semantics.

## Cross-lane boundaries
- **A/B/C:** define semantic replacement/parity and, for #1063, logical serialization/reconstruction contracts for canonical Object/Property/Relation/Body/Database/View data they own.
- **D:** owns native Image/File identity and producer-side provenance from trusted primitive workflows. F consumes explicit provenance for filesystem/package eligibility but must not manufacture it.
- **G:** caller-zero code retirement; F verifies preservation before actual schema/data destruction.
- **E:** Search may consume derived file content but storage unavailability must fail safely.

## Validation
Repository tests and tools are authoritative for repository-owned behavior; use real-machine validation again whenever a focused F Issue or future destructive migration requires physical filesystem/platform evidence that CI cannot prove. For Storage-owned portability slices, deterministic tests must prove path containment, explicit ownership and source-Vault non-mutation. Record concrete failures as focused owner-lane Issues rather than speculatively changing Storage semantics.

## Resume sequence
1. re-read latest `main`, live F-focused Issues/PRs, current CI, shared-hotspot ownership and migration-writer state;
2. while #1146 / PR #1159 is active, finish its filesystem-planner acceptance criteria, fix only failures caused by the focused change and integrate after authoritative green validation;
3. after #1146 integrates, re-audit #1063 for another explicit F-owned filesystem/package slice whose logical prerequisites already exist;
4. do not invent a canonical graph serializer, manifest or package writer before owning-lane logical contracts are explicitly available;
5. use preservation tooling and real-machine evidence when an active Issue or destructive-retirement gate specifically requires it;
6. route concrete semantic defects to A/B/C/D/G as appropriate;
7. keep destructive Bookmark/People/Photo schema retirement in a separate explicit single-writer migration with preservation evidence and required approval.

Lane F inherits the shared **Lane continuation and resume/stop contract** in `AGENTS.md`. A real-machine requirement may legitimately produce `external-infra` for a specific active Issue, and an explicit cross-lane prerequisite may produce `dependency`, but only after the final live resume audit finds no other independent safe F work.

Work in progress: #1146 / PR #1159 — validate and integrate the explicitly-owned `photos/...` portable-export filesystem boundary.

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
Backup/restore preserves an application Vault for recovery; portable export is a separate user-facing capability. Resume Lane F from live #1063 and any newly created focused F Issues rather than treating completed filesystem slices as active work.

Keep export work aligned with the Object-first portability contract: preserve stable Object identity, typed Property/Relation/Body data and managed/external byte semantics without claiming lossy Markdown/CSV projections are round-trip complete. F owns filesystem/package safety and byte inclusion policy; logical Object/Property/Relation/Body/Database/View serialization remains with the owning lanes.

The remaining #1063 umbrella work is not permission for F to invent a canonical graph serializer, manifest or import/reconstruction contract. A later package writer becomes actionable only when the owning lanes expose an explicit lossless logical serialization/reconstruction contract or a separately focused F packaging contract defines what it consumes.

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
The focused restore-preservation hardening is integrated. Restore proves the complete archive namespace before mutating its target.

- Every ZIP member is validated before target deletion/creation or extraction.
- Symbolic-link entries are rejected; Bookmark Vault backup format has no supported symlink requirement.
- Empty/NUL, absolute/drive-qualified, backslash-ambiguous, traversal, dot and empty path segments fail closed.
- Exact/case-folded member aliases and file/descendant namespace conflicts fail before target mutation.
- Exactly one regular top-level `database.sqlite` is required before extraction.
- Invalid preflight input leaves an existing target untouched; extraction-stage cleanup/rollback remains best-effort without replacing the original failure.
- App-generated regular-file Vault backups remain supported, and no schema/migration/Object/Relation semantics changed.

### #1171 — Vault restore content extraction fail-closed
The restore content-integrity follow-up is integrated with #1132's namespace contract preserved.

- Bookmark restore no longer delegates regular-file extraction to `archive 4.2.0`'s `extractFileToDisk()` helper, whose regular-file path catches and discards `ArchiveFile.writeContent()` failures.
- The complete archive namespace is still validated before any existing restore target is deleted or recreated.
- The archive decoded for the extraction pass is fully revalidated again before the first extracted byte is written, so case-fold aliases, file/descendant conflicts, symlinks, unsafe member names and the top-level `database.sqlite` requirement apply to the bytes actually extracted rather than only an earlier file snapshot.
- Every extraction destination is resolved under the restore root and fails closed if containment is not preserved.
- Regular-file content is written through `ArchiveFile.writeContent()` directly so decompression/content/output failures propagate instead of becoming false restore success.
- Output close remains best-effort when a write/decompression failure already exists, so cleanup errors do not replace the original failure explaining why restore failed.
- Any extraction-stage failure enters the existing partial-target cleanup path and rethrows the original failure; preflight-invalid input still leaves a pre-existing target untouched.
- A deterministic regression keeps ZIP namespace metadata valid while corrupting one raw DEFLATE payload to reserved BTYPE=3, proving preflight succeeds, content extraction fails, and the partial target is removed.
- Existing app-generated backup restore continues to preserve `database.sqlite`, `profile.json`, `photos/...` and `attachments/...` bytes.
- No schemaVersion, migration, Object/Relation semantics, Image/File identity, backup-format redesign or destructive active-Vault behavior changed.

The latest implementation head before this durable handoff update was green for changed-Dart format, Analyze/guards, all four Flutter Test shards on first pass, test-health, handoff/migration/settings audits and authoritative `merge-gate`.

### #1179 — Vault complete-backup destination preservation
The complete-backup output-boundary hardening is integrated by PR #1181 (`e3e9152e5d629e080d723f5d59088ed38f34389a`). Backup is now read-only with respect to the source Vault even when the selected destination pathname crosses filesystem aliases.

- The source Vault and selected destination parent are resolved before WAL checkpoint/archive output; direct/nested Vault destinations and outside-looking parent symlinks resolving into the Vault fail closed.
- An existing destination symlink whose target resolves inside the source Vault is rejected before archive creation.
- The validated real outside parent becomes the actual output directory, so later archive staging does not traverse an untrusted alias again.
- ZIP bytes are written only to a freshly created staging file in that validated outside directory, never through the pre-existing selected destination entity.
- After successful ZIP creation, only the selected directory entry is replaced. Existing regular-file hard links and symbolic links are therefore not followed for writes.
- Supported-platform regressions prove that an outside destination hard-linked to a Vault file can be replaced without changing the source-Vault bytes, and an outside symlink to an outside target can be replaced without changing the target bytes.
- Cancellation still returns before checkpoint/output, invalid destinations leave the source Vault unchanged, and ordinary external complete backup remains supported.
- Existing ZIP format/restore behavior, Object/Relation/Image/File identity, schemaVersion and migrations remain unchanged.
- The latest-main-synchronized implementation head passed changed-Dart format, Analyze/guards, all four Flutter Test shards on first pass, test-health, handoff/migration/settings audits and authoritative `merge-gate` before auto-merge.

### #1146 — explicitly owned Image bytes under `photos/...`
The downstream Image-byte filesystem slice is integrated by PR #1159 (`2b5ae87f1b65edf67c1ca02b4ab39d78b33a1f0c`) after D/#1141 established explicit Image ownership provenance.

- `PortableExportFilePlanner` accepts explicit `vault-managed-copy-v1` provenance only under the closed Vault managed roots `attachments/...` and `photos/...`.
- Existing File `attachments/...` behavior is preserved while canonical managed Image `photos/...` bytes can now be planned for inclusion.
- The selected managed root, every intermediate parent and the source are validated as real non-symlink filesystem entries.
- The resolved source must remain inside the selected managed root.
- Unowned relative references remain fail-closed; unowned absolute references remain external-reference-only and are not probed/copied.
- Traversal, absolute/drive-qualified, backslash-ambiguous and unsupported-root input remains fail-closed.
- Planning remains read-only with respect to source Vault data and does not infer Image/File identity or ownership from path location.
- No historical ownership backfill, byte relocation, logical Object serializer, package manifest, schema/migration or destructive filesystem behavior was introduced.

Validation for the latest-main-synchronized implementation head was green for changed-Dart format, Analyze/guards, all four Flutter Test shards, test-health, handoff/migration/settings audits and authoritative `merge-gate` before squash integration.

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
- **A/#1064:** durable history is still A-owned. If its retention/restore contract later splits managed-byte retention/GC to F, wait for a focused F Issue before implementing it.

## Validation
Repository tests and tools are authoritative for repository-owned behavior; use real-machine validation again whenever a focused F Issue or future destructive migration requires physical filesystem/platform evidence that CI cannot prove. For Storage-owned portability slices, deterministic tests must prove path containment, explicit ownership and source-Vault non-mutation. Record concrete failures as focused owner-lane Issues rather than speculatively changing Storage semantics.

## Resume sequence
1. re-read latest `main`, live F-focused Issues/PRs, current CI, shared-hotspot ownership and migration-writer state;
2. re-read #1063 and search for a newly split focused F filesystem/package contract whose logical prerequisites already exist;
3. re-check #1064 only for a newly created F-owned managed-byte retention/GC slice; do not take over the A-owned history model;
4. re-check any destructive Bookmark/People/Photo retirement work for a specifically requested F preservation-validation slice before schema/data removal;
5. otherwise do not invent a canonical graph serializer, manifest, package writer, sync protocol, managed-byte history model or destructive cleanup merely to keep Lane F active;
6. route concrete semantic defects to A/B/C/D/G as appropriate.

Lane F inherits the shared **Lane continuation and resume/stop contract** in `AGENTS.md`. A real-machine requirement may legitimately produce `external-infra`, a genuine prerequisite may produce `dependency`, and no concrete work after the final live audit may produce `idle-no-work`.

Final resume audit after the #1179 integration finds #1063 as the active F-primary roadmap anchor. #1179 is completed, while #56/#1039 are cross-lane umbrellas that mention F preservation responsibilities rather than focused F implementation work. #1063 still has no newly split focused F package-writer/filesystem slice whose logical prerequisites authorize independent implementation, and no additional current-main Storage/Vault correctness defect was demonstrated in this audit.

Stop reason: idle-no-work after #1179 integration — resume when #1063 gains an explicit focused F filesystem/package contract with owning-lane logical prerequisites, #1064 splits a managed-byte retention/GC Issue to F, a destructive retirement requests focused preservation validation, or a concrete current-main Storage/Vault correctness defect appears.

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
- Destructive legacy Bookmark/People/Photo schema retirement requires fresh preservation evidence after caller-zero/parity; F validates preservation but does not define semantic migration mappings.
- Backup/restore is application Vault recovery. Portable export is a separate open/inspectable takeout contract.
- F owns package/filesystem safety and byte inclusion policy. A/B/C/D own the logical serialization semantics of the Object/Property/Relation/Body/Database/View/native-primitive data they define.
- Path location alone is never managed-byte ownership authority.

## Completed preservation / filesystem checkpoints

### #242 — Vault v1 real-machine validation
Create/Open/Switch/Move/Recovery validation is completed. This proves the supported Vault lifecycle checkpoint only; it does not authorize later destructive schema/data retirement without migration-specific preservation evidence.

### #951 — Photo→Image preservation validation
The supported Photo→Image preservation matrix was validated through the intended real-machine path. This is not blanket authority to delete historical Photo/Bookmark/People data later.

### #1128 — portable export package path / byte trust boundary
Portable export planning now has a closed filesystem trust boundary:

- package members must be clean relative forward-slash paths;
- automatic byte inclusion requires explicit `vault-managed-copy-v1` ownership plus an existing regular non-symlink Vault-relative managed source;
- traversal, absolute/drive-qualified, dot/empty-segment and backslash-ambiguous paths fail closed;
- symlinked managed roots/intermediate parents/sources, missing/offline Vaults and escaping paths fail closed;
- unowned absolute references remain external-reference only and are not silently probed/copied/rebased;
- planning is read-only with respect to the source Vault.

### #1132 / #1171 — restore namespace and content extraction fail-closed
Vault restore validates the complete ZIP namespace before target mutation and validates again for the extraction pass. Unsafe names, symlinks, namespace collisions/conflicts and invalid top-level database structure fail closed. Regular-file content extraction propagates decompression/write failures instead of reporting false success, and partial targets are cleaned up while the original failure is preserved.

### #1179 — complete-backup destination preservation
Complete backup proves the selected output destination is outside the source Vault before checkpoint/archive output and writes through a fresh staging file in the validated outside directory. Symlink/hard-link aliases cannot cause source-Vault bytes to be overwritten. Cancellation and invalid destinations remain source-read-only.

### #1146 — explicitly owned Image bytes under `photos/...`
`PortableExportFilePlanner` accepts explicit `vault-managed-copy-v1` provenance only under the closed managed roots `attachments/...` and `photos/...`. Existing File behavior remains intact while canonical managed Image bytes can be included without inferring ownership from location.

### #1238 — portable-backup import preserves legacy managed absolute paths
Integrated by PR #1245 / merge `279d12783a34617ed0a03fa467d30c79b2c01e9a`.

Backup import now consumes the actual portable `profile.json` contract instead of passing it through registry-only `DatabaseProfile.fromJson()`.

- portable metadata is validated using the current fields (`formatVersion`, stable Vault `id`, `name`, `database`, `photos`, `attachments`);
- portable metadata does **not** become filesystem-location authority;
- the stable Vault id may identify a source root only by matching exactly one already-registered Vault;
- only that independently proven registered directory can authorize legacy absolute-path rebasing;
- without a registered matching source, import does not guess a root from path text;
- only source-contained paths whose copied target actually exists are rebased to portable relative paths;
- already-relative managed paths remain valid;
- absolute external references remain external;
- malformed/ambiguous metadata cannot authorize rewriting;
- backup ZIP/preflight/extraction behavior is unchanged;
- no schemaVersion/migration/Object/Relation semantics changed.

Focused regressions cover the registered-source happy path, no-source fail-closed behavior, malformed metadata, relative managed paths and external absolute references. The latest-main-synchronized implementation passed changed-Dart format, Analyze/guards, all four Flutter Test shards, test-health, handoff/migration/settings audits and authoritative `merge-gate` before squash integration.

## Integrated foundation that remains authoritative
- configurable user-selected Vault roots;
- create/open/switch/rename/duplicate/remove-from-list lifecycle;
- fail-closed missing/offline Vault behavior;
- safe Move with checkpoint/copy/validate/registry/reopen/rollback sequence;
- Vault-relative managed paths plus compatibility rebasing rules;
- external absolute references preserved rather than silently copied/rebased/deleted;
- backup/restore/duplication portability;
- managed-file copy/rollback and ownership-gated physical delete boundaries;
- read-only Vault preservation manifest/compare tooling and documented validation procedure;
- release packaging/basic real-Mac launch path.

## Current roadmap anchors

### #1063 — open export / portability
#1063 remains the active F-primary umbrella. It is **not** permission for F to invent a canonical graph serializer, manifest, reconstruction contract or package writer before the owning logical lanes expose an explicit lossless contract or a separately focused F packaging Issue defines the exact contract it consumes.

F may independently take a newly split #1063 child only when it is a concrete filesystem/package responsibility whose logical prerequisites are already explicit. Continue to keep backup/restore distinct from portable export and preserve stable identity, typed graph semantics and managed/external byte distinctions without claiming Markdown/CSV projections are round-trip complete.

### #1064 / #1268 — durable history managed-byte retention
Durable Object history remains A-owned, but #1064 has now split the managed Image/File byte-retention and GC safety boundary to focused F Issue #1268.

#1268 is the next demonstrated F implementation slice, but it explicitly depends on A/#1260. Do not implement it until #1260 is integrated and its logical checkpoint contract is the current-main source of truth.

When that dependency is satisfied, start with the contract-first, non-migration slice described by #1268:

- distinguish logical historical references from an actual retained/restorable managed-byte guarantee;
- keep current-state, retained-history and backup/export preservation claims distinct enough that releasing one claim never implies immediate physical deletion;
- require global ownership/reference safety before any future GC decision can permit deletion;
- keep external absolute references external and outside app-owned deletion authority;
- preserve existing Vault move/backup/restore and explicit-provenance contracts;
- fail closed/retain on ambiguity;
- prefer a focused policy/decision boundary plus deterministic tests before any persisted retention ledger or physical deletion implementation.

Do not let F redefine A-owned checkpoint/Body/Property semantics, Relation replay, history timeline UX or history persistence merely to implement #1268.

### Legacy Bookmark / People / Photo retirement
Normal-use convergence and caller-zero work belongs to A/B/C/D/G. F participates before destructive schema/data retirement only when a focused preservation-validation requirement is explicitly created. Completion of #242/#951 does not waive that requirement.

## Cross-lane boundaries
- **A/B/C:** own semantic Object/Property/Relation/Body/Database/View replacement and logical portability/reconstruction contracts.
- **D:** owns native Image/File identity and producer-side provenance. F consumes explicit provenance for filesystem/package eligibility but never manufactures it from a path.
- **E:** owns Search/index behavior; storage unavailability must fail safely.
- **G:** owns caller-zero code retirement and refactor; destructive data/schema removal still requires preservation evidence and the normal migration/destructive-approval process.

F should not:
- decide conflicting legacy Bookmark merge semantics;
- redesign Person identity/groups/roles;
- implement Tag hierarchy;
- infer Image/File identity or ownership from paths;
- create a cloud-folder sync protocol;
- define another lane's canonical graph serialization;
- create a package writer that invents missing logical reconstruction semantics;
- create a managed-byte history model outside #1268's explicit storage-owned boundary;
- perform destructive cleanup merely because a legacy UI/runtime path is caller-zero.

## Validation expectations
Repository tests/tools are authoritative for repository-owned behavior. Use real-machine validation whenever a focused F Issue or destructive migration requires filesystem/platform evidence CI cannot prove. Storage-owned portability/preservation slices should deterministically prove containment, explicit ownership, fail-closed ambiguity and source-Vault non-mutation where applicable.

## Resume sequence
1. Re-read latest `main`, `AGENTS.md`, `docs/product_architecture.md`, `docs/AI_PROGRESS.md`, this handoff, live F-focused Issues/PRs, CI, shared-hotspot ownership and migration-writer state.
2. Re-read live #1260 and #1268 first. If #1260 is integrated, #1268 is still open and no other owner exists, take the smallest contract-first #1268 slice from latest main without schema/migration or physical deletion.
3. If #1260 is not integrated, check for another independent concrete F obligation rather than modifying A's branch or weakening the dependency.
4. Re-read #1063 and take only a newly split focused F filesystem/package contract whose logical prerequisites already exist.
5. Re-check destructive Bookmark/People/Photo retirement only for a specifically requested F preservation-validation slice before schema/data removal.
6. If a concrete current-main Storage/Vault correctness defect is demonstrated, create/reuse the smallest focused F Issue and fix only that defect.
7. Otherwise do not invent a serializer, package format, sync protocol, retention ledger, physical GC or destructive cleanup merely to keep Lane F active.

## Current durable stop
Final live audit after #1268 was split found no active #1268 PR/branch and no other independent focused F implementation slice. #1268 is the next demonstrated F work, but its explicit prerequisite #1260 is not yet integrated. #1063 remains umbrella-only, no destructive retirement currently requests focused F preservation validation, and no additional current-main Storage/Vault correctness defect was demonstrated.

Stop reason: dependency — #1268 is the next focused F implementation slice and cannot start until A/#1260 is integrated; resume by re-reading live #1260/#1268, current main and F ownership before taking the contract-first non-migration slice.

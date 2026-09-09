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
Backup/restore preserves an application Vault for recovery; portable export is a separate user-facing capability. Resume Lane F from live #1063 and other currently open F Issues rather than treating completed #242/#951 as active work.

Keep export work aligned with the Object-first portability contract: preserve stable Object identity, typed Property/Relation/Body data and managed/external byte semantics without claiming lossy Markdown/CSV projections are round-trip complete.

### #1128 — package path and managed-byte export boundary
The first focused F-owned #1063 slice establishes the filesystem trust boundary without taking over logical Object/Relation/Database serialization.

- Portable package members must be clean relative forward-slash paths; absolute/drive-qualified, traversal, dot/empty-segment and backslash-ambiguous paths fail closed.
- Automatic byte inclusion requires explicit `vault-managed-copy-v1` ownership plus an existing regular non-symlink Vault-relative `attachments/...` source.
- Path location alone is never managed-byte ownership authority, including for files that happen to sit inside the Vault.
- Intermediate symlink parents, symlinked `attachments`, missing/offline Vaults, missing/non-file sources and escaping paths fail closed.
- Unowned absolute references remain external reference-only by default and are not silently probed, copied or rebased.
- This boundary is read-only with respect to the source Vault. Later serializers/package writers consume the validated plan instead of reimplementing containment or inferring ownership.

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
- infer Image/File Object identity from paths;
- create a parallel sync protocol from cloud-synced folders;
- define canonical graph serialization for another lane merely to make #1063 progress.

## Cross-lane boundaries
- **A/B/C/D:** define semantic replacement/parity and, for #1063, logical serialization/reconstruction contracts for the canonical data they own.
- **D:** native Image/File identity and product semantics; F owns bytes/paths/ownership only.
- **G:** caller-zero code retirement; F verifies preservation before actual schema/data destruction.
- **E:** Search may consume derived file content but storage unavailability must fail safely.

## Validation
Repository tests and tools are authoritative for repository-owned behavior; use real-machine validation again whenever a focused F Issue or future destructive migration requires physical filesystem/platform evidence that CI cannot prove. For Storage-owned portability slices, deterministic tests must prove path containment, explicit ownership and source-Vault non-mutation. Record concrete failures as focused owner-lane Issues rather than speculatively changing Storage semantics.

## Resume sequence
1. re-read live F-focused Issues and current product state;
2. if #1128 is active, finish its package path/managed-byte acceptance criteria without broadening into logical serializers;
3. otherwise prioritize #1063/open portability work when it remains open and unowned;
4. check for other independent Vault/storage/export/delivery obligations before declaring Lane F blocked or idle;
5. use preservation tooling and real-machine evidence when an active Issue or destructive-retirement gate specifically requires it;
6. route concrete semantic defects to A/B/C/D/G as appropriate;
7. keep destructive Bookmark/People/Photo schema retirement in a separate explicit single-writer migration with preservation evidence and required approval.

Lane F inherits the shared **Lane continuation and resume/stop contract** in `AGENTS.md`. A real-machine requirement may legitimately produce `external-infra` for a specific active Issue, but completed #242/#951 are not themselves current stop reasons. Re-read live Issues first and continue independent #1063 or other F work whenever available.

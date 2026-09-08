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

## Active focused gates

### #951 — Photo→Image final preservation validation
Run the real-macOS preservation matrix proving existing legacy Photos, canonical Images, Bookmark covers/attachments, Person profile imagery and external references survive restart and Vault lifecycle operations.

### #242 — Vault v1 final real-machine validation
Production implementation is established. Remaining close gate is real-macOS Create/Open/Switch/Move/Recovery validation, coordinated with #951 where possible.

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
Current Bookmark/People retirement work must not delete historical data merely because Weblink/Person generic UX becomes normal. When A/B/C/D/G eventually prove replacement parity and caller-zero, any destructive schema/data cleanup is a separate single-writer migration with F preservation validation.

F should not:
- decide how conflicting legacy Bookmark rows merge onto one Weblink;
- redesign Person identity/groups/roles;
- implement Tag hierarchy;
- infer Image/File Object identity from paths;
- create a parallel sync protocol from cloud-synced folders.

## Cross-lane boundaries
- **A/B/C/D:** define semantic replacement/parity before F validates destructive retirement safety.
- **D:** native Image/File identity and product semantics; F owns bytes/paths/ownership only.
- **G:** caller-zero code retirement; F verifies preservation before actual schema/data destruction.
- **E:** Search may consume derived file content but storage unavailability must fail safely.

## Validation
Real-machine validation is still required for #951/#242; repository tests/tools cannot replace it. Record concrete failures as focused owner-lane Issues rather than speculatively changing Storage semantics.

## Resume sequence
1. re-read live #951/#242 and current product state;
2. use the preservation procedure/tooling to record before/after evidence;
3. execute Create/Open/Switch/Move/Recovery and image/profile/cover/external-reference matrix on real macOS;
4. route concrete semantic defects to A/B/C/D/G as appropriate;
5. update #951/#242 and this handoff with results;
6. do not perform destructive schema retirement inside the validation issues.
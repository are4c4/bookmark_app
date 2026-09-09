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
- Vault backup/restore is an application recovery contract; portable export is a separate open, inspectable extraction contract.

## Completed preservation/Vault gates

### #951 — Photo→Image final preservation validation
Closed as completed after the real-macOS preservation work. The durable rule remains: destructive legacy retirement must preserve canonical/legacy media, external references and Vault lifecycle behavior; any later destructive migration requires its own preservation evidence.

### #242 — Vault v1
Closed as completed after the final real-machine validation. User-selectable Vault lifecycle, safe Move/recovery and existing managed/external path behavior remain established contracts rather than open implementation work.

## Active portability roadmap

### #1063 — open export / portability
Portable export is now the main independent F roadmap item. F owns the package/filesystem and managed/external-byte contract; logical Object/Property/Body/Relation/Database/View serialization stays with the lanes that own those semantics.

Required direction:
- canonical lossless data must remain distinguishable from intentionally lossy Markdown/CSV projections;
- managed bytes require explicit ownership/provenance before automatic inclusion;
- external references stay external unless a future explicit export mode requests byte inclusion;
- package paths must be relative and fail closed on traversal/ambiguity;
- export must not mutate or rebase the source Vault.

### #1128 — package path + managed-byte boundary
First focused F-owned slice of #1063. Establish one fail-closed package-relative path policy and immutable file plan:
- only explicit `vault-managed-copy-v1` ownership may authorize automatic inclusion of a Vault-relative `attachments/...` regular file;
- path location alone is never byte-ownership authority;
- symlink/missing/offline/escaping managed sources fail closed;
- unowned absolute paths remain external reference-only by default;
- unowned relative paths and unknown ownership values are not guessed.

This slice intentionally does not choose the final graph JSON schema, Markdown/CSV rules, ZIP writer, UI or import semantics.

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
- create a parallel sync protocol from cloud-synced folders;
- define canonical graph serialization for another lane merely to make #1063 progress.

## Cross-lane boundaries
- **A/B/C/D:** define semantic serialization/reconstruction contracts for the canonical data they own when #1063 splits those slices.
- **D:** native Image/File identity and product semantics; F owns bytes/paths/ownership only.
- **G:** caller-zero code retirement and architecture health; F verifies preservation before actual schema/data destruction.
- **E:** Search may consume derived file content but storage unavailability must fail safely.

## Validation
For Storage-owned portability slices, focused filesystem tests must prove containment, ownership and non-mutation behavior. GitHub CI is authoritative when local Flutter execution is unavailable. Real-machine validation remains appropriate for OS/picker/release behavior but should not substitute for deterministic path/ownership regressions.

## Resume sequence
1. re-read live #1063 and any focused F child Issue, plus current open PR ownership;
2. if #1128 is still active, continue its package path/managed-byte acceptance criteria without broadening into logical serialization;
3. after a focused slice integrates, re-audit #1063 for the next independent F-owned filesystem/package obligation;
4. if the next step depends on A/B/C/D serialization contracts, split/sequence it rather than implementing their semantics in F;
5. preserve the backup/restore versus open-export distinction and source-Vault non-mutation rule;
6. do not invent speculative Storage abstractions merely to avoid an idle lane.

Lane F inherits the shared **Lane continuation and resume/stop contract** in `AGENTS.md`.

# AI Progress — Storage, Vault & Delivery Lane

> Durable Lane F handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical implementation detail remains in git/Issue/PR history.

## Lane goal

Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed-storage contracts, preservation validation and app delivery plumbing without taking over Object/Relation/native media identity semantics.

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

## Completed F checkpoints

### Vault / filesystem preservation

- **#242 — Vault v1 real-machine validation:** supported Create/Open/Switch/Move/Recovery lifecycle validated.
- **#951 — Photo→Image preservation:** supported preservation matrix validated; this is not blanket permission for later destructive retirement.
- **#1128 — portable package path / byte trust boundary:** package members require safe relative paths and explicit managed ownership; traversal, symlink ambiguity, missing ownership and external absolute references fail closed.
- **#1132 / #1171 — restore safety:** complete ZIP namespace validation, fail-closed extraction and cleanup of partial targets.
- **#1179 — backup destination preservation:** complete backup proves the output is outside the source Vault before mutation and stages safely.
- **#1146 — managed Image bytes:** explicit `vault-managed-copy-v1` provenance extends managed export eligibility to canonical Image bytes without inferring ownership from path location.
- **#1238 — portable-backup legacy path preservation:** PR #1245 / merge `279d12783a34617ed0a03fa467d30c79b2c01e9a`; stable registered Vault identity, not path text, authorizes safe absolute→relative rebasing.
- **#1268 — durable-history managed-byte retention / GC safety:** PR #1282 / merge `8b5d8f2860bbcf4371eeae99d24ec95a910c6029`; current state, retained history and preservation claims independently block GC. This is a policy contract only, not a persisted ledger or physical delete implementation.

### Delivery

#### #1335 — packaged build provenance / installed-build identity

Integrated by PR #1341 / merge `492390f49fa664991b97a471fe86312e919ff307`.

- macOS packaging derives semantic version/build, Git HEAD and clean/dirty source state before building;
- provenance is injected at compile time; the installed app does not inspect a source checkout;
- Settings exposes version/build/commit/source state and a copy affordance;
- generated DMG naming carries source provenance;
- package failure is explicit when required Git metadata is unavailable.

This did not add signing/notarization, automatic updates or release channels.

#### #1362 — repeatable RC/stable and rollback workflow

Integrated by PR #1378 / merge `187b7de7afd9e64929c01b06ebe71b36661d6503`.

- repository-owned `development` / `rc` / `stable` channels are explicit;
- release dispatch selects an exact full source SHA already integrated into `main`;
- publication requires authoritative `merge-gate` validation for that source;
- RC/stable identities are immutable and stable requires a prior matching RC;
- `tool/package_macos.sh` remains the single package authority;
- DMG verification, checksum, release provenance and schema-version evidence are retained;
- app rollback means reinstalling an older compatible package, never downgrading/re-writing Vault data;
- newer unsupported Vault schema fails closed before downgrade behavior.

No automatic updater, signing/notarization or App Store pipeline was added.

#### #1381 — release dispatch SHA shell-source boundary

Integrated by PR #1386 / merge `c68eff2a128cb0055bcd0fee7874537dc32c97b5`.

- free-form `workflow_dispatch` `source_sha` now reaches Bash through `env.REQUESTED_SOURCE_SHA` rather than direct expression interpolation in `run:` source;
- Bash validates the exact 40-character hexadecimal form before Git/GitHub use;
- the existing selected-HEAD, main-ancestry, authoritative-CI, immutable-release and stable-after-RC invariants remain unchanged;
- focused regression scans every workflow `run:` block and rejects direct `${{ inputs.source_sha }}` shell-source interpolation.

Final latest-main candidate passed coordination/workflow guards, Analyze, all four Flutter Test shards, test-health, Repository Settings / Migration Lease / Handoff audits and authoritative `merge-gate`. Ordinary PR `build-macos-release` remained intentionally skipped because the change hardens workflow source handling rather than publishing a release.

### #1358 — privacy-safe support diagnostics

Integrated by PR #1384 / merge `dfb2ce42778a6bc499ed7f64e3c34b6c8092b4d0`.

The app now has a local, user-invoked support-diagnostics boundary instead of requiring screenshots or exposing Vault contents.

- deterministic support JSON includes exact build provenance, runtime/platform context, application schema version and only a Vault-present boolean for Vault state;
- every exported diagnostic field has an explicit privacy class and fixed reason code;
- provider IDs, keys, reason codes and string values use fixed diagnostic tokens so arbitrary user-authored strings cannot be relabeled as technical metadata;
- provider failure is isolated as unavailable instead of poisoning the whole bundle;
- unsafe privacy classes, malformed providers, duplicate fields and arbitrary strings fail closed;
- `DiagnosticEventBuffer` is local/in-memory and bounded; it retains fixed category/severity/code tokens only, never free-form exception messages;
- Settings exposes `サポート情報` / `診断情報をコピー` and states the default exclusions;
- support-copy and Settings-originated Vault lifecycle failures record fixed diagnostic codes only.

`docs/SUPPORT_DIAGNOSTICS.md` is the privacy contract. Default diagnostics exclude Object titles, Body text, captured URLs/domains, raw absolute paths, file names/content, secrets/tokens/cookies, full databases/Vault files and raw exception text. No external telemetry, upload, persisted log store, migration or user-content mutation was added.

The latest-main candidate passed coordination/shared-hotspot guards, changed-Dart format, Analyze, all four Flutter Test shards, test-health, Repository Settings / Migration Lease / Handoff audits and authoritative `merge-gate` before squash integration.

## Integrated foundation that remains authoritative

- configurable user-selected Vault roots;
- create/open/switch/rename/duplicate/remove-from-list lifecycle;
- fail-closed missing/offline Vault behavior;
- safe Move with checkpoint/copy/validate/registry/reopen/rollback sequence;
- Vault-relative managed paths plus compatibility rebasing rules;
- external absolute references preserved rather than silently copied/rebased/deleted;
- backup/restore/duplication portability;
- managed-file copy/rollback and ownership-gated physical-delete boundaries;
- explicit managed-byte history retention/restoreability/GC-precondition contract without deletion-by-inference;
- read-only preservation validation tooling;
- self-identifying packages and installed-build diagnostics;
- repository-owned development/RC/stable release contract with checksum/provenance evidence and fail-closed rollback compatibility;
- privacy-safe local support diagnostics with bounded structured events;
- release dispatch input treated as data rather than shell source.

## Current roadmap anchors

### #1063 — open export / portability

#1063 remains the F-primary umbrella, but it is **not** permission for F to invent a canonical graph serializer, manifest, reconstruction contract or package writer before the owning logical lanes expose an explicit lossless contract or a separately focused F packaging Issue defines the exact contract it consumes.

F may take a newly split #1063 child only when it is a concrete filesystem/package responsibility whose logical prerequisites are already explicit. Backup/restore remains distinct from portable export; Markdown/CSV projections are not automatically round-trip complete.

### #1064 — durable history

Durable Object history remains A-owned, with Relation-specific restore integrity owned by B. F-owned managed-byte retention/GC safety is established by completed #1268. Do not persist a retention ledger, wire physical GC or claim stronger restoreability until a new focused F Issue defines the exact Storage responsibility and dependencies.

### Legacy Bookmark / People / Photo retirement

Normal-use convergence and caller-zero work belongs to A/B/C/D/G. F participates before destructive schema/data retirement only when a focused preservation-validation requirement is explicitly created. Earlier preservation checkpoints do not waive fresh evidence for a later destructive migration.

## Cross-lane boundaries

- **A/B/C:** semantic Object/Property/Relation/Body/Database/View replacement and logical portability/reconstruction contracts.
- **D:** native Image/File identity and producer-side provenance. F consumes explicit provenance but never manufactures it from a path.
- **E:** Search/index behavior; storage unavailability must fail safely.
- **G:** caller-zero code retirement/refactor and cross-cutting audit infrastructure; destructive data/schema removal still requires F preservation evidence where explicitly routed.

F should not:

- decide conflicting legacy Bookmark merge semantics;
- redesign Person identity/groups/roles or Tag hierarchy;
- infer Image/File identity or ownership from paths;
- create a cloud-folder sync protocol;
- define another lane's canonical graph serialization;
- create a package writer that invents missing logical reconstruction semantics;
- persist a managed-byte retention ledger or implement physical history GC without a focused contract;
- add always-on external telemetry or include private Vault/user content in default diagnostics;
- invent signing/notarization/updater infrastructure without a focused Delivery Issue;
- perform destructive cleanup merely because a legacy path is caller-zero.

## Validation expectations

Repository tests/tools are authoritative for repository-owned behavior. Use real-machine validation whenever a focused F Issue or destructive migration requires filesystem/platform evidence CI cannot prove. Storage-owned portability slices must deterministically prove containment, explicit ownership, fail-closed alias handling and source-Vault non-mutation. Diagnostics slices must prove field-level privacy, bounded retention and provider-failure isolation. Delivery workflow slices must keep untrusted/free-form dispatch data out of generated shell source and preserve immutable release validation.

## Resume sequence

1. Re-read latest `main`, `AGENTS.md`, `docs/product_architecture.md`, `docs/AI_PROGRESS.md`, this handoff, live F-focused Issues/PRs, CI, shared-hotspot ownership and migration-writer state.
2. Re-read #1063 and take only a newly split focused F filesystem/package contract whose logical prerequisites already exist.
3. Re-check #1064 only for a new explicitly F-owned follow-up beyond #1268; do not take over A history semantics or B Relation restore integrity.
4. Re-check destructive Bookmark/People/Photo retirement only for a specifically routed preservation-validation slice.
5. Re-check Delivery for a newly focused packaging/install/update/security defect beyond completed #1335/#1362/#1381; completed delivery checkpoints do not authorize inventing signing/notarization/updater work.
6. Re-check support diagnostics only for a newly focused privacy/correctness defect or explicit provider expansion; #1358 does not authorize telemetry, private-content collection or a general persisted logging platform.
7. If a concrete current-main Storage/Vault/Delivery correctness defect is demonstrated, create/reuse the smallest focused F Issue and fix only that defect.
8. Otherwise stop under the `AGENTS.md` idle-no-work condition rather than inventing a serializer, package format, sync protocol, retention ledger, updater, telemetry service or destructive cleanup merely to keep Lane F active.

## Current durable state

#1358 is completed through PR #1384 / merge `dfb2ce42778a6bc499ed7f64e3c34b6c8092b4d0`. #1381 is completed through PR #1386 / merge `c68eff2a128cb0055bcd0fee7874537dc32c97b5`.

At this checkpoint there is no active F implementation PR. #1063 still has no newly split ready filesystem/package child with explicit logical prerequisites, #1064 has no further explicit F persistence/physical-GC slice, no destructive retirement requests focused F preservation validation, and no additional concrete current-main Storage/Vault/Delivery defect has been demonstrated.

**Stop reason: idle-no-work after #1358/#1381 integration.** Resume only when one of the focused triggers above appears.
# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Recheck Primitive/Refactor ownership before changing shared storage helpers or bootstrap hotspots.

## Lane goal
Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed storage contracts shared by primitives, and app delivery plumbing without taking over Object/Relation product semantics.

## Current status — 2026-09-08
Lane F is active on **#951 — final Photo -> Image Vault/data-preservation validation**, coordinated with the remaining real-macOS checks in **#242**.

Latest repository audit is based on `main` `dc9a330896bb79b146b692b47b7fd38464311995`:
- **#949 is completed/closed.** Canonical `画像` is the single normal user-facing image collection and legacy `写真` AppShell navigation is retired.
- **#941 is completed/closed.** Shared Object Inspector canonical Image preview/edit parity is integrated.
- **#950 remains active, but the product-retirement gate required by F is integrated.** `PhotoManagementPage` is caller-zero and deleted; later G cleanup continues to preserve Photo schema/data, Vault files, migrations and backup/import/export compatibility.
- **#1021 is D-owned.** Draft PR #1025 adds safe canonical deletion for legacy-mirrored Images. It reuses the existing Storage ownership/deletion boundary and does not create a new F implementation obligation unless a concrete filesystem defect is found.
- **#242 implementation remains complete.** Only real-macOS Create/Open/Switch/Move/Recovery validation remains.
- **#897 and #218 remain completed/closed.** Legacy Photo physical deletion is Vault-safe, and macOS packaging/real-Mac launch/data preservation has already been validated.

The repository-side prerequisite for the final #951 preservation pass is released. Remaining closure work is the actual real-macOS preservation exercise plus any regression-backed defect found by that pass.

## Integrated validation tooling — #1026
PR #1026 `Add read-only Vault preservation manifest tool` is squash-merged as `dc9a330896bb79b146b692b47b7fd38464311995` after Flutter CI #3004 passed Analyze, all four Flutter Test shards, test-health and merge-gate. Both AI coordination audits were green.

Integrated files:
- `tool/vault_preservation_manifest.py`
- `tool/vault_preservation_manifest_test.py`
- `docs/vault_preservation_validation.md`
- one diagnostic-test invocation in the existing Flutter CI quality job

The helper is deliberately read-only with respect to the inspected Vault:
- rejects a Vault root that is a symlink/file;
- requires regular non-symlink `profile.json` and `database.sqlite`;
- validates the Vault v1 metadata contract before snapshotting;
- opens SQLite with `mode=ro` and requires `PRAGMA quick_check == ok`;
- records database size/SHA-256 for diagnostics but does not require identical SQLite bytes after legitimate reopen/migration/path rewrite;
- recursively inventories `photos/` and `attachments/` using `lstat` and never follows symlinks;
- hashes every regular managed file with SHA-256 and records size;
- detects missing, changed, type-changed and unexpected managed entries;
- writes manifests only outside the inspected Vault, including protection against a symlinked output parent redirecting back into the Vault;
- supports `--allow-profile-id-change` for Duplicate/backup-restore flows;
- keeps unexpected additions strict by default through explicit `--allow-extra`.

Privacy note: manifests are local diagnostics and may contain relative filenames or literal symlink targets. Do not attach raw manifests publicly.

## Active follow-up — database path-reference preservation
Branch: `feature/storage-vault-path-reference-manifest-951`
Baseline: `main` `dc9a330896bb79b146b692b47b7fd38464311995`

The first manifest slice proves SQLite integrity and exact managed bytes, but #242 also requires persisted Photo/attachment references to survive Move correctly. The current follow-up extends the same read-only helper rather than changing production storage semantics.

Implemented on the branch:
- snapshot `photos.path` and `bookmark_attachments.path` from SQLite read-only;
- classify each persisted path as Vault-owned or external absolute;
- normalize Vault-owned paths to one canonical relative identity;
- allow the expected legacy source-Vault absolute -> portable relative representation change after Move when both resolve to the same Vault-relative identity;
- require external absolute path text to remain exactly unchanged;
- detect missing/retargeted/unexpected database path references;
- reject relative `..` traversal instead of normalizing it into an apparently valid Vault identity;
- count persisted path references/external references in snapshot summaries;
- keep compatibility with manifests created by the first #1026 helper version by skipping path-reference comparison only when the *before* manifest predates the field.

Focused regression coverage on this branch adds:
1. database Photo/attachment path snapshotting;
2. Vault-contained absolute -> equivalent relative Move rebase acceptance;
3. exact external absolute path text preservation;
4. missing database path-reference detection;
5. traversing relative path rejection;
while retaining the ten #1026 safety/integrity regressions.

No production Dart/Vault behavior is changed. The branch does not edit `profile_manager.dart`, `settings_page.dart`, `app_database.dart`, AppShell, Image/Relation services or primitive hosts.

## #951 — final Photo -> Image preservation matrix
The repository state is ready for the real app/macOS pass. Verify:
1. existing legacy Photos promoted to canonical Images still resolve after restart;
2. existing Bookmark `Images` / `Cover Image` media migrated from Photo data still renders after restart;
3. existing Person profile Images still render after restart;
4. native canonical Images that never had legacy Photos remain intact;
5. Vault Move preserves canonical Image paths and remaining migration-only compatibility paths at the target;
6. default/custom Vault switching keeps image/profile/cover data isolated;
7. external absolute image/file references are not silently copied, rebased or deleted;
8. missing/offline Vault behavior remains fail-closed and does not manufacture an empty replacement data set;
9. Duplicate/reopen/backup-restore does not lose Image/Photo mapping required for migration compatibility.

Use the preservation manifest before/after filesystem-sensitive operations. After the active path-reference follow-up integrates, it will verify not only SQLite integrity and exact managed bytes but also the persisted legacy Photo/Bookmark attachment path-rebasing contract. Object/Relation/UI meaning still requires the manual semantic checks above.

## Vault lifecycle (#242)
The production lifecycle remains integrated:
- persisted custom Vault paths are authoritative;
- missing custom Vaults/databases fail closed rather than being silently recreated;
- Settings supports reveal/create/open/switch/move;
- Create/Open validate before active-state mutation;
- Move checkpoints/quiesces/copies/validates/reopens with rollback and never automatically deletes the source;
- legacy absolute managed Photo/attachment paths inside the source Vault are rebased only when a corresponding copied target exists;
- external absolute references remain external;
- backup/restore portability, moved/missing Vault recovery and registry-only removal are regression-covered;
- removing a Vault from the registered/recent list never deletes its files.

Vault v1 remains:

```text
<My Vault>/
├─ database.sqlite
├─ profile.json
├─ photos/
└─ attachments/
```

Remaining real-macOS #242 checks should be combined with #951 where practical:
1. Create a Vault in a temporary custom/external location and restart successfully.
2. Open an existing Vault in place without copying it to the default root.
3. Switch default/custom Vaults and verify separation/preservation.
4. Move a Vault, restart from the target, and verify photos/attachments/external refs.
5. Exercise invalid/non-empty Move target plus missing/moved-folder recovery while preserving the source/current Vault.

## Shared managed-file filesystem contract
Integrated contracts remain unchanged:
- `VaultManagedFileCopyService` copies regular files into `<Vault>/attachments`, returns portable stored paths plus explicit `vault-managed-copy-v1` ownership, and rolls back only the exact newly-created copy.
- Legacy Bookmark attachment copying and canonical File import use that managed-copy seam.
- Persistent attachment physical delete requires explicit managed ownership plus a safe Vault-relative `attachments/...` path and fails closed on traversal, symlinks, non-files and unavailable Vault roots.
- Legacy Photo physical delete similarly requires proven active-Vault managed ownership; external/ambiguous paths are preserved.

Do not infer generic File ownership from path location alone. Lane D owns Image/File product identity and mutation semantics; Lane F owns byte placement and deletion authority.

## Data-safety invariants
- Never silently replace or recreate an unavailable Vault merely to continue an operation.
- Configured Vault/profile roots control managed-media resolution.
- External absolute references remain external and never gain deletion authority from a legacy record.
- Physical delete fails closed on traversal, symlinks, unsafe roots, non-files and ambiguous ownership.
- Legacy Photo/Image sharing policy remains distinct from Storage path/byte ownership.
- Generic File physical delete requires explicit managed ownership, not path location alone.
- Removing a Vault from the registered/recent list never deletes its bytes.
- Raw filesystem/database exception details are not exposed in user-facing recovery/Settings messages.
- #951 validation must not delete legacy schema/data; any destructive schema retirement is a separate explicit migration decision.

## Cross-lane boundaries / concurrency
- Lane D owns Image/Photo/File identity, promotion/mapping, MIME/content routing and user-facing primitive semantics. #1021/#1025 remain D-owned.
- Lane B owns Relation mutation/index/delete integrity.
- Lane C completed #949 and owns no remaining legacy `写真` navigation work.
- Lane G owns further #950 caller-zero compatibility deletion. Open PR #1028 touches `app_database.dart`; the current F branch does not touch that hotspot.
- Lane F owns byte placement, portable paths, Vault lifecycle/recovery, physical-delete safety and #951 preservation validation/tooling.

The active F branch changes only the preservation helper/tests/guide/handoff. Shared hotspot lease: none.

## Current checkpoint / validation
- #1026 merged as `dc9a330896bb79b146b692b47b7fd38464311995` after Flutter CI #3004 full green;
- current branch: `feature/storage-vault-path-reference-manifest-951`;
- production app/Vault behavior changed on current branch: **none**;
- migration/data impact: **none**;
- shared hotspot lease: **none**;
- path-reference normalization/comparison logic was prototyped against temporary SQLite Vaults before repository update: managed source absolute -> target relative compared cleanly; changed external target was detected;
- normal repository CI remains the authoritative validation for the committed branch.

## Next actions
1. Open and integrate the focused path-reference manifest PR after normal CI proves the expanded Python regression plus Analyze/full Flutter Test green.
2. Run the combined #951 + #242 real-macOS preservation matrix using `docs/vault_preservation_validation.md`, retaining the source Vault throughout Move/recovery exercises.
3. Record filesystem/Vault results on #242 and Photo -> Image semantic-preservation results on #951.
4. If a reproducible filesystem/Vault defect appears, create/follow a focused Lane F Issue and add a regression-backed fix. Otherwise close #242/#951 once the real-machine criteria are confirmed.

## Stop condition
Do not stop merely because a validation-tool PR is opened or CI is pending. Continue with independent F-owned work when present. After the path-reference helper is integrated, no known repository-side F implementation obligation remains; the remaining closure boundary is actual real-macOS app/Vault interaction unless that validation exposes a concrete defect.

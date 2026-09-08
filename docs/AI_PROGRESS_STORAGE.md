# AI Progress — Storage, Vault & Delivery Lane

> Lane F handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Recheck Primitive/Refactor ownership before changing shared storage helpers or bootstrap hotspots.

## Lane goal
Own physical data-location lifecycle, Vault portability/recovery, filesystem-level managed storage contracts shared by primitives, and app delivery plumbing without taking over Object/Relation product semantics.

## Current status — 2026-09-08
Lane F is active on **#951 — final Photo -> Image Vault/data-preservation validation**, coordinated with the remaining real-macOS checks in **#242**.

Latest repository audit is based on `main` `10bae52808a0176a94163228d348c988de516498`:
- **#949 is completed/closed.** PR #1015 merged as `5f03dccc55e9333c51ce3db2a2e8d8f6f2216f0f`, so canonical `画像` is now the single normal user-facing image collection and legacy `写真` AppShell navigation is retired.
- **#941 is completed/closed.** Shared Object Inspector canonical Image preview/edit parity is integrated.
- **#950 remains active, but its current product-retirement gate is integrated.** PR #1019 merged as `10bae52808a0176a94163228d348c988de516498`, deleting the caller-zero `PhotoManagementPage` implementation while explicitly preserving Photo schema/data, `bookmark_photos`, `photo_object_links`, Person legacy photo data, Vault files, migrations, backup/import/export behavior and Storage policy.
- **#242 implementation remains complete.** Only real-macOS Create/Open/Switch/Move/Recovery validation remains.
- **#897 and #218 remain completed/closed.** Legacy Photo physical deletion is Vault-safe, and macOS packaging/real-Mac launch/data preservation has already been validated.

The repository-side prerequisite for the final #951 preservation pass is now effectively released: canonical Images own normal product navigation/detail, and the legacy Photo management UI is caller-zero and removed. Remaining #950 refactor work must continue to preserve migration/Vault compatibility but does not block starting #951.

## Active implementation — read-only Vault preservation manifest
Branch: `feature/storage-vault-preservation-manifest-951`

Goal: make the final #242/#951 real-machine preservation pass reproducible and machine-checkable without changing production Vault semantics.

Added:
- `tool/vault_preservation_manifest.py`
- `tool/vault_preservation_manifest_test.py`
- `docs/vault_preservation_validation.md`
- one patch-sized CI diagnostic-test invocation in `.github/workflows/flutter_ci.yml`

The helper is deliberately read-only with respect to the inspected Vault:
- rejects a Vault root that is a symlink/file;
- requires regular non-symlink `profile.json` and `database.sqlite`;
- validates the Vault v1 metadata contract before snapshotting;
- opens SQLite with `mode=ro` and requires `PRAGMA quick_check == ok`;
- records database size/SHA-256 for diagnostics but does not require identical SQLite bytes after legitimate reopen/migration/path rewrite;
- recursively inventories `photos/` and `attachments/` using `lstat` and never follows symlinks;
- hashes every regular managed file with SHA-256 and records size;
- detects missing, changed, type-changed and unexpected managed entries;
- writes the manifest only to an explicitly supplied location outside the Vault;
- canonicalizes the output path so a symlinked parent cannot redirect the manifest back inside the Vault;
- supports `--allow-profile-id-change` for Duplicate/backup-restore flows where a new Vault identity is expected;
- keeps unexpected additions strict by default; `--allow-extra` is explicit and should only be used when the validation operation intentionally creates managed files.

Privacy note: manifests may contain relative managed filenames and literal symlink target strings. Keep them local; GitHub comments should contain only the pass/fail summary or deliberately redacted failure details.

Validation coverage currently includes:
1. SQLite quick-check + managed-file hashing.
2. invalid Vault v1 metadata rejection.
3. unchanged comparison success.
4. changed/missing managed-file detection.
5. optional profile-id change for Duplicate/restore.
6. symlink observation without traversal.
7. symlink database rejection.
8. symlink Vault-root rejection.
9. direct manifest-output-inside-Vault rejection.
10. symlink-parent manifest-output redirection rejection.

The Python regression is wired into the existing `Developer workflow diagnostic tests` CI step so the repository's normal full gate validates it.

## #951 — final Photo -> Image preservation matrix
The repository state is now ready for the real app/macOS pass. Verify:
1. existing legacy Photos promoted to canonical Images still resolve after restart;
2. existing Bookmark `Images` / `Cover Image` media migrated from Photo data still renders after restart;
3. existing Person profile Images still render after restart;
4. native canonical Images that never had legacy Photos remain intact;
5. Vault Move preserves canonical Image paths and remaining migration-only compatibility paths at the target;
6. default/custom Vault switching keeps image/profile/cover data isolated;
7. external absolute image/file references are not silently copied, rebased or deleted;
8. missing/offline Vault behavior remains fail-closed and does not manufacture an empty replacement data set;
9. Duplicate/reopen/backup-restore does not lose Image/Photo mapping required for migration compatibility.

Use the preservation manifest before/after filesystem-sensitive operations to verify SQLite integrity and exact managed-file bytes. The helper does **not** replace the manual semantic/UI checks above.

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
- Lane D owns Image/Photo/File identity, promotion/mapping, MIME/content routing and user-facing primitive semantics.
- Lane B owns Relation mutation/index/delete integrity.
- Lane C completed #949 and owns no remaining legacy `写真` navigation work.
- Lane G owns further #950 caller-zero compatibility deletion. #1019 is integrated and changed no Vault/Storage behavior.
- Lane F owns byte placement, portable paths, Vault lifecycle/recovery, physical-delete safety, and #951 preservation validation/tooling.

Current F branch does not edit `profile_manager.dart`, `settings_page.dart`, `app_database.dart`, AppShell or primitive hosts. The only shared CI file edit is one non-overlapping diagnostic-test line after G PR #1017 merged.

## Current checkpoint / validation
- baseline refreshed to main `10bae52808a0176a94163228d348c988de516498` after #1019 merged;
- current branch: `feature/storage-vault-preservation-manifest-951`;
- PR: #1026 `Add read-only Vault preservation manifest tool`;
- current branch includes the read-only manifest helper, ten focused Python regressions, validation guide, and CI invocation;
- CI #2999 proved the initial nine-test helper suite executed successfully in `Developer workflow diagnostic tests`; a follow-up safety review added explicit Vault v1 metadata validation plus the tenth regression, now awaiting the latest full CI run;
- production app/Vault behavior changed: **none**;
- migration/data impact: **none**;
- shared hotspot lease: **none**.

## Next actions
1. Integrate PR #1026 after the latest normal CI proves all ten Python regressions plus Analyze/full Flutter Test remain green.
2. Run the combined #951 + #242 real-macOS preservation matrix using `docs/vault_preservation_validation.md`, retaining the source Vault throughout destructive-looking Move/recovery exercises.
3. Record filesystem/Vault results on #242 and Photo -> Image semantic-preservation results on #951.
4. If a reproducible filesystem/Vault defect appears, create/follow a focused Lane F Issue and add a regression-backed fix. Otherwise close #242/#951 once the real-machine criteria are confirmed.

## Stop condition
Do not stop merely because the validation-tool PR is opened or CI is pending. Continue with any independent F-owned work. Once the helper is integrated, no known repository-side dependency remains for #951; the remaining closure work requires actual real-macOS app/Vault interaction, which is the legitimate remaining boundary if no defect is found.

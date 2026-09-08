# AI Progress — Primitive Objects & Media Lane

> Lane D durable handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth; SHAs below are checkpoints only.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Current issue status — 2026-09-08
- #484 — built-in primitive boundary / canonical File: **completed/closed**.
- #495 — MIME/content-aware Image/File import: **completed/closed**. Shared content-first classification/routing is established; the final canonical Images collection picker inconsistency was closed by #866.
- #245 — Photo -> Image consolidation: **open**. Bookmark-facing Photo authority is largely migrated. Remaining work is primarily People/profile-photo parity plus safe retirement of residual legacy Photo presentation/storage compatibility.
- #155 — Weblink Objectization / legacy Bookmark convergence: **open**. Canonical Weblink identity/media/action behavior is established. Recent work removed stale legacy Bookmark URL presentation/writer paths from People and Bookmark detail; continue only for concrete behavior gaps or caller-zero retirement, not another Weblink persistence path.
- #489 — shared native capabilities: **completed/closed**.

## Architecture contract
- Image and File are distinct system ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File. Do not add a PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete boundaries.
- Lane C owns generic Database/View/schema presentation; Lane B owns Relation lifecycle/integrity; Lane E owns search persistence/reconciliation.
- Canonical Bookmark `Images` / `Cover Image` Relations are the editing authority. `bookmark_photos` is only a temporary compatibility projection for Image Objects that still map to legacy Photos.
- Canonical Bookmark -> Weblink identity is the preferred URL source for presentation and non-URL compatibility writes. Legacy `bookmark.url` remains fallback/compatibility data and must not overwrite a healthy canonical Weblink during unrelated edits.
- Never infer physical-delete authority merely from a Vault-looking path or content hash.

## Image / legacy Photo — current #245 state
Canonical Image now has managed import/create/reuse, provenance, portable stored-path identity, content-first classified import, geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety, generic collection media and Bookmark Relation integration.

### Completed migration slices
- #866 — canonical Images collection picker classifies selected content before mutation. Squash merge `51b8e41d8a500b905f2e96d005a559d04d6aa743`; Flutter CI #2632 full green. This completed #495.
- #869 — canonical Image/Weblink media in Database List rows. Squash merge `36588e0d89e4f95e204d72d7a00194d7c7a2f0ba`; Flutter CI #2649 full green.
- #876 — shared canonical media host in Database Table name cells. Squash merge `3506974e…`; Flutter CI #2677 full green.
- #879 — `CoreObjectBridge` preserves native Bookmark Image Relations while synchronizing only the legacy-mapped compatibility subset. Squash merge `3be71f12…`; Flutter CI #2674 full green.
- #881 — Bookmark detail image editing moved to canonical `Images` / `Cover Image` Relations. Squash merge `47d31345dbaa602e99d00c6199650d9e6b329d32`; Flutter CI #2710 full green.
- #889 — PhotoManagement attach-to-Bookmark routes through canonical Image Relations. Squash merge `fcd0eb34c8ed79cbf67a8595f730f6c08cb7e7ff`; Flutter CI #2717 full green.
- #892 — Bookmark creation stopped directly writing selected Photos into `bookmark_photos`. Squash merge `94b3833106683745291470732331aef3d28d66d5`; Flutter CI #2730 full green.
- #901 — Photo -> Bookmark reverse lookup resolves through canonical Image Relation backlinks. Squash merge `0fa47d01ecf49d47c6b2cc0173505219590e59de`; Flutter CI #2747 full green.
- #903 — Lane G removed six caller-zero legacy Bookmark Photo forwarding APIs. Squash merge `48e945fdf8aa2496120ca60297e65f8e1cd31585`.
- #914 — Stage1 saved Photo filter uses canonical Image backlinks. Squash merge `d91cb79a5add08bac0d2ca6dbcfd9a00f2f4a04f`; Flutter CI #2759 full green.
- #921 — Stage1 image drops route through canonical content-aware Image import and do not create legacy Photo rows. Squash merge `2b5500957f58c41a12a9ae1c6c02bfc71343f4a8`; Flutter CI #2774 full green.
- #908 — Lane C established canonical Images first-run shared Gallery presentation.
- #922 / #895 — Lane B added strict stored-value/index/target/cardinality preflight for Bookmark Image Relation mutations. Squash merge `bc09381b9eb77dee6b4ef12a94e7b9c06bc86c36`; Flutter CI #2793 full green. Lane D Bookmark Image writers must preserve this fail-closed contract.
- #930 — Bookmark creation now selects canonical Image Objects directly instead of `PhotoRecord` / `photo_database_picker.dart`. Squash merge `63760af94358945d8ca83d8a4d2cc58245c51baf`; Flutter CI #2806 full green.

### Remaining legacy Photo boundary
- Post-#930 production caller audit found `photo_database_picker.dart` used by **People profile-photo selection only**.
- `Person.profilePhotoId` remains a direct legacy Photo reference, and `PeopleManagementPage` still resolves/chooses profile images through `PhotoRecord` + `photo_database_picker.dart`.
- There is currently no canonical Person Object/Relation identity contract on main. Do **not** invent a Lane-D-only Person->Image mapping merely to remove `profilePhotoId`; sequence that migration with the lane that owns Person/Object identity.
- `PhotoManagementPage` still owns legacy Photo import plus legacy title/note/tag/image-edit presentation. It cannot be deleted while People profile photos still require legacy Photo supply and until explicit presentation parity/caller-zero is proven.

Compatibility warning: do not remove `Photos`, `Person.profilePhotoId`, `PhotoManagementPage`, `photo_database_picker.dart`, `photo_object_links` or compatibility bridge rules until replacement parity/caller-zero is explicit. `CoreObjectBridge` also preserves a special relative-path/no-profile-root compatibility rule; do not mechanically replace it with ordinary filesystem-existence semantics.

## MIME/content routing — #495 completed
`PrimitiveObjectImportService` remains the canonical ambiguous-file decision boundary:
1. validate a real regular-file source;
2. classify once with `strong content signature > meaningful declared MIME > extension fallback`;
3. invoke exactly one Image/File importer;
4. never fall through after the selected importer fails.

Current behavior includes supported image content routing to canonical Image even with misleading extensions; safe non-image/unknown content routing to canonical File; explicit target pickers failing before mutation on a classification mismatch; codec-appropriate managed extensions while preserving source filename provenance; shared routing for File picker and Relation target quick-create; and path-free ordinary diagnostics.

#495 is closed/completed. Reopen only if a concrete real import entry point is found to bypass the shared classifier contract.

## Canonical File — integrated state
Canonical File is production-capable with managed/Vault-relative identity, original filename, strict MIME/content type, extension/size/import timestamp/SHA-256 metadata, typed ownership, open/reveal/export, missing-file-safe projection, PDF metadata/preview/text capabilities, shared-reference-aware deletion, real generic File collection import and Object Inspector presentation.

File identity remains stored-path based; SHA-256 is metadata, not implicit identity/delete authority.

## Weblink / legacy Bookmark — current #155 state
- Canonical Weblink has normalized identity/reuse, fail-soft enrichment, Representative/Related Images through canonical Relations, shared visual resolution and native actions.
- Bookmark Stage1 Gallery/List/Table/card/detail visual surfaces already use managed/canonical resolvers rather than direct raw Weblink/media persistence.
- #937 — PeopleManagement related-Bookmark URL subtitle now resolves canonical Bookmark -> Weblink URL via the shared presentation resolver, with legacy fallback. Squash merge `8a5c192920df5b32f6a2d5ec9287570f4d1da744`; Flutter CI #2830 full green.
- #943 — Bookmark detail URL display, tooltip, open action, URL-edit baseline and unrelated inline compatibility updates now preserve the resolved canonical Weblink URL. `BookmarkAttachmentSection` PDF metadata updates use the same canonical URL preservation contract. Squash merge `64c40d8590616574e80361554c38a33b2de2607f`; Flutter CI #2845 full green.
- #943 validation lesson: an initial full `BookmarkDetailPanel` widget regression timed out because unrelated preview-refresh/image/Relation async work remained outstanding. Diagnostics showed a pending repository preview-refresh Timer rather than a production assertion failure. The regression was narrowed to deterministic URL wiring/source coverage while existing resolver/precedence behavior remains covered at lower levels.
- Fresh audit before #943 found no other production `url: widget.bookmark.url` compatibility writer beyond Bookmark detail and PDF metadata application.
- Remaining `bookmark.url` uses include persistence/bridge/import/export/search/organize compatibility roles. Do not mechanically replace them; migrate only when a concrete behavior gap is demonstrated and the owning boundary is clear.

## Tag
Tag remains canonical Object storage with hierarchy through canonical self-Relation. Do not invent parallel tag-edge storage or native uniqueness semantics without an explicit product decision.

## Validation / environment
- Recent #245 validation: #869 CI #2649, #876 #2677, #879 #2674, #881 #2710, #889 #2717, #892 #2730, #901 #2747, #914 #2759, #921 #2774, Relation #922 #2793 and #930 #2806 all completed successfully before merge.
- Recent #155 validation: #937 CI #2830 full green; #943 CI #2845 full green.
- Local Flutter/Dart execution is unavailable in this connector runtime; GitHub Actions is the executable validation source.

## Current hotspot / concurrency state
Latest audited main when this handoff was refreshed: `64c40d8590616574e80361554c38a33b2de2607f` (#943).

Open PR snapshot at this checkpoint:
- #946 — Lane A docs-only handoff.
- #952 — Lane G legacy Saved View Store retirement.
- #953 — Lane G docs-only handoff.
None owns current Lane D Weblink/Photo presentation files, but re-audit live ownership before editing.

Shared hotspots requiring a fresh lease audit include `PhotoManagementPage`, `PeopleManagementPage`, `bookmark_create_dialog.dart`, `bookmark_detail_panel.dart`, `app_database.dart`, `app_shell.dart`, `generic_database_page.dart` and Object/Relation core files.

## Exact next actions
1. #245 People dependency: coordinate an explicit canonical Person identity/Relation contract before migrating `Person.profilePhotoId`. Do not invent Lane-D-only Person->Image persistence.
2. Audit PhotoManagement legacy-only features (new Photo import, title/note/tags, image editing/deletion) against canonical Images. Retire only features with proven canonical parity and no People dependency.
3. Keep compatibility projection/import paths fail-closed and preserve #922 Relation integrity preflight for every Bookmark Image writer.
4. Once Person profile-photo parity exists, re-audit `photo_database_picker.dart`, `PhotoManagementPage`, `Photos` and `photo_object_links` for true caller-zero retirement.
5. For #155, inspect remaining `bookmark.url` consumers by behavior. Continue only when canonical-vs-legacy divergence produces a real user-visible or correctness gap. Presentation/direct compatibility writers in People/detail/PDF metadata are already migrated by #937/#943.
6. Do not change Search/import/export/bridge/auto-organize URL semantics speculatively; coordinate with their owning lanes if a concrete gap is found.

## Cross-lane dependencies / blockers
- Lane B: owns Relation integrity; #922 strict mutation preflight is required for Lane D Bookmark Image writers.
- Lane C: canonical Images first-run Gallery and shared collection presentation are on main; generic Database/View remains a shared hotspot.
- Lane F: Vault copy/ownership/rollback/delete boundaries are on main; no generic File blocker is active.
- Lane E: owns Search persistence/reconciliation; Lane D should emit primitive/domain facts only, never write FTS directly.
- Person/Object identity: current blocker for fully removing `Person.profilePhotoId` / People’s legacy Photo picker. Coordinate before inventing a new Person->Image persistence path.

## Run checkpoint
Latest Lane D production merge: #943, squash merge `64c40d8590616574e80361554c38a33b2de2607f`, Flutter CI #2845 full green.

Immediately preceding Lane D production merge: #937, squash merge `8a5c192920df5b32f6a2d5ec9287570f4d1da744`, Flutter CI #2830 full green.

Latest Image/Photo production milestone: #930, squash merge `63760af94358945d8ca83d8a4d2cc58245c51baf`, Flutter CI #2806 full green.

Cross-lane integrity prerequisite on main: Relation #922 / #895, squash merge `bc09381b9eb77dee6b4ef12a94e7b9c06bc86c36`, Flutter CI #2793 full green.

#495 is complete. #245 is primarily a People/profile-photo and residual Photo-presentation retirement problem. #155 now requires evidence-driven cleanup of remaining compatibility consumers rather than further generic Weblink architecture work.

# AI Progress — Primitive Objects & Media Lane

> Lane D durable handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth; SHAs below are checkpoints only.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Current issue status — 2026-09-08
- #484 — built-in primitive boundary / canonical File: **completed/closed**.
- #495 — MIME/content-aware Image/File import: **completed/closed**. Shared content-first classification/routing is established and the final canonical Images collection picker inconsistency was closed by #866.
- #245 — Photo -> Image consolidation: **open**. Canonical Image is established and Bookmark-facing Photo authority is now largely migrated. Remaining work is People/profile-photo parity plus safe retirement of residual legacy Photo presentation/storage compatibility.
- #155 — Weblink Objectization / legacy Bookmark convergence: **open**. Canonical Weblink identity/media/action behavior is established; remaining work should be generic presentation or caller-zero retirement, not another Weblink persistence path.
- #489 — shared native capabilities: **completed/closed**.

## Architecture contract
- Image and File are distinct system ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File. Do not add a PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete boundaries.
- Lane C owns generic Database/View/schema presentation; Lane B owns Relation lifecycle/integrity; Lane E owns search persistence/reconciliation.
- Canonical Bookmark `Images` / `Cover Image` Relations are the editing authority. `bookmark_photos` is only a temporary compatibility projection for Image Objects that still map to legacy Photos.
- Never infer physical-delete authority merely from a Vault-looking path or content hash.

## Image / legacy Photo — current #245 state
Canonical Image now has managed import/create/reuse, provenance, portable stored-path identity, content-first classified import, geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety, generic collection media and Bookmark Relation integration.

### Completed migration slices
- #866 — canonical Images collection picker classifies selected content before mutation. Misleading extensions route by content, mixed Image/File selections fail before mutation, and legacy Photo picker behavior remains isolated. Squash merge `51b8e41d8a500b905f2e96d005a559d04d6aa743`; Flutter CI #2632 full green. This completed #495.
- #869 — canonical Image/Weblink media in Database List rows. Squash merge `36588e0d89e4f95e204d72d7a00194d7c7a2f0ba`; Flutter CI #2649 full green.
- #876 — shared canonical media host in Database Table name cells. Squash merge `3506974e…`; Flutter CI #2677 full green.
- #879 — `CoreObjectBridge` preserves native Bookmark Image Relations while synchronizing only the legacy-mapped subset still required for compatibility. Squash merge `3be71f12…`; Flutter CI #2674 full green.
- #881 — Bookmark detail image editing moved to canonical `Images` / `Cover Image` Relations. Canonical Relation is the editing authority; only legacy-mapped Images maintain a `bookmark_photos` projection. Squash merge `47d31345dbaa602e99d00c6199650d9e6b329d32`; Flutter CI #2710 full green.
- #889 — PhotoManagement “attach to Bookmark” routes through canonical Image Relations rather than legacy Bookmark Photo mutation. Squash merge `fcd0eb34c8ed79cbf67a8595f730f6c08cb7e7ff`; Flutter CI #2717 full green.
- #892 — Bookmark creation stopped writing selected Photos directly into `bookmark_photos`; the compatibility create path mirrors first and commits canonical Image Relations. Squash merge `94b3833106683745291470732331aef3d28d66d5`; Flutter CI #2730 full green.
- #901 — Photo -> Bookmark reverse lookup resolves `photo_object_links -> canonical Image Relation backlinks -> Bookmark`, not `BookmarkItem.photos`. Squash merge `0fa47d01ecf49d47c6b2cc0173505219590e59de`; Flutter CI #2747 full green.
- #903 — Lane G removed six caller-zero legacy Bookmark Photo forwarding APIs after the above migrations. Squash merge `48e945fdf8aa2496120ca60297e65f8e1cd31585`.
- #914 — Stage1 saved Photo filter uses canonical Image backlinks and no longer filters through `bookmark.photos`. Squash merge `d91cb79a5add08bac0d2ca6dbcfd9a00f2f4a04f`; Flutter CI #2759 full green.
- #921 — Stage1 image drops route through canonical content-aware Image import and do not create legacy Photo rows. Squash merge `2b5500957f58c41a12a9ae1c6c02bfc71343f4a8`; Flutter CI #2774 full green.
- #908 — Lane C established the canonical Images collection’s first-run shared masonry/direct-Image Gallery View, so first-class Images have generic collection presentation parity without reviving the Photo page as the primary collection.
- #922 / #895 — Lane B added strict stored-value/index/target/cardinality preflight for Bookmark Image Relation mutations. Squash merge `bc09381b9eb77dee6b4ef12a94e7b9c06bc86c36`; Flutter CI #2793 full green. Lane D Bookmark Image writers must preserve this fail-closed contract.
- #930 — Bookmark creation now selects canonical Image Objects directly instead of `PhotoRecord` / `photo_database_picker.dart`. `saveImagesAfterCreate(...)` establishes the canonical Bookmark Object and atomically persists Images/Cover plus only necessary legacy-mapped projection; native Images create no `photos` or `bookmark_photos` rows. Relation #922 strict preflight is preserved before compatibility sync and again from fresh state inside the final transaction. Squash merge `63760af94358945d8ca83d8a4d2cc58245c51baf`; Flutter CI #2806 full green.

### Remaining legacy boundary
- Post-#930 production caller audit finds `photo_database_picker.dart` used by **People profile-photo selection only**. Bookmark detail/create no longer use it.
- `Person.profilePhotoId` remains a direct legacy Photo reference, and `PeopleManagementPage` still resolves/chooses profile images through `PhotoRecord` + `photo_database_picker.dart`.
- There is currently no canonical Person Object/Relation identity contract on main. Do **not** invent a second Person->Image mapping inside Lane D merely to remove `profilePhotoId`; sequence that migration with the lane that owns Person/Object identity.
- `PhotoManagementPage` still owns legacy Photo import plus legacy title/note/tag/image-edit presentation. It cannot be deleted while People profile photos still require legacy Photo supply and until explicit presentation parity/caller-zero is proven.

Compatibility warning: do not remove `Photos`, `Person.profilePhotoId`, `PhotoManagementPage`, `photo_database_picker.dart`, `photo_object_links` or compatibility bridge rules until replacement parity/caller-zero is explicit. `CoreObjectBridge` also preserves a special relative-path/no-profile-root compatibility rule; do not mechanically replace it with ordinary filesystem-existence semantics.

## MIME/content routing — #495 completed
`PrimitiveObjectImportService` remains the canonical ambiguous-file decision boundary:
1. validate a real regular-file source;
2. classify once with `strong content signature > meaningful declared MIME > extension fallback`;
3. invoke exactly one Image/File importer;
4. never fall through after the selected importer fails.

Current behavior includes:
- supported image content routes to canonical Image even with misleading extension;
- non-image/unknown safe content routes to canonical File;
- explicit Image/File target pickers fail before mutation when selected content belongs to the other primitive;
- content-classified Image import uses a codec-appropriate managed extension while preserving source filename provenance;
- File picker and Relation target quick-create reuse the same routing boundary;
- no raw user path belongs in ordinary diagnostics.

#495 is closed/completed. Reopen only if a concrete real import entry point is found to bypass the shared classifier contract; do not extend the routing architecture speculatively.

## Canonical File — integrated state
Canonical File is production-capable with managed/Vault-relative identity, original filename, strict MIME/content type, extension/size/import timestamp/SHA-256 metadata, typed ownership, open/reveal/export, missing-file-safe projection, PDF metadata/preview/text capabilities, shared-reference-aware deletion, real generic File collection import and Object Inspector presentation.

Key integrated slices include #512, #528, #553, #557, Lane F #750/#771, #778, #788, #794, #798, #804, #824, #830, #834, #837, #841, #853 and #862. File identity remains stored-path based; SHA-256 is metadata, not implicit identity/delete authority.

## Weblink / Tag
- Weblink has normalized identity/reuse, fail-soft enrichment, Representative/Related Images through canonical Relations, shared visual resolution and native actions. Continue #155 only for concrete generic presentation or caller-zero compatibility work.
- Tag remains canonical Object storage with hierarchy through canonical self-Relation. Do not invent parallel tag-edge storage or native uniqueness semantics without an explicit product decision.

## Validation / environment
- Recent #245 validation: #869 CI #2649, #876 #2677, #879 #2674, #881 #2710, #889 #2717, #892 #2730, #901 #2747, #914 #2759, #921 #2774, Relation #922 #2793 and #930 #2806 all completed successfully before their respective merges.
- Local Flutter/Dart execution is unavailable in this connector runtime; GitHub Actions is the executable validation source.

## Current hotspot / concurrency state
Latest audited main when this handoff was refreshed: `ec27e886519e9d1af31ba551e91533687294dcab`.

At this checkpoint GitHub reported no open PRs. Treat that only as a snapshot: always re-audit live PR ownership immediately before editing shared hotspots.

Shared hotspots requiring a fresh lease audit include `PhotoManagementPage`, `PeopleManagementPage`, `bookmark_create_dialog.dart`, `app_database.dart`, `app_shell.dart`, `generic_database_page.dart` and Object/Relation core files.

## Exact next actions
1. #245 People dependency: coordinate an explicit canonical Person identity/Relation contract before migrating `Person.profilePhotoId`. Do not invent Lane-D-only Person->Image persistence.
2. Audit PhotoManagement legacy-only features (new Photo import, title/note/tags, image editing/deletion) against canonical Images. Retire only features with proven canonical parity and no People dependency.
3. Keep compatibility projection/import paths fail-closed and preserve #922 Relation integrity preflight for every Bookmark Image writer.
4. Once Person profile-photo parity exists, re-audit `photo_database_picker.dart`, `PhotoManagementPage`, `Photos` and `photo_object_links` for true caller-zero retirement.
5. Continue #155 only for concrete Weblink presentation/caller-zero work if #245 is blocked on Person identity.

## Cross-lane dependencies / blockers
- Lane B: owns Relation integrity; #922 strict mutation preflight is a required contract for Lane D Bookmark Image writers.
- Lane C: canonical Images first-run Gallery and shared collection presentation are on main; generic Database/View remains a shared hotspot.
- Lane F: Vault copy/ownership/rollback/delete boundaries are on main; no generic File blocker is active.
- Lane E: owns Search persistence/reconciliation; Lane D should emit primitive/domain facts only, never write FTS directly.
- Person/Object identity: current blocker for fully removing `Person.profilePhotoId` / People’s legacy Photo picker. Coordinate before inventing a new Person->Image persistence path.

## Run checkpoint
Latest Lane D production merge: #930, squash merge `63760af94358945d8ca83d8a4d2cc58245c51baf`, Flutter CI #2806 full green.

Immediately preceding Lane D production merge: #921, squash merge `2b5500957f58c41a12a9ae1c6c02bfc71343f4a8`, Flutter CI #2774 full green.

Cross-lane integrity prerequisite on main: Relation #922 / #895, squash merge `bc09381b9eb77dee6b4ef12a94e7b9c06bc86c36`, Flutter CI #2793 full green.

#495 is complete. #245 is now primarily a People/profile-photo and residual Photo-presentation retirement problem rather than a Bookmark Image Relation/import problem.

# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership, and current CI before editing. GitHub is the source of truth; this file summarizes the latest durable Lane D checkpoint.

## Lane goal
Provide built-in Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined domain schemas without parallel persistence systems.

## Active issues / status
- #155 — reusable Weblink identity/metadata/media and legacy Bookmark convergence. Open; remaining work is presentation/legacy compatibility retirement rather than core Weblink identity.
- #245 — legacy Photo -> canonical Image migration. Open; canonical Image import and Photo mirroring are established, while remaining work is host/write-authority parity and legacy retirement.
- #484 — primitive boundary and canonical File. Open; canonical File + PDF-on-File behavior are established, while generic host composition/template parity remains cross-lane work.
- #495 — MIME/content-aware Image/File import routing. Open; content-first routing and production File/Image import paths are established.
- #489 — capability-oriented native behavior. **Completed/closed**; do not treat this as an active blocker.

## Product contract / lane boundary
- Image and File remain distinct ObjectTypes while sharing file-backed/native capability infrastructure.
- PDF remains a File Object with type-specific preview/metadata/page-count/text behavior; no PDF-specific persistence model is allowed.
- Lane D owns primitive identity, metadata, MIME/content routing and native product behavior.
- Lane F owns Vault/filesystem placement, portable paths, explicit byte ownership, rollback and physical-delete filesystem safety.
- Lane C owns generic Database/View presentation and shared hosts.
- Lane B owns Relation lifecycle/integrity for primitive-producing workflows.
- Lane E owns search index persistence/reconciliation; Lane D only provides derived File/PDF capability.
- Never infer physical-file ownership from a Vault-looking path. Only the closed ownership contract may authorize deletion.

## Current checkpoint — 2026-09-07

### Weblink
Core Weblink product semantics are established:
- canonical URL normalization/reuse;
- missing-only metadata enrichment;
- managed representative Image orchestration through canonical Relations;
- shared visual resolution;
- canonical open/copy native actions.

Recent hardening:
- #711 (`92e7166a9075c61df7f947d5fa9891041f7970b2`) prevented malformed Weblink MIME persistence.
- #743 (`42d0d04d…`) added canonical Weblink open/copy capability with system-Weblink identity gating, HTTP/HTTPS-only behavior and path/URL-safe errors.
- #751 (`7e3b9d9e…`) introduced shared strict MIME normalization.
- #768 (`dfeee7af…`) moved Weblink durable MIME metadata onto that shared normalizer.

The managed Bookmark visual host migration is effectively complete in the currently audited Bookmark detail/List/Table/card paths. Remaining #155 work is generic Weblink collection/detail polish and eventual safe retirement of legacy `bookmarks.url` / remote-thumbnail compatibility only after caller parity is proven.

### Image / Photo migration
Canonical Image behavior is mature:
- managed import/create and reuse;
- source provenance;
- portable stored-path identity;
- content-first classified import;
- persisted/fallback geometry;
- safe preview/edit/rotate/flip/restore/crop behavior;
- ownership/shared-file guards;
- Weblink representative media integration.

Recent hardening:
- #718 is merged (`82e9b91294ee39b7105d4b84c01ff50d92521515`); it is no longer active.
- #764 (`45c5bf98…`) moved Image durable MIME metadata onto the shared strict MIME contract.
- #783 (`1b3e029f…`) makes remote managed Image extension follow HTTP `Content-Type` while preserving URL filename provenance.

#245 position:
- Phase 1 canonical Image import/create is established.
- Phase 2 Photo -> Image mirroring/promotion is established through stable `photo_object_links`, exact-file reuse, missing-file safety and native-Image survival semantics.
- Bookmark `Images` / `Cover Image` canonical Relations are established.
- Remaining major work is Phase 4+ host/write-authority parity: generic Object detail/List/Table presentation and replacing legacy Bookmark/People `PhotoRecord` write authority before hiding/removing legacy `写真`.
- `CoreObjectBridge` intentionally keeps its special relative-path/no-profile-root compatibility rule. Do not mechanically replace it with a normal filesystem existence resolver.
- Do not remove `Photos`, `BookmarkPhotos`, `Person.profilePhotoId`, `PhotoManagementPage`, or `photo_database_picker.dart` until production callers/write parity are explicitly proven.

### Canonical File / shared file-backed capability
Canonical File is now a production-capable primitive rather than a schema-only foundation.

Established behavior includes:
- managed/Vault-relative stored-path identity;
- original filename, MIME/content type, extension/size/imported timestamp and optional SHA-256 metadata;
- canonical open/reveal/export;
- missing-file-safe resource projection;
- PDF metadata/preview/page-count/text capability behind canonical File identity;
- typed Storage ownership metadata;
- safe shared-reference-aware physical deletion.

Key integrated slices:
- #512 (`29cc878f…`) — canonical File primitive + shared managed-file resolver/capability foundation.
- #553 (`4a0c53fc…`) — canonical File open/reveal capability.
- #557 (`702a2278…`) — PDF metadata capability on canonical File.
- #682 / #702 / #704 — canonical File identity gate for File/PDF native capability.
- #750 (`fedcceb49463ac05dfa64f338620207f65bdf5b2`) — Lane F Vault-managed arbitrary-file copy + explicit `vault-managed-copy-v1` ownership receipt + receipt-scoped rollback.
- #771 (`3f3c63c024f6885c32f38fce94253ac368787857`) — Lane F ownership-gated physical delete boundary.
- #778 (`eb2f0e6d1ca06feefb2664e20407e21622d5f0a4`) — production generic File import composition: Vault copy -> canonical File creation -> rollback on downstream failure.
- #788 (`eea8e52ddb014f5e0c444ca605ee3db75000cf6e`) — typed ownership persisted on canonical File Objects and projected through the shared file-backed resource boundary.
- #794 (`49eb9ffeec19be163b32a079d2882bc7e7799968`) — two-phase shared-reference-aware physical deletion. Surviving canonical/custom File Properties, canonical Image refs, or legacy Photos preserve shared bytes.
- #798 (`fc04b1db72491b10d729327b97f6764c5d81e685`) — SHA-256 metadata derived from the managed copy. Hashing is fail-soft and **does not redefine File identity**.
- #804 (`58dc3923d19489ec030a83ef83bffcc88fd90970`) — safe generic File collection import contract and picker-facing preflight.

File identity contract remains stored-path based. Reimporting the same external source creates a distinct managed path and distinct File Object even when SHA-256 matches. The matching hash is metadata, not an implicit content-addressed identity/dedup rule.

### MIME/content import routing
`PrimitiveObjectImportService` is the canonical Image/File decision boundary:
- validates an existing regular-file source;
- classifies once with precedence `strong content signature > meaningful declared MIME > extension fallback`;
- invokes exactly one selected importer;
- selected-importer failure never falls through to another primitive.

Integrated hardening:
- #528 (`735c8be7…`) — exclusive Image/File primitive router.
- #569 — content-classified Image import no longer trusts a misleading source extension for the managed copy.
- #739 (`c9a56245…`) — malformed MIME shapes such as `image/`, `/png`, `image/png/extra` and `image / png` no longer count as MIME evidence.
- #751 (`7e3b9d9e…`) — shared `MimeTypeNormalizer` centralizes durable/runtime MIME validity.
- #764 / #768 — Image/Weblink durable metadata adopt the same strict normalizer; File already uses it.
- #778 / #798 — generic File production import, ownership, rollback and SHA metadata are live.
- #804 — picker-facing File import preflights **all** selected sources before mutation. If any source classifies as supported Image, the whole File-collection action fails before Vault copy/Object creation, preventing partial or wrong-primitive imports. PDF bytes disguised with an image extension still route to File.

The former “generic File import is blocked on Lane F managed-copy/ownership” statement is obsolete. #750/#771 delivered that dependency and Lane D consumes it on main.

### PDF-on-File
PDF remains canonical File. Existing services provide:
- content-verified PDF metadata;
- transient preview bytes / Quick Look style preview path;
- page count;
- text extraction;
- derived Search text integration;
- normal File open/reveal/export.

No PDF ObjectType, PDF table or parallel PDF search/storage route exists.

### Tag
`TagObjectBridge` keeps Tag on canonical Object storage. Parent hierarchy uses the canonical self-Relation path; there is no parallel tag-edge persistence.

Native Tag name uniqueness/identity remains intentionally undefined. Do not invent uniqueness semantics without an explicit product contract. Relation integrity belongs to Lane B.

## Validation / CI
All referenced implementation PRs above were merged only after their relevant normal Flutter CI succeeded unless otherwise noted by the PR itself. In this run:
- #804 final head passed maintainability guards, Drift generation, Analyze and the full Flutter test suite before merge.
- The connector runtime has no local Flutter/Dart execution; CI is the executable validation source.

## Hotspot / concurrency state
Current active hotspot lease:
- Lane C draft PR #808 (`feature/database-view-relation-value-quick-create-491`) owns `GenericDatabasePage` / `GenericDatabasePageServices` and is wiring real Relation quick-create for custom/Tag/Weblink/Image/File targets, including Image/File native source selection and content-first primitive import.

Therefore Lane D must **not** concurrently edit those host regions. #804 deliberately supplies lower-level File affordance/import contracts without editing the large host.

Other shared hotspots (`object_inspector_page.dart`, Bookmark/People/Photo management hosts, `app_shell.dart`, `app_database.dart`) require a fresh open-PR ownership audit before any non-trivial edit.

## Exact next actions
1. Let Lane C #808 finish/merge its current `GenericDatabasePage` / `GenericDatabasePageServices` lease. Re-audit after merge before any File collection real-host wiring.
2. After #808, connect `requiresManagedFileImport()` + `GenericDatabaseFileImportService.importPickedFiles(...)` into the generic File collection host only if Lane C has not already provided equivalent composition. Keep the host patch-sized.
3. Re-audit #484 acceptance after File host wiring. Core File/PDF identity, metadata, ownership, import, actions and delete safety are already implemented; remaining architecture close work is mostly composability/presentation across lanes.
4. Continue #245 only where legacy Photo replacement parity is explicit. Highest-value remaining work is canonical Image detail/List/Table host parity and Bookmark/People write-authority migration; do not hide `写真` prematurely.
5. Continue #155 only for generic Weblink collection/detail polish or caller-zero legacy URL/remote-thumbnail retirement. Do not add a second Weblink page or persistence path.
6. Keep #495 changes limited to concrete routing/import ambiguities. The core content-first router, Image/File production import and strict MIME contract are established.
7. Keep Tag hierarchy on canonical Relation APIs and defer native Tag uniqueness semantics until explicitly specified.

## Cross-lane dependencies / blockers
- **Lane C:** current #808 hotspot lease blocks independent Lane D edits to `GenericDatabasePage` / `GenericDatabasePageServices`; this is the only immediate implementation conflict for generic File host wiring.
- **Lane F:** no current generic File blocker. #750/#771 provide managed copy, explicit ownership, rollback and physical-delete filesystem boundaries. Future Vault/profile lifecycle changes remain Lane F-owned.
- **Lane B:** owns Relation lifecycle correctness for primitive-producing workflows such as #808 quick-create.
- **Lane E:** owns search index persistence/reconciliation; Lane D owns only PDF/File extraction behavior.

## Run checkpoint
Latest Lane D implementation merged in this run: #804, squash merge `58dc3923d19489ec030a83ef83bffcc88fd90970` after full Flutter CI green.

Current handoff branch: `docs/primitives-handoff-2026-09-07`.

Stop reason for this checkpoint: the next high-value generic File host change overlaps Lane C #808's active shared-hotspot lease. Independent core File/MIME/ownership/import work for #484/#495 is already implemented; further safe work should focus on #245/#155 parity slices only after a fresh caller/hotspot audit rather than inventing speculative abstractions.

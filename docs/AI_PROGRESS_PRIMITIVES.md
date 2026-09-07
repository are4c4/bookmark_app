# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, `docs/AI_PROGRESS.md`, active issues, and current open PR/CI state before editing. Recheck Object/Relation/Database/Storage/Refactor ownership before touching shared hotspots.

## Lane goal
Provide built-in Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined domain schemas without parallel persistence systems.

## Primary active issues
- #155 — reusable Weblink identity/metadata/media and legacy Bookmark convergence.
- #245 — legacy Photo -> canonical Image migration.
- #484 — primitive boundary and canonical File.
- #489 — capability-oriented shared native behavior.
- #495 — MIME/content-aware Image/File import routing.

## Product contract / lane boundary
Image and File remain distinct ObjectTypes while sharing managed-file/native capability infrastructure. PDF remains a File Object with optional preview/metadata/page-count/text behavior; no PDF-specific storage model is allowed.

Lane C owns generic Database/View settings/hosts. Lane B owns Relation lifecycle integrity. Lane F owns Vault/filesystem lifecycle, managed-copy ownership, backup/restore and storage switching. Lane E owns search indexing; Lane D only supplies derived File/PDF capability.

Do not infer File byte ownership from path location. Generic File physical deletion remains blocked until Storage supplies an explicit ownership grant.

## Current checkpoint — 2026-09-07

### Weblink
`WeblinkObjectService` owns canonical URL normalization/reuse and missing-only metadata enrichment. Merged #634 resolves relative OpenGraph/favicon resources against the final redirected response URL while preserving requested-URL identity. Enrichment remains fail-soft.

Merged #693 (`335a9c49fcbe4cba875aa31d3b84e59f92a00430`) keeps `WeblinkVisualResolver` responsible only for fail-closed, read-only Representative Image Relation selection and delegates the target Image's managed path/existence/persisted geometry read to the existing `ImageVisualResolver`. It uses `probeMissingGeometry: false`, preserving Weblink cards' previous persisted-metadata-only behavior without introducing image-byte decoding. Flutter CI #2169 passed guardrails, Drift generation, Analyze and the full test suite before merge.

Merged #711 (`92e7166a9075c61df7f947d5fa9891041f7970b2`) closes a missing-only Weblink MIME poisoning gap. `WeblinkObjectService` now rejects malformed non-MIME content-type strings before persistence while preserving lowercase/parameter stripping and non-empty existing metadata. A focused regression proves `not-a-mime` stays missing and a later valid `Text/HTML; charset=UTF-8` enrichment fills the same Weblink as `text/html`. Flutter CI #2247 passed guardrails, Drift generation, Analyze and the full test suite before merge.

### Image / Photo migration
Canonical Image import/provenance/geometry/editing/deletion safety is established. Merged #652 canonicalized legacy Photo paths through the active profile/Vault resolver. Merged #675 (`08d46d599c717b57f608159c5b106e836034e911`) aligned native Image creation/reimport with the same portable stored-path identity while preserving historical non-empty absolute values and external absolute references.

Merged #692 (`91824121156fbfebfa260b09d80e604d5923d8ab`) adopted the shared `ProfilePathResolver.canonicalStoredPath(...)` operation inside `ImageObjectService`, removing its remaining duplicate `resolveStoredPath -> toStoredPath` composition while preserving Image-specific empty-path validation, managed absolute/relative convergence, external absolute references, source provenance and concrete Image identity. Flutter CI #2159 passed maintainability guardrails, legacy dependency guard, Drift generation, Analyze and the full test suite before merge.

Current PR #718 (`fix/primitives-image-mime-enrichment-495`) closes the Image counterpart of the missing-only MIME poisoning gap. It normalizes `contentType` before persistence with trim/lowercase/parameter stripping and a basic MIME slash check, matching canonical File behavior without restricting values to `image/*` or changing routing/identity. The focused regression proves `not-a-mime` remains missing, equivalent managed-path reimport reuses the same Image Object, and later `Image/PNG; charset=binary` enriches to `image/png`. Production/test were refreshed onto latest main as `9ff851ced0c8c01d4799af5587a75e9f8aec53ae`; this handoff commit follows that refresh.

Legacy Photo migration remains compatibility-sensitive. `CoreObjectBridge` intentionally retains its special relative-path/no-profile-root gate; replacing it mechanically with `ManagedFileResolver.resolveExisting(...)` would change migration semantics. Refactor #695 merged as `a2d22e89792ea4d46abe030bc56e1c7910c5fe60`, retiring four temporary Photo Database-presentation shim imports and ratcheting the legacy-import guardrail. Do not hide/remove legacy Photo persistence or navigation until Bookmark/People authority and write parity are proven.

### Canonical File / shared managed-file capability
Canonical File identity/metadata, open/reveal/export and deterministic path-based reimport are established. Merged #671 (`26600dbafb119b35f5e33ceb48217a8535603714`) proves File Object deletion preserves physical bytes without an explicit Storage ownership grant.

Merged #679 (`f2782dd860ded896cd8d6eb5ddb6bc66015a1a30`) centralized portable stored-path identity as `ProfilePathResolver.canonicalStoredPath(...)` and exposed the operation through `ManagedFileResolver`.

Merged #682 (`7cee922adf82d7daf15c4b44657b6b77d266d0f2`) added `CanonicalFileManagedResourceResolver`, preventing native File/PDF capability from activating on arbitrary custom ObjectTypes that merely contain a File-shaped Property.

Merged #688 (`792fb4d58701785dba2f4d9768c6f2cf1fe363a6`) adopted the shared `canonicalStoredPath(...)` operation inside `FileObjectService`, removing duplicate path composition while preserving File-specific validation and identity. Flutter CI #2147 passed maintainability guardrails, legacy dependency guard, Drift generation, Analyze and the full test suite before merge.

Merged #697 (`48eaa34747925f760a4f30231565d989915576ca`) closed a missing-only File metadata gap: path-identity reuse now fills a missing `Imported at` while preserving any non-empty earlier timestamp. Flutter CI #2180 passed guardrails, Drift generation, Analyze and the full test suite before merge.

Merged #702 (`bd0ec996ce87f8e01e9834c6e57b7e2b3c7a42c2`) requires `CanonicalFileManagedResourceResolver` at the `CanonicalFileActionService` and `CanonicalFileExportService` API boundary. Native open/reveal/export therefore cannot be accidentally activated for a custom File-shaped ObjectType by passing the low-level structural resolver. Flutter CI #2202 passed guardrails, Drift generation, Analyze and the full test suite before merge.

Merged #704 (`c7055cff8e8ffd2e5b68191efd753cb6c7959284`) extends the same canonical File identity gate to PDF metadata/preview/page-count/text services. The four PDF-native services now require `CanonicalFileManagedResourceResolver`; content-first classification and derived read-only behavior are unchanged. Flutter CI #2218 passed guardrails, Drift generation, Analyze and the full test suite before merge.

Merged #709 (`b0e5852cc5cd4b14e0b5b97ca07c12c79a19e176`) closes the File counterpart of the missing-only MIME poisoning gap. `FileObjectService` now applies the same basic MIME-shape check used by the classifier after trim/lowercase/parameter stripping. Malformed input stays missing so a later equivalent-path reimport can enrich the same File Object with a valid MIME. Flutter CI #2239 passed guardrails, Drift generation, Analyze and the full test suite before merge.

### MIME/content import routing
`PrimitiveObjectImportService` validates a real regular-file source, classifies it content-first and delegates exactly once to Image or File; selected-importer failures never fall through.

Merged #665 expanded strong signatures for common non-Image/unsupported-Image formats. Merged #684 (`aa0eefe5be1da730a7af94f0b26c7a6cdd58659f`) closes the existing-path extension-only gap: if real source bytes do not identify a supported Image and routing evidence falls back only to filename extension, production path import fails closed to generic File. Direct classifier extension fallback remains available when content is genuinely unavailable. #684 CI #2134 passed before merge.

#709, #711 and current #718 harden durable primitive metadata only; none changes routing target selection or content-first classification precedence.

End-to-end generic File import remains intentionally blocked on a Lane F-owned managed-copy + explicit ownership seam for arbitrary source files. Lane F PR #691 changes Vault move/reopen migration behavior and does not provide that seam. Lane D must not duplicate attachment/Vault copy/delete lifecycle or create a second managed-file root.

### PDF-on-File
PDF remains canonical File. Available capability services cover content-verified metadata, transient Quick Look preview bytes, Spotlight text extraction, page count, Search-derived text projection, and File open/reveal/export. No separate PDF persistence/search/storage route exists.

Merged #704 makes the canonical File identity gate mandatory at the PDF capability API boundary. Search composition already used `CanonicalFileManagedResourceResolver`, so no search persistence/index contract changed.

### Tag
`TagObjectBridge` keeps built-in Tag on canonical Object storage; parent hierarchy is a normal self-Relation through canonical Relation APIs. Native Tag name uniqueness/identity remains intentionally undefined until product semantics are explicit.

Refactor #705 removed the duplicate legacy `AppDatabase` tag-hierarchy mutation path in favor of `TagGroupStore.moveTag(...)`; this does not change Lane D Tag Object identity or Relation semantics.

## Validation / CI
Recent Lane D merges #665, #671, #675, #679, #682, #684, #688, #692, #693, #697, #702, #704, #709 and #711 passed normal Flutter CI before integration. #688 CI #2147, #692 CI #2159, #693 CI #2169, #697 CI #2180, #702 CI #2202, #704 CI #2218, #709 CI #2239 and #711 CI #2247 passed guardrails, Drift generation, Analyze and full tests.

Local Flutter/Dart execution is unavailable in the connector-only runtime. #718's pre-refresh CI was green, but the refreshed final head requires normal Flutter CI including this handoff commit before integration. No local test result is claimed.

## Hotspot / concurrency state
No shared hotspot lease is required for #718. The current slice touches only `ImageObjectService`, its focused test and this lane handoff. The latest open-PR audit found no competing owner for `ImageObjectService`; shared presentation hosts remain active cross-lane territory.

`SystemObjectListMedia` already provides reusable canonical Image/Weblink leading media, but the live `GenericDatabasePage` List host still uses a fixed document icon. Lane D should coordinate a patch-sized host integration with Lane C rather than broadly rewriting that shared page. `ObjectImageDetailPanel` likewise remains reusable but live `ObjectInspectorPage` integration is a shared Object hotspot and needs a fresh ownership audit before editing.

Lane F #691 remains storage-migration-only and still does not provide the generic managed-copy/ownership seam. Lane C and active Object/Relation/Refactor work do not own primitive data services. Avoid `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `people_management_page.dart`, `photo_management_page.dart`, Relation internals and Vault lifecycle code unless a fresh ownership audit proves a patch is safe.

## Exact next actions
1. Require green normal Flutter CI on final #718 head; if green and mergeable, integrate it.
2. After #718, re-audit primitive metadata/native capability consumers only for another concrete fail-open or missing-only enrichment defect; do not add speculative abstractions.
3. Continue #495 only for concrete classification ambiguities. End-to-end File import waits for the Lane F managed-copy/ownership contract.
4. Coordinate with Lane F on File managed-copy + explicit ownership before generic File import/delete lifecycle.
5. Coordinate with Lane C for generic File import/create UX and File/Image/Weblink presentation hosts rather than reconstructing Database/View hotspots from Lane D.
6. Continue #245 Photo retirement and #155 legacy Weblink retirement only where replacement parity is proven and hotspot ownership is clear.
7. Keep Tag hierarchy on canonical Relation APIs; defer native Tag uniqueness semantics until explicitly defined.

## Cross-lane dependencies / blockers
- Lane F: managed-copy location, ownership grant, delete/move semantics, Vault portability/recovery.
- Lane C: generic Database/View File import/create and presentation UX.
- Lane B: Relation lifecycle correctness for primitive-producing Relation workflows.
- Lane E: Search owns index persistence/reconciliation.

Pending CI alone is not a stop condition; independent primitive service/domain/test work should continue when available.
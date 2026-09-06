# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` first. Recheck current Object/Storage/Refactor PR ownership before editing shared media/storage code.

## Lane goal
Provide a small set of built-in primitive ObjectTypes whose irreducible native behavior can be composed by user-defined domain schemas.

## Primary active issues
- #155 — Weblink reusable Object and legacy Bookmark URL/media convergence.
- #245 — legacy Photos -> canonical Image Objects.
- #484 — built-in primitive boundary and canonical File Object.
- #489 — capability-oriented shared native behavior.
- #495 — MIME/content-aware import routing to Image or File.
- #481 only where primitive detail composition must expose the universal Body owned by Object Core.

## Product contract
Built-in primitives currently target:
- Weblink
- Image
- File
- Tag

Daily Note is a special workflow, not a general media primitive. Bookmark/Paper/Book/Project/etc. should normally be user-owned/template domain types.

## Owns
- Weblink URL identity/normalization/enrichment.
- Image identity/provenance/import/editing and Photo compatibility migration.
- Canonical File Object identity/import/open/reveal/export behavior.
- Shared managed-file/native capability services where domain-semantic.
- MIME/content classification and PDF/File enrichment behavior.
- Tag built-in defaults/quick-create semantics where not Relation-integrity work.

## Boundary with Storage lane
- Primitive lane owns Object identity/product semantics and capability contracts.
- Storage lane owns Vault/Profile directory lifecycle, filesystem portability, backup/restore, and storage-location switching.
- Shared managed-file path/ownership helpers require explicit coordination; do not create duplicate filesystem abstractions.

## Current implementation checkpoint
Canonical Image is already advanced: managed import/reuse, legacy Photo mirroring, Bookmark Images/Cover Image Relations, safe preview/edit ownership, rotate/flip/restore/crop and geometry fallback are integrated. Remaining work should focus on shared-host parity and legacy Photo write/navigation retirement, not another Image persistence model.

## Initial next actions
1. Finish patch-sized canonical Image real-host integration and generic List/Table media parity where no hotspot conflict exists.
2. Audit File/attachment infrastructure to design the canonical File primitive without duplicating Image storage ownership.
3. Define the shared file-backed capability seam with #489 and coordinate Vault-relative requirements with Storage lane.
4. Implement #495 only after canonical File creation/import semantics are concrete.
5. Continue #155 legacy retirement only after generic replacement paths are proven.

## Handoff checklist
Record active Issue, branch/PR/commit, tests, native capability/storage dependencies, hotspot ownership, exact next actions, and stop reason.

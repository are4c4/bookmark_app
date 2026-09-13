# ADR-0003: Compatibility paths retire only after proven replacement

- Status: Accepted
- Date: 2026-09-14
- Related Issues: #1039, #1040, #1041, #1042, #1044, #1045, #950
- Related docs: `docs/product_architecture.md`, `docs/architecture.md`

## Context

The repository contains historical Bookmark, People, and Photo schema/code while the target product converges on generic Object/Relation/Database contracts plus native Weblink/Image/File capabilities. Removing legacy paths early would simplify the codebase, but installed local-first data can contain fields, lifecycle state, relationships, managed-file references, or workflows that the replacement does not yet preserve.

Keeping legacy subsystems as permanent peers is also unsafe: it preserves dual authorities, encourages new callers, and makes the target architecture impossible to finish.

## Decision

Legacy Bookmark/People/Photo paths are compatibility infrastructure, not permanent product authorities. Retirement follows this order:

`replacement contract → daily-use parity → current-main caller-zero proof → preservation validation → explicit destructive schema/data migration when needed`.

Code/UI retirement and persisted schema/data retirement are separate steps. A caller-zero code path may be deleted only after its remaining migration/import/export/backup/preservation responsibilities are proven absent or deliberately retained elsewhere.

## Alternatives considered

### Immediate rewrite/delete once the target model exists

This reduces code quickly, but can silently drop user-authored state or break upgrade/restore paths that are not exercised by normal current-schema tests.

### Keep both old and new authorities indefinitely

This avoids short-term migration risk but creates permanent dual-write/reconciliation ambiguity and invites new dependencies on paths that were supposed to disappear.

### Rename legacy code without moving authority

This improves surface terminology without reducing architectural debt and can hide that the old persistence model is still authoritative.

## Consequences / constraints

- owning A–F lanes prove replacement parity; G performs focused caller-zero retirement only after that handoff;
- code search alone is not caller-zero proof: wrappers, real hosts, Analyze/Test, and preservation dependencies must be checked;
- destructive schema/data deletion requires its own preservation evidence, migration single-writer lease, and approval policy;
- temporary compatibility projections may remain after normal product routing moves away from them;
- no new feature should use a legacy path merely because it is convenient unless the compatibility requirement is explicit.

# ADR-0001: Global Object identity, contextual Database/View ownership

- Status: Accepted
- Date: 2026-09-14
- Related Issues: #56, #1048
- Related docs: `docs/product_architecture.md`, `docs/architecture.md`

## Context

The application began from a Bookmark-oriented model and accumulated domain-specific presentation/storage paths. As Database/View functionality expanded, a durable choice was required between keeping entity identity inside each domain/database context or giving entities one identity that can appear through many contexts.

Database-owned rows or per-domain copies are locally simple, but they make backlinks, cross-database references, deduplication, history, and generic detail UX ambiguous. They also encourage each new domain to recreate storage and presentation behavior.

## Decision

Every durable user-facing entity has one canonical Object identity inside a Vault. A Database selects an Object set/context and a View configures presentation/query behavior; neither owns or clones Object identity.

ObjectType answers what an Object is. Properties, Relations, Tags, Body, lifecycle state, and Database/query context describe the Object without creating competing identities. Weblink/Image/File may attach native capabilities while remaining Objects.

## Alternatives considered

### Keep Bookmark/domain entities as primary authorities

This matches the application's historical shape and can make one domain straightforward, but it keeps architecture centered on bespoke subsystems and makes cross-domain composition a migration/bridge problem indefinitely.

### Let each Database own its rows/entities

This resembles traditional table-centric applications, but the same conceptual item appearing in several Databases would need duplication or fragile synchronization. Stable backlinks and shared detail/history semantics become much harder.

## Consequences / constraints

- the same Object may appear in many Databases/Views without duplication;
- generic Database/View/Inspector behavior should compose around Object identity rather than rebuild per domain;
- duplicate detection does not imply automatic identity collapse;
- legacy Bookmark/People/Photo persistence may remain for compatibility, but must not become a second permanent authority;
- migrations must preserve ambiguous/unmapped user data rather than guessing a semantic ObjectType merely to fit the target model.

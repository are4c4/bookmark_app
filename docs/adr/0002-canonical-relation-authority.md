# ADR-0002: One canonical Relation authority

- Status: Accepted
- Date: 2026-09-14
- Related Issues: #56, #1048, #1045
- Related docs: `docs/product_architecture.md`, `docs/architecture.md`

## Context

Bookmarks, People, Tags, and newer generic Objects all need links between entities. It is tempting for each domain or UI to store its own target ids, join tables, serialized lists, backlinks, or tree structure because the local feature can then move quickly.

That convenience creates competing edge authorities. Once two stores can represent the same relationship, delete/retarget behavior, cardinality, ordering, backlinks, cycle prevention, reconciliation, and migration all become dual-write correctness problems.

## Decision

Typed Object relationships use the canonical Relation subsystem as the persistence and integrity authority. Domain roles, Person groups, Tag hierarchy, Object references, merge rewiring, and similar edges must compose that authority instead of creating parallel edge stores.

Specialized UX and derived indexes are allowed, but they are projections/consumers of canonical Relation state rather than alternative relationship authorities.

## Alternatives considered

### Domain-specific edge stores

A Person-group table or Tag-tree table can be easy to query in one feature, but it duplicates identity/integrity rules and requires permanent synchronization with generic Relations.

### Serialized ids in Property/UI state

This minimizes schema work initially, but weakens target validation, backlinks, ordering/cardinality guarantees, and safe deletion/retarget semantics.

### Dual-write canonical and legacy edge state indefinitely

Temporary compatibility projection can be necessary during migration, but treating both sides as peers makes reconciliation ambiguous and prevents caller-zero retirement.

## Consequences / constraints

- Relation mutation/read/index/backlink/audit/reconcile behavior remains behind one integrity boundary;
- cardinality, order, target validity, cycle/corruption handling, delete/detach/retarget, and retries must fail closed through that boundary;
- specialized pickers/trees/roles may exist without owning independent relationship persistence;
- temporary legacy projections need an explicit compatibility reason and retirement condition;
- refactors must not introduce a second edge authority merely to reduce coupling or simplify one caller.

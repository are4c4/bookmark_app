# Architecture Decision Records

This directory preserves the **reasoning behind durable, cross-cutting architecture decisions**. It complements the current contracts in `docs/product_architecture.md` and `docs/architecture.md`; it does not replace them.

## How to use ADRs

Architecture-changing work should consult this index and the ADRs relevant to the authority/model it would change. Ordinary feature, bug-fix, and behavior-preserving refactor PRs do **not** need to read every ADR.

Create an ADR only when all of these are true:

- the decision is durable and cross-cutting;
- plausible alternatives existed;
- a future maintainer or AI agent could reasonably choose a conflicting design without the rationale;
- recording the rationale will prevent meaningful re-analysis or architecture drift.

Do not use ADRs for transient PR ownership, current CI state, implementation trivia, or facts already obvious from the current constitution/code.

## Status and supersession

Use one of these statuses:

- `Proposed` — under active architecture discussion and not yet authoritative;
- `Accepted` — the historical decision was accepted and should be treated as rationale for the current architecture;
- `Superseded by ADR-XXXX` — a later explicit decision replaced it.

After an ADR is accepted, keep its historical decision/rationale immutable. Typo/link repairs and an explicit supersession note are allowed. A material architecture reversal should create a new ADR and mark the old ADR as superseded rather than silently rewriting history.

## Index

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-0001](0001-object-first-identity.md) | Accepted | Objects have global identity; Database/View provide context rather than ownership |
| [ADR-0002](0002-canonical-relation-authority.md) | Accepted | Relations use one canonical integrity authority instead of domain edge stores |
| [ADR-0003](0003-compatibility-retirement-sequence.md) | Accepted | Legacy Bookmark/People/Photo paths retire only after parity, caller-zero proof, and preservation |
| [ADR-0004](0004-undo-vs-durable-history.md) | Accepted | Local Undo and restart-safe durable History are separate contracts |

## Creating a new ADR

1. Copy [ADR-0000](0000-template.md) to the next numeric filename.
2. Link the focused Issue and the current architecture documents that establish the contract.
3. Keep the record short: context, decision, serious alternatives, and consequences/constraints.
4. Do not copy volatile GitHub state into the ADR.
5. If it replaces an accepted ADR, create the new record and add only a supersession note to the old record.

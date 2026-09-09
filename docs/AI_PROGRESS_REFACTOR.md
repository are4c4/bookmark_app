# AI Progress — Refactor & Architecture Health Lane

> Durable Lane G handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Reduce maintenance hotspots and duplicate/caller-zero legacy paths while preserving product behavior. Own architecture guardrails, CI/developer-loop health, repository-wide handoff alignment and small responsibility extraction/deletion. Do not hide product redesign inside refactor work.

## Current architecture responsibility
The Object-first product constitution is established. Lane G owns keeping repository instructions/handoffs and architecture guardrails consistent with it so future agents do not follow superseded Bookmark-centric or Tag-as-native-primitive routing.

Durable product implications for G:
- `Bookmark` is legacy compatibility/migration input, not a final ObjectType;
- Person is a generic ObjectType; dedicated People runtime/UI becomes removable only after owning-lane parity;
- Tag/TagGroup are generic ObjectTypes; no native-primitive routing for Tag;
- Weblink/Image/File are Objects with native capabilities;
- legacy UI/API/code deletion follows replacement parity + caller-zero proof;
- destructive schema/data retirement is a separate preservation-proven migration, not routine refactor work.

## Historical branch cleanup — completed policy
#1072/#1074/#1076 established and executed evidence-based historical branch cleanup. Proven merged refs and exact stale heads of closed-unmerged PRs were removed only after live SHA/PR checks; ambiguous refs were intentionally retained.

Durable retention policy:
- never delete the default branch, current default tip, open-PR heads, or recent/transient work through historical cleanup;
- `advanced-after-pr` retains work added after recorded PR heads and must not be auto-deleted;
- `no-pr-history` has no durable PR evidence proving intent/recoverability and must not be auto-deleted;
- ordinary merged PR heads rely on GitHub's native automatic head-branch deletion;
- any future historical cleanup starts with a new read-only live inventory and the narrowest proven reversible class.

Exact branch counts and current branch names are **not** durable handoff data. Recompute them live when needed.

## Active/future G routing

Always verify Issue state and active PR ownership live before taking work.

### #225 — architecture health umbrella
Continue measurable hotspot reduction, `AppDatabase` narrowing, explicit failure/privacy policy and CI/AI workflow guardrails through focused child Issues/PRs. Prefer deletion or responsibility movement over another abstraction layer.

### #950 — Photo caller-zero cleanup (completed checkpoint)
Safe caller-zero Photo mutation/presentation/read cleanup is complete. The surviving Photo-era paths are intentionally live compatibility/preservation infrastructure and must not be treated as spare cleanup merely to keep G active. Any future Photo code retirement requires a new focused current-main caller-zero proof; persisted Photo schema/data retirement is separately preservation-, migration-, and approval-gated.

### #1079 — durable AI documentation source-of-truth
Synchronize stale repository docs and make handoffs structurally resistant to transient-state drift. Durable docs record contracts/resume guidance; live GitHub owns open PRs, CI, branch tips, repository settings and current ownership.

### #1082 / #1107 — destructive-risk approval and enforcement trust root
Deterministic PR-contract failures and high-confidence destructive-risk detection are blocking. #1107 Phase A is established: a destructive/approval-sensitive PR requires a current-head `APPROVED` review from a distinct non-author GitHub User whose latest review state is evaluated across the complete paginated review history and whose repository permission is write/admin. Owner comments, PR-body markers, labels, self reviews, bot reviews, stale reviews and read-only reviewers are not approval authority.

The remaining #1107 security gap is Phase B, not approval provenance itself: repository-local PR-controlled GitHub Actions and guard code are still modifiable through the implementation authorization, so that authorization boundary is not yet independently immutable. #1107 stays open until a distinct external/reviewer/check identity, organization-level protection, or equivalent enforcement root exists that the implementation identity cannot modify or spoof. Routine reversible PRs remain approval-free.

Future G work after owning-lane parity:
- retire caller-zero Bookmark repositories/items/pages/bridges from #1039;
- retire caller-zero People-specific repositories/pages/bridges from #1040;
- revisit Photo compatibility only through a new focused current-main caller-zero audit rather than reopening completed #950;
- ratchet maintainability ceilings as large hosts/dependencies genuinely disappear.

## Established guardrails that remain authoritative
- maintainability report/regression ceilings;
- no-new-legacy and presentation/database boundary checks;
- hunk-aware changed-Dart formatting;
- full Flutter Test sharding + Drift generated-code cache;
- test-health/flake artifacts;
- docs-only CI fast path and stable `merge-gate`;
- `merge_group` workflow support;
- repository-pinned Flutter toolchain via `pubspec.yaml`, tracked `pubspec.lock`, and machine checks that `flutter pub get` does not drift the committed lockfile;
- AI PR lane/Issue/dependency/hotspot/migration-impact contract with deterministic violations blocking;
- hotspot overlap/stale-base/churn diagnostics;
- duplicate focused-Issue ownership detection;
- deterministic migration single-writer hard gate: non-migration PRs pass without ownership arbitration, the lowest-numbered open migration PR is the unique active owner, later migration PRs block, and the check runs inside the required quality/`merge-gate` path;
- high-confidence destructive-risk detection is blocking, and Phase A machine-strong non-self approval requires a distinct current-head approved User with write/admin permission and complete review-history evaluation; Phase B enforcement-root immutability remains open under #1107;
- read-only repository-settings drift audit on PR, scheduled and manual runs for the observable effective default-branch integration contract; administration-only fields are validated when GitHub exposes them, but API omission is not guessed as drift and no privileged administration credential is introduced merely for exhaustive auditing;
- focused implementation Issue Form requiring Primary lane, Goal, Depends on, Shared hotspots, Migration/data impact, Acceptance and Non-goals;
- durable handoff audit;
- immutable GitHub Actions SHA pin audit;
- weekly Dependabot updates for Dart/pub and GitHub Actions;
- evidence-based historical branch cleanup and read-only ambiguous-ref inventory.

Do not relax a guardrail or create no-op commits to make unrelated work easier to merge.

## Durable-document policy

G owns repository-wide developer-workflow/handoff hygiene when a focused Issue owns the edit.

- Architecture semantics belong in `docs/product_architecture.md` / `docs/architecture.md`.
- AI process/concurrency rules belong in `AGENTS.md`.
- `AI_PROGRESS*.md` records durable contracts, completed checkpoints, dependencies/blockers that remain meaningful, and exact resume actions.
- Focused acceptance criteria belong in Issues.
- Current open PRs, branch tips, CI run IDs, live ruleset/settings values and transient ownership must be queried from GitHub rather than copied into handoffs as long-lived truth.
- Prefer deleting duplicated volatile values (for example a schema version in README) over creating a synchronization burden.
- Machine-certifiable drift belongs in CI/guards; semantic drift belongs in H oversight.

## Caller-zero proof standard
Code search alone is insufficient. A deletion slice should prove:
1. current-main production caller inventory;
2. wrapper/facade chain to real hosts;
3. replacement parity/compatibility ownership;
4. Analyze success to catch missed static callers;
5. relevant/full Flutter Test green;
6. no migration/import/export/backup/preservation dependency was accidentally treated as dead.

## Shared hotspots
High-risk hosts include `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart`, `people_management_page.dart`, `app_shell.dart`, `tag_management_page.dart` and `app_database.dart`.

Recheck live PR ownership before broad edits. G should usually reduce a hotspot by small extraction/deletion rather than taking a broad rewrite lease. Schema/migration writer remains single-writer and is now enforced by the deterministic blocking gate.

## Cross-lane boundaries
- **A:** Object/ObjectType/Body identity and migration semantics.
- **B:** Relation integrity and Tag hierarchy correctness.
- **C:** Database/View/schema/query UX and replacement daily-use surfaces.
- **D:** Weblink/Image/File native semantics/capture.
- **E:** Search/FTS semantics.
- **F:** Vault/filesystem/preservation semantics.
- **H:** repository-wide architecture/integration oversight; routes concrete implementation back to one owning lane.

G deletes superseded implementation only after the owning product/integrity lane proves replacement parity.

## Repository integration contract
`main` is protected by the active repository ruleset and integrates through PRs with strict/up-to-date `merge-gate`; #980 is completed. Automatic deletion of ordinary merged PR head branches is enabled.

Critical observable integration invariants are also checked by a read-only repository-settings audit. The audit intentionally distinguishes real drift from fields omitted by non-privileged GitHub API payloads; exact current ruleset/settings values remain live GitHub state rather than durable handoff prose.

## Validation
Behavior-preserving refactors require changed-Dart format, Analyze and relevant/full Flutter Test. Workflow/guard changes must exercise focused regressions and the authoritative CI path. Docs-only architecture synchronization uses the docs-only CI path plus handoff/coordination audits.

## Resume sequence
1. re-audit latest `main`, open PR ownership and shared-hotspot/migration ownership before taking new G work;
2. treat #1107 Phase A non-self approval as established; do not treat #1082 as complete until Phase B provides an enforcement root the implementation identity cannot modify/spoof;
3. take #225/#1047 or other live G work only through focused reversible child Issues; treat #950 as a completed checkpoint rather than an active work queue;
4. when #1039/#1040 owning-lane parity lands, create caller-zero retirement slices instead of combining product migration with cleanup;
5. if historical branch cleanup is revisited, begin with a new read-only inventory and do not broaden deletion to ambiguous refs;
6. keep destructive schema/data removal separate, preservation-gated, and independently approved;
7. keep durable docs free of transient snapshots and route machine-certifiable drift to CI while H handles semantic drift.

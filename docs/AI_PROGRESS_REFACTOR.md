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

### #1079 — durable AI documentation source-of-truth (completed checkpoint)
#1079 established the durable source-of-truth split: repository docs record stable contracts and resume guidance, while live GitHub owns open PRs, CI, branch tips, repository settings and current ownership. Future documentation-drift work must come from a live focused Issue rather than treating #1079 itself as an active work queue.

### #1082 / #1107 — destructive-risk approval and enforcement trust root
Deterministic PR-contract failures and high-confidence destructive-risk detection are blocking. #1107 Phase A is established: a destructive/approval-sensitive PR requires a current-head `APPROVED` review from a distinct non-author GitHub User whose latest review state is evaluated across the complete paginated review history and whose repository permission is write/admin. Owner comments, PR-body markers, labels, self reviews, bot reviews, stale reviews and read-only reviewers are not approval authority.

The remaining #1107 security gap is Phase B, not approval provenance itself: repository-local PR-controlled GitHub Actions and guard code are still modifiable through the implementation authorization, so that authorization boundary is not yet independently immutable. #1107 stays open until a distinct external/reviewer/check identity, organization-level protection, or equivalent enforcement root exists that the implementation identity cannot modify or spoof. Routine reversible PRs remain approval-free.

### #1208 — repository `GITHUB_TOKEN` PR self-mutation boundary (completed checkpoint)
#1208 proved a separate workflow-trigger/identity failure mode: a temporary Actions workflow granted `contents: write`, committed as `github-actions[bot]`, and pushed directly back to an open same-repository PR branch with the repository `GITHUB_TOKEN`. The resulting `pull_request` workflow runs were approval-required and created no runnable jobs until a write user approved them. This was not a Flutter CI defect or branch-protection failure.

Durable contract:
- normal AI-assisted PR branch updates must use the connected GitHub/user-authorized branch-update path, not a repository Actions workflow that self-mutates the active PR branch;
- PR-specific workflows that combine `contents: write` with branch `git push` remain a deterministic coordination violation and are blocked by the existing repository guard/test contract;
- zero-job / approval-required workflow runs are not successful validation and must never be reinterpreted as green merely to unblock merge;
- do not introduce a PAT or separate GitHub App credential solely to evade this protection. If an exceptional product/developer workflow genuinely requires autonomous PR self-updates, define its credential/security boundary in a separate focused Issue;
- this completed trigger/identity boundary does **not** solve #1107 Phase B. A distinct enforcement root that repository-controlled implementation code cannot modify/spoof remains a separate open security requirement.

### #1127 — effective-current-base PR classification (partial checkpoint)
PR #1250 completed the CI-scope half of #1127. For `pull_request` runs, `tool/classify_ci_scope.py` now treats the checked-out synthetic PR merge as the effective landing-diff authority only after fail-closed identity proof: local `HEAD` must equal `GITHUB_SHA`, the checkout must have exactly two parents, and the second parent must equal the event PR head. Scope classification then uses `HEAD^1 -> HEAD`, so stale creation-time base history no longer determines docs-only/full-CI selection. Focused regressions cover stale event base, checkout mismatch, malformed merge shape, wrong second parent and missing identity metadata; the real CI-scope path, developer diagnostics, Analyze, four Flutter Test shards, test-health and required merge-gate all passed before integration.

#1127 remains open because `tool/pr_coordination_guard.py` still needs the same effective landing-diff semantics for changed-path/hotspot checks and destructive-risk classification. That remaining slice must **separate landing-diff refs from the real PR head SHA used for current-head approval identity**; replacing `CI_HEAD_SHA` wholesale with the synthetic merge SHA would weaken/break Phase A approval semantics. Do not create a wrapper or parallel coordination authority to avoid the canonical guard.

The guard/test pair is approval-sensitive and must not be edited concurrently with another active owner. Recheck live ownership before resuming #1127; once ownership clears, take the remaining guard slice from latest main and keep #1127 open until its coordination/destructive-risk acceptance is proven.

### #1087 — CI Performance Phase 2 (completed checkpoint)
Duration-aware full-suite execution is established. The required Flutter Test path uses exactly four jobs with deterministic **file-level** assignment instead of Flutter's built-in test-case sharding.

Durable execution contract:
- a compact repository-owned historical file-weight snapshot is versioned/integrity-checked and is planning input, not canonical test inventory;
- every run discovers the current `test/**/*_test.dart` inventory and assigns each current file exactly once across four deterministic LPT bins;
- unknown/new test files receive a deterministic fallback weight and are never omitted because history is stale;
- each shard re-verifies the saved plan against the current inventory immediately before execution and fails closed on missing/duplicate/extra files;
- runner count remains four; `fail-fast: false`, per-test timeout, first-pass failure authority, identical failed-shard diagnostic rerun, Drift generated-code cache behavior, per-shard/per-file timing, test-health and required `merge-gate` remain intact;
- normal PR coverage is never changed-files-only, quarantined, selectively optional or weakened for speed;
- the file-level cutover was adopted only after repeated cache-hit measurements showed a material critical-path and total-test-work reduction versus the built-in four-shard path;
- rollback is workflow/tooling-only: if future evidence shows coverage, reliability or performance regression, restore the built-in execution command while retaining useful timing/planner diagnostics.

Slow-test work remains evidence-backed rather than activity-driven. After the file-level cutover, the stable leading files are mostly intentional real-host Generic Database/AppShell widget/integration regressions with in-memory persistence and settled UI transitions. Do not split/combine/weaken them merely because they top the timing table. #1163/#1164 removed one genuinely unused fixture from a Bookmark error test, but the measured timing change was not material; retain it as responsibility cleanup, not as performance evidence. Create future slow-test PRs only when current timing plus source inspection identifies a concrete safe cost that can be removed without reducing assertion strength or isolation.

Future G work after owning-lane parity:
- retire caller-zero Bookmark repositories/items/pages/bridges from #1039;
- retire caller-zero People-specific repositories/pages/bridges from #1040;
- revisit Photo compatibility only through a new focused current-main caller-zero audit rather than reopening completed #950;
- ratchet maintainability ceilings as large hosts/dependencies genuinely disappear.

## Established guardrails that remain authoritative
- maintainability report/regression ceilings;
- no-new-legacy and presentation/database boundary checks;
- hunk-aware changed-Dart formatting;
- deterministic duration-aware file-level 4-shard full Flutter Test execution with exact-once current-inventory verification, deterministic fallback for unknown files, and Drift generated-code cache;
- test-health/flake artifacts and advisory per-file slow-test timing;
- docs-only/full-CI scope for pull requests is classified from the verified synthetic current-base landing diff, failing closed when checkout identity cannot be proven;
- docs-only CI fast path and stable `merge-gate`;
- `merge_group` workflow support;
- repository-pinned Flutter toolchain via `pubspec.yaml`, tracked `pubspec.lock`, and machine checks that `flutter pub get` does not drift the committed lockfile;
- AI PR lane/Issue/dependency/hotspot/migration-impact contract with deterministic violations blocking;
- hotspot overlap/stale-base/churn diagnostics;
- duplicate focused-Issue ownership detection;
- PR-branch self-mutation protection: repository Actions must not grant `contents: write` and `git push` back into active PR branches as an AI repair/update mechanism; use normal user-authorized branch updates instead;
- deterministic migration single-writer hard gate: non-migration PRs pass without ownership arbitration, the lowest-numbered open migration PR is the unique active owner, later migration PRs block, and the check runs inside the required quality/`merge-gate` path;
- high-confidence destructive-risk detection is blocking, and Phase A machine-strong non-self approval requires a distinct current-head approved User with write/admin permission and complete review-history evaluation; Phase B enforcement-root immutability remains open under #1107;
- read-only repository-settings drift audit on PR, scheduled and manual runs: active branch ruleset details are inspected and uniqueness is required only among rulesets targeting `~DEFAULT_BRANCH`; normal Actions runs authenticate reads with the ordinary read-only token while local/manual execution may fall back to unauthenticated reads; audit unavailability remains fail-closed and is distinguished from actual settings drift; administration-only fields are validated when GitHub exposes them, but omission is not guessed as drift and no privileged administration credential is introduced merely for exhaustive auditing;
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

Critical observable integration invariants are also checked by a read-only repository-settings audit. The audit selects the unambiguous active ruleset targeting the default branch rather than requiring it to be the repository's only active branch ruleset, authenticates normal Actions reads with the ordinary read-only token, distinguishes audit unavailability from actual drift while failing closed in either case, and intentionally distinguishes real drift from administration-only fields omitted by non-privileged GitHub API payloads. Exact current ruleset/settings values remain live GitHub state rather than durable handoff prose.

## Validation
Behavior-preserving refactors require changed-Dart format, Analyze and relevant/full Flutter Test. Workflow/guard changes must exercise focused regressions and the authoritative CI path. Full Flutter Test currently means the deterministic exact-once four-file-list path above, not the retired built-in test-case shard flags. Docs-only architecture synchronization uses the docs-only CI path plus handoff/coordination audits.

## Resume sequence
1. re-audit latest `main`, open PR ownership and shared-hotspot/migration ownership before taking new G work;
2. treat #1107 Phase A non-self approval as established; do not treat #1082 as complete until Phase B provides an enforcement root the implementation identity cannot modify/spoof;
3. treat #1208 as a completed trigger/identity checkpoint: do not recreate repository-`GITHUB_TOKEN` PR self-mutation or weaken required checks to make zero-job approval-required runs look green;
4. re-read #1127 live state: its CI-scope half is integrated, but the canonical coordination guard still needs effective-current-base landing-diff semantics with PR-head approval identity kept separate; do not edit the guard while another PR owns the guard/test pair;
5. after that ownership clears, finish #1127 before taking another overlapping guard follow-up such as #1123; re-audit #1122 state rather than duplicating an active implementation;
6. treat #1087 file-level CI performance work as a completed checkpoint; do not reopen shard-count or slow-test tuning without new measured evidence of a concrete regression/bottleneck;
7. take #225 or other live G work only through focused reversible child Issues; treat #1047 and #950 as completed checkpoints rather than active work queues;
8. when #1039/#1040 owning-lane parity lands, create caller-zero retirement slices instead of combining product migration with cleanup;
9. if historical branch cleanup is revisited, begin with a new read-only inventory and do not broaden deletion to ambiguous refs;
10. keep destructive schema/data removal separate, preservation-gated, and independently approved;
11. keep durable docs free of transient snapshots and route machine-certifiable drift to CI while H handles semantic drift.

### Last audited stop
`Stop reason: conflict` — the remaining immediately concrete repository-local G work is concentrated in `tool/pr_coordination_guard.py` and its focused tests: #1127 still needs effective-current-base landing-diff classification for coordination/destructive-risk checks, and #1123 remains a later overlapping guard follow-up. At the last live audit PR #1136/#1122 already owned that approval-sensitive guard/test pair and had no distinct current-head approved reviewer, so starting another guard implementation would violate focused ownership and the self-protected approval policy. Resume by rechecking #1136 first; if that ownership clears, refresh latest main and finish #1127 before #1123. Independent alternatives remain blocked for separate reasons: #1094 requires repository-description write capability not exposed by the current integration, #1107 Phase B requires an enforcement root outside repository-controlled Actions, and Bookmark/People caller-zero cleanup remains gated on owning-lane parity. Re-run the full live audit on every resume because this stop line records a snapshot, not permanent ownership state.

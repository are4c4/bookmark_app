# AI Progress — Database, View & Schema UX Lane

> Durable Lane C handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history; this file prioritizes durable contracts and exact resume actions.

## Lane goal
Make Database/View/schema UX generic enough that Person, Weblink, Tag and user-defined ObjectTypes can use ordinary Object/Database workflows rather than dedicated management engines.

## Architecture contract
- Objects are global and are not owned/duplicated by Databases or Views.
- Database defines an Object set/context; View defines layout/filter/sort/group/visible Properties/opening configuration.
- Removing from a Database is distinct from Object archive/trash/permanent deletion.
- `Bookmark` is not a permanent ObjectType or Database concept. Saved URLs should be normal Weblink Objects used through generic Database/View/Inbox contexts.
- Person is a generic ObjectType; dedicated People UI is transitional.
- Tag/TagGroup use generic persistence with specialized hierarchy-aware query/picker/tree UX.
- C owns presentation/configuration/query UX, not native Weblink/Image/File identity or Relation integrity.

## Completed Tag hierarchy query checkpoint

### #1053 — hierarchy-aware Tag filter/query UX
Completed. The durable semantics are:
- exact parent does not match a directly assigned descendant;
- `is-or-below`, below-only and exclude-branch remain distinct typed predicates;
- no automatic ancestor Tag assignment is persisted;
- saved query/filter serialization preserves hierarchy mode;
- C consumes B's validated canonical `TagHierarchySnapshot.isStrictDescendant` reader rather than creating a second traversal/tree store;
- hierarchy capability is enabled only for Relation Properties targeting the canonical Tag system ObjectType;
- unavailable or malformed canonical Parent state removes hierarchy capability so non-exact hierarchy predicates fail closed;
- Database collection filters, saved View projection and reusable query UI share the same canonical hierarchy capability.

#1052 and #1105 are completed B integrity/read checkpoints; #1053 is a completed C query/UX checkpoint. Broader #1050 Tag picker/tree/management UX may still contain unfinished product work, but fresh C runs must not reopen #1053 as an implementation queue.

## Active focused issues

Always verify live GitHub before taking ownership. Completed checkpoints below are not active work sources.

### #1046 — replace dedicated People management
A/#1044 generic Person authority, B/#1045 Person role/group integrity, and E/#1178 canonical Person mutation Search freshness are completed prerequisites. C no longer waits on those tracks before proving daily-use parity.

Integrated C checkpoints:
- canonical Person is exposed as the ordinary generic `People` Database/navigation collection, including an empty workspace with zero legacy People rows (#1199 / PR #1220);
- normal generic Database creation for the registered system Person ObjectType routes through A's `PersonObjectWriteService` rather than title-only Object creation (#1224 / PR #1225);
- Relation-picker Person quick-create uses the same canonical Person write authority and returns the canonical Person Object id (#1230 / PR #1231);
- Person Board/group creation preserves canonical Person authority and applies the group preset to that same Object/transaction (#1234 / PR #1235);
- dedicated People group lifecycle/membership writes now route through canonical Object/Relation-first boundaries while retained legacy group/membership rows remain compatibility projection (#1237 / PR #1277);
- generic Person Profile Image Relation edits compose the canonical Relation boundary while preserving the temporary `people.profile_photo_id` compatibility projection required by surviving legacy UI (#1292 / PR #1308);
- normal AppShell Person navigation, including sidebar and command-palette entry, resolves the canonical system Person generic `People` Database without display-name matching and no longer constructs `PeopleManagementPage` (#1327 / PR #1328).

Do not reimplement those creation/navigation/group-write/Profile Image composition or shell-routing paths. Remaining #1046 parity must be re-audited from current `main`, with emphasis on:
- normal Person rename/Note edit and lifecycle/delete through generic Object/Database/Inspector flows;
- Profile Image presentation/opening through the canonical `Person -> Profile Image -> Image` Relation and generic Relation/Gallery capabilities; #1292/#1308 already establishes compatibility-safe generic edit composition and is not an active C work source;
- groups/roles/backlinks through canonical Relation/Database contracts rather than extending dedicated People storage authority;
- search/filter/group/persisted View/opening behavior needed for normal People workflows;
- inline editing/creation and keyboard/focus/empty-state behavior;
- proving equivalent daily-use workflows are available generically before G retires the now-shell-caller-zero dedicated `PeopleManagementPage` implementation.

The #1237 group-write transition bug, #1292 Profile Image compatibility composition, and #1327 shell-routing slice are completed and must not be selected as active work. Canonical `Person -> Profile Image -> Image` Relation remains authority; legacy `people.profile_photo_id` is compatibility-only while surviving legacy UI still requires it. Prefer removing dedicated controls after generic parity rather than further extending `PeopleManagementPage`.

### #1061 — Home/start UX
Home converges on Inbox / Recent / Favorites / Pinned Databases without making legacy Bookmark/People modules permanent navigation authority.

Integrated checkpoints:
- Home is the normal shell start destination while transition navigation remains available until parity/caller-zero gates complete;
- Recent is derived from canonical Objects across ObjectTypes using deterministic `updatedAt` ordering and excludes transition-only mirrored Bookmark Objects without excluding user-facing system ObjectTypes;
- Home Recent opens through the shared Object Inspector and has loading/empty/error/retry/refresh and keyboard focus/activation behavior;
- canonical Weblink quick capture is integrated (#1194 / PR #1202): Home create/reuse delegates to D's `CanonicalWeblinkCaptureService`, pointer/touch/keyboard submit share one path, malformed/ambiguous collisions surface stable errors, and successful capture reloads canonical Recent without introducing Bookmark rows, Home-only Weblink identity, or fake Recent state.

Home quick capture is complete as a checkpoint, but #1061 remains open. Inbox, Favorites and Pinned Databases still require explicit canonical persistence/query semantics before implementation. Do not reuse legacy Bookmark `storageState`/favorite state as permanent Home authority and do not invent UI-memory persistence merely to fill the surface.

### #1043 — replace Stage1 normal ownership
Move ordinary saved-URL use to canonical Weblink Objects through generic Database/View/navigation and capture-first/Inbox organization. Preserve useful list/table/gallery/filter/sort/opening behavior through generic contracts. Retire Stage1 routing only after completed A/#1041, B/#1042 and D/#1054 prerequisites plus C daily-use parity make the dedicated path caller-zero.

## Integrated foundation that remains authoritative
- generic Database/ObjectType separation;
- persisted Table/List/Gallery/Board Views;
- filter/sort/group/layout/visible-Property persistence;
- relation-aware Property authoring/schema editing through canonical services;
- generic Gallery cover sources and media rendering;
- generic Database sidebar/command-palette navigation;
- canonical Images/Weblinks/Daily Notes/People system collection defaults;
- normal generic Person create, Relation-picker quick-create and Board-create routed through canonical Person authority;
- People group lifecycle/membership transition writes routed through canonical Object/Relation boundaries;
- generic Person Profile Image Relation edits routed through the canonical Relation boundary with compatibility-only legacy projection where required;
- normal shell Person navigation routed to the canonical generic People Database rather than `PeopleManagementPage`;
- shared Object opening/Inspector/Body composition;
- Home start routing with canonical recently-changed Object projection, transition-only Bookmark mirror suppression and canonical Weblink quick capture;
- completed canonical hierarchy-aware Tag Database/View query runtime from #1053 using B's #1052/#1105 integrity/read contracts.

Older statements that A/#1044, B/#1045, or E/#1178 are unresolved blockers for C are obsolete. Older statements that Person collection/create/Relation-picker/Board-create, People group canonicalization, Profile Image edit composition, shell Person routing, or Home canonical URL capture still need to be built are also obsolete. #1046/#1061 remain open for the parity/contracts explicitly listed above.

## Cross-lane boundaries
- **A:** Object/ObjectType identity/lifecycle, Body, Person/Bookmark migration authority. C consumes completed #1044 rather than recreating Person write identity.
- **B:** Relation integrity, Tag Parent/group cycle/cardinality correctness, Bookmark/Person relationship migration. C consumes completed #1045 and the canonical Person Group/Object Relation boundaries; completed #1237 and #1292 compose canonical boundaries into transition compatibility rather than creating second authorities.
- **D:** Weblink/Image/File native behavior and direct URL capture. Home capture delegates to D's canonical Weblink identity service.
- **E:** FTS/search architecture; C owns Database/View typed query/filter semantics, not global FTS persistence. #1178 is a completed Person mutation freshness checkpoint; newly demonstrated Search defects remain E-owned rather than reopening that track.
- **F:** Vault/storage lifecycle.
- **G:** behavior-preserving shared-host reduction and caller-zero dedicated-page retirement after C parity.

## Shared hotspots
`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart` and `people_management_page.dart` are conflict-prone. Recheck live PR ownership before editing. Prefer reusable query/domain/presentation components and small host-composition hunks over broad rewrites. Completed #1237/#1292/#1327 no longer reserve their transition hotspots; live PR ownership remains authoritative for any new work.

## Validation
Changed-Dart format, Analyze, full Flutter Test and focused serialization/widget/real-host regressions are required for primary flows. UI acceptance includes click/key count, inline creation/editing, predictable focus, empty/error/loading states and clear remove-vs-delete semantics. Docs-only handoff changes use the repository docs/coordination path plus required merge-gate.

## Resume sequence
1. refresh latest `main`, live open PR ownership, current CI, shared-hotspot and migration ownership;
2. re-read live #1043/#1046/#1061 and broader #1050 acceptance/dependency status; treat #1053, #1237, #1292, #1327 and the integrated Person creation/navigation checkpoints as completed rather than implementation queues;
3. for #1046, treat shell Person routing as completed, then re-audit generic edit/delete/lifecycle, Profile Image presentation/opening, groups/roles/backlinks, query/filter/opening and full parity before handing the dedicated page to G for caller-zero retirement; do not rebuild #1292/#1308 compatibility-safe Profile Image edit composition;
4. for #1061, keep Home canonical Weblink capture as completed and implement Inbox/Favorites/Pinned only after their canonical contracts are explicit;
5. for #1043, preserve canonical Weblink/Object Database/View semantics and do not grow legacy Bookmark authority;
6. avoid broad shared-host edits until the underlying contract is testable in reusable components;
7. after each coherent slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` and continue while safe C work exists.

If the final resume audit finds no actionable C work, record the exact stop category from `AGENTS.md` with live evidence. Completion of one historical Person/Home slice is never, by itself, a stop reason.

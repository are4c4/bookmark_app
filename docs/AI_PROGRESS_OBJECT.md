# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, live PR ownership and CI before implementation. GitHub live state overrides historical notes below.

## Lane goal
Keep reusable Object/ObjectType identity, typed Property semantics, universal Body, Daily Note identity and shared Object opening/detail contracts coherent across built-in and user-defined ObjectTypes. Lane A may also own a focused legacy Bookmark presentation convergence Issue when GitHub explicitly routes it here; completed presentation work does not broaden Lane A into Primitive, Database/View, Search, Storage or Refactor ownership.

## Current active scope — 2026-09-08
- #56 — only concrete Object/ObjectType/Body/detail/opening obligations that remain clearly Lane A-owned.

Focused Lane A issues now completed/closed:
- #481 — universal Object Body across all real shared opening surfaces.
- #249 — Bookmark Gallery/List presentation parity tracked from real-host gaps.

There is currently **no known independent Lane A production slice** after #249 closure. Idle is correct until #56 or real usage exposes a concrete Object-core/detail regression.

## Integrated Object/Core state
Major correctness checkpoints already on `main` include:
- universal Body editing for system/custom ObjectTypes and Daily Notes (#503/#689);
- persisted Property metadata/type/semantics remain authoritative and computed/intrinsic values fail closed on direct writes (#699/#724/#835);
- concurrent Object creation returns the exact inserted identity (#712);
- reusable ObjectType Body templates and focused default updates (#511/#517);
- Body structure/version/block identity/field-shape validation is fail-closed while unknown/future blocks remain forward-compatible (#521/#749/#755/#761/#796);
- Bookmark detail composes canonical Object Body without manufacturing missing mirrored Object identity (#780);
- corrupt Body reads expose the shared safe retry boundary instead of editable empty content (#811);
- ObjectType template application preflights invalid definitions before side effects and keeps primitive provisioning in the same transaction (#827/#833);
- template Property names/references use canonical persistence naming rules and reject blank/padded/normalized-duplicate identities before provisioning (#843).

Search indexing of Body/title/aliases/properties is Lane E-owned; Relation lifecycle is Lane B-owned. Do not create duplicate pipelines here.

## Universal Body — #481 completed
#874 (`38c20b67…`) completed the final cross-host requirement by composing the reusable canonical `ObjectBodyEditorSection` into Generic Database side peek. The same persisted Body contract now spans:
- shared Object Inspector/detail;
- side peek;
- center peek/full-page shared opening paths;
- Daily Notes and custom ObjectTypes;
- Bookmark detail through the canonical Bookmark -> Object identity boundary.

#481 has been audited and closed. The previous handoff statement that Generic Database side peek blocked #481 is obsolete and must not be revived.

`ObjectInspectorPage` still contains some Body orchestration that overlaps reusable Body components. Any broad behavior-preserving extraction belongs with Lane G/#225 coordination, not speculative Lane A work.

## Bookmark presentation parity — #249 completed
The three concrete real-host gaps from #249 are now covered:
- one Person/Object target per semantic chip is integrated; comma-joined synthetic Person chips are no longer the intended path (#301 and follow-up shared presentation work);
- Bookmark List information hierarchy/readability was improved through focused metadata/chip/spacing slices (#352/#354 and follow-ups), with canonical URL presentation retained (#360);
- Bookmark opening parity is handled through the shared opening contract and #247 is completed/closed;
- #885 (`38494512fc2ba119fecb3f94e6973577aa665f67`) wires the real Stage1 Gallery to shared `ObjectGalleryModeMenu`, `DatabaseViewGalleryAdapter` and `ObjectGalleryView`, persisting `settings['galleryMode']` per active Bookmark View without introducing a Bookmark-only mode or renderer.

The #885 real-host regression switches fixed -> masonry -> fixed and checks both renderer keys and persisted View settings. Filtering, sorting, selection, card content and opening behavior stay on the existing path.

Validation for #885:
- CI #2705 passed maintainability/feature guards, Drift generation, Analyze and the functional Gallery assertions, but the new widget test teardown left a Drift zero-duration cleanup timer pending.
- commit `c791201832e174662bd0ea06ba5e5caa67286c5a` added the repository-standard post-unmount 1 ms pump; production code was unchanged.
- Flutter CI #2712 then passed all maintainability/feature guards, Drift generation, `flutter analyze`, and the full Flutter test suite.
- #249 was closed as completed after #885 merged.

Any later visual polish discovered on real macOS should enter through a concrete #56/follow-up issue rather than keeping #249 conceptually active.

## ObjectType/template integrity status
The current Lane A core integrity requirements for the template path are integrated:
- deterministic invalid template definitions fail before canonical primitive provisioning;
- primitive provisioning participates in the same transaction as user-owned ObjectType/Property/View/template output;
- template-created definitions remain user-owned and later template versions do not silently rewrite customized instances;
- unsupported persisted Property storage types fail closed rather than becoming Text;
- template-local Property identities match persistence normalization.

General template/domain instantiation UX, View labels/layout/grouping and schema-management presentation remain Lane C concerns under current `AGENTS.md`. Do not absorb adjacent normalization/presentation work into Lane A without a concrete ObjectType/core identity invariant.

## Hotspot ownership / concurrency
Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`.

- Re-check latest `main` and open PR ownership immediately before editing.
- The Stage1 lease used for #885 is released; no Lane A production WIP remains.
- Prefer core Store/Service/domain/test fixes below presentation when a real Object invariant can be enforced there.
- Coordinate broad Body/detail extraction with Lane G/#225.

## Cross-lane boundaries
- Weblink/Image/File/Tag identity, managed media, canonical image import/editing and Photo -> Image migration: Lane D (#155/#245).
- Relation mutation/read/index/backlink/audit/reconcile correctness: Lane B.
- Database/View/template/schema UX and generic layout contracts: Lane C.
- Search projection/refresh/indexing: Lane E.
- Vault/filesystem/release lifecycle: Lane F.
- behavior-preserving hotspot reduction and caller-zero legacy deletion: Lane G/#225.

#885 sharing generic Gallery contracts does not transfer generic Gallery ownership to Lane A after #249 completion.

## Exact next actions
1. Re-read live #56, latest `main`, `docs/AI_PROGRESS.md`, this file and open PR ownership on the next Lane A run.
2. Take only a concrete Object/ObjectType/Body/detail/opening correctness regression or explicitly routed Object-core acceptance item.
3. Do not invent RichText/new schema types, template label validation, Body abstractions or Bookmark presentation work merely to keep Lane A active.
4. If a new issue touches Relation, Primitive, Search, Database/View, Storage or broad refactor semantics, hand it to the owning lane rather than creating a parallel implementation.
5. If no concrete Lane A item exists, stop under the AGENTS idle/no-actionable-work condition.

## Latest run checkpoint — 2026-09-08
- #481 was re-audited after #874 and is completed/closed.
- PR #885 merged to `main` as `38494512fc2ba119fecb3f94e6973577aa665f67` after Flutter CI #2712 full green.
- #249 was audited against its live comments/close condition and closed as completed.
- Search #884 (`f1651ba1…`) completed #877, and new Search issue #888 is Lane E-owned rather than a Lane A reopening.
- Primitive #881 (`47d31345…`) moved Bookmark detail image editing onto canonical Image Relations; #889 (`fcd0eb34…`) subsequently routed legacy Photo Management Bookmark attachment through the same canonical Image Relation authority. Both are Lane D/#245 work and do not create Lane A ownership.
- Docs handoff #890 merged as `913653ba3b4437bb12e62b4af97de77145ef00d0` after Flutter CI #2718 full green.
- Work in progress: **none in Lane A production**. No Lane A shared-hotspot lease is held.
- Stop reason: no remaining actionable independent Lane A-only acceptance item is known. Resume only for a concrete #56/Object-core/detail regression or explicit new Lane A routing.

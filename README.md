# bookmark_app

A local-first Flutter personal knowledge/database application built around an Object-first model and a local Drift / SQLite store.

The repository is migrating away from legacy Bookmark/People/Photo-specific authorities toward reusable Objects, ObjectTypes, Properties, Relations, Databases, Views, and a free-form Body. `Bookmark` remains a compatibility/migration input; normal URL capture is intended to converge on canonical Weblink Objects.

See [`docs/product_architecture.md`](docs/product_architecture.md) for the durable product contract and [`AGENTS.md`](AGENTS.md) for AI-development rules.

## Product direction

- Global reusable Objects inside a Vault
- One primary ObjectType per Object
- Structured Properties and typed Relations
- Free-form block Body on every Object
- Generic Database/View presentation with Table / List / Gallery / Board
- Canonical Weblink, Image, and File native-capability Objects
- Generic Person, Tag, TagGroup, Book, Paper, Project, Recipe, and user-defined ObjectTypes
- Canonical Object Search
- Local-first Vault/Profile storage, backup/restore, and portable-storage boundaries
- Inbox / archive / trash lifecycle and a roadmap toward Inbox / Recent / Favorites / Pinned Databases as the main work-start surface

Legacy Bookmark/People/Photo runtime paths are retained only where migration parity, caller-zero proof, or preservation requirements still need them. Do not infer the current implementation state from this README; live GitHub Issues/PRs/CI and `main` are authoritative for transient status.

## Local update / development run

Use the repository-pinned Flutter version documented by the developer workflow. To update the local checkout and run the latest development build:

```bash
cd ~/bookmark_app
git pull
flutter pub get
dart run build_runner build
flutter run -d macos
```

Run the same generation step after Drift schema changes. The authoritative current Drift schema version lives in `lib/data/app_database.dart`; this README intentionally does not duplicate that volatile number.

## Update the installed macOS app

To replace an already installed `Bookmark.app` with the latest version while keeping the existing app data:

1. Quit Bookmark completely.
2. Pull the latest source and regenerate code:

```bash
cd ~/bookmark_app
git pull
flutter pub get
dart run build_runner build
```

3. Build the latest release app and DMG:

```bash
bash tool/package_macos.sh
```

4. Open the release output in Finder:

```bash
open ~/bookmark_app/build/macos/Build/Products/Release/
```

5. In Finder, move the existing `/Applications/Bookmark.app` aside or to the Trash, then drag the newly built `Bookmark.app` into the Applications folder.

The generated files are:

```text
~/bookmark_app/build/macos/Build/Products/Release/Bookmark.app
~/bookmark_app/dist/macos/Bookmark-<version>.dmg
```

The packaging script deliberately refuses to overwrite an existing `/Applications/Bookmark.app` automatically. It also preserves an existing Bundle Identifier when switching identifiers would make existing profile data appear missing. Replacing only the app bundle therefore normally keeps existing profile/Vault/Image data intact.

If `/Applications` rejects a terminal copy with a permission error, use Finder drag-and-drop instead. macOS may ask for administrator authentication.

## macOS app / DMG

To build the app as `Bookmark.app` and create an installable DMG:

```bash
bash tool/package_macos.sh
```

For a first direct install into `/Applications` when `Bookmark.app` does not already exist there:

```bash
bash tool/package_macos.sh --install
```

The release script reads the version from `pubspec.yaml`, applies the release product identity safely, preserves an existing Bundle Identifier when changing it would hide existing profile data, and creates:

```text
build/macos/Build/Products/Release/Bookmark.app
dist/macos/Bookmark-<version>.dmg
```

See [`docs/MACOS_RELEASE.md`](docs/MACOS_RELEASE.md) for Bundle Identifier safety, custom AppIcon input, DMG packaging, Gatekeeper notes, and update/install details.

## Repository source-of-truth rules

Durable documentation and live repository state have different jobs:

- `docs/product_architecture.md` — long-lived product architecture and semantics.
- `docs/architecture.md` — long-lived technical architecture.
- `AGENTS.md` — AI development/ownership/concurrency rules.
- `docs/AI_PROGRESS*.md` — durable handoff, routing, completed contracts, and exact resume guidance.
- GitHub Issues — focused implementation contracts and acceptance criteria.
- GitHub PRs / CI / current `main` — transient ownership, branch state, currently-open work, and validation status.

Do not copy volatile open-PR counts, CI run numbers, or current main commit SHAs into durable docs unless the historical checkpoint itself is the point. A fresh AI run must re-read live GitHub state before implementation.

## Codebase size checks

For quick raw Dart line counts, including blank lines and comments:

```bash
cd ~/bookmark_app

echo "=== lib ==="
find lib -name '*.dart' -type f -print0 | xargs -0 wc -l | tail -1

echo "=== test ==="
find test -name '*.dart' -type f -print0 | xargs -0 wc -l | tail -1

echo "=== lib + test ==="
find lib test -name '*.dart' -type f -print0 | xargs -0 wc -l | tail -1
```

For code / comment / blank-line counts, install `cloc` once and measure production and tests separately:

```bash
brew install cloc

cd ~/bookmark_app
cloc lib
cloc test
cloc lib test
```

To inspect the largest handwritten production Dart files, exclude generated files from the ranking:

```bash
cd ~/bookmark_app

find lib -name '*.dart' \
  ! -name '*.g.dart' \
  ! -name '*.freezed.dart' \
  -type f -print0 \
  | xargs -0 wc -l \
  | sort -nr \
  | head -30
```

To list only handwritten production Dart files at or above 1,000 raw lines:

```bash
cd ~/bookmark_app

find lib -name '*.dart' \
  ! -name '*.g.dart' \
  ! -name '*.freezed.dart' \
  -type f -print0 \
  | xargs -0 wc -l \
  | sort -nr \
  | awk '$1 >= 1000'
```

Generated files such as Drift's `app_database.g.dart` can be very large and should not be treated as maintainability hotspots. For Refactor work, prefer tracking handwritten responsibility concentration and legacy/domain-specific host retirement rather than total LOC alone.

## Database

Drift schema/migration code preserves historical user data while runtime CRUD moves toward canonical Object-first stores and services. The current schema version is intentionally not duplicated here; read `AppDatabase.schemaVersion` in `lib/data/app_database.dart` when an exact live value is required.

Raw SQL is intentionally retained where appropriate, such as legacy-schema discovery/migration and SQLite FTS5 queries.

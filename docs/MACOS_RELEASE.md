# macOS release packaging and release channels

Related: #218, #1335, #1362

Bookmark has one macOS packaging authority: `tool/package_macos.sh`. Local development packages and repository-owned RC/stable releases both use that script so product identity, Bundle Identifier safety and build provenance do not drift between paths.

This repository does not currently track the generated `macos/` Flutter runner. The packaging script applies product identity and packaging rules to the local/generated runner at build time.

## Product and build identity

Default identity:

- product/app name: `Bookmark`;
- preferred Bundle Identifier: `com.are4c4.bookmark`;
- version/build number: top-level `version:` in `pubspec.yaml`;
- source identity: exact Git commit plus clean/dirty state;
- release channel: `development`, `rc`, or `stable`.

The running app exposes version/build, release channel, source commit and source state in Settings. Packaged DMG names also include source provenance.

## Development / local package

From the project root on macOS:

```bash
bash tool/package_macos.sh
```

No release environment variables are required. A normal local package is always `development`; it cannot silently present itself as an RC or stable package.

The script:

1. verifies required macOS build tools and Git source metadata;
2. reads version/build number from `pubspec.yaml`;
3. records the exact source commit and clean/dirty state;
4. generates the standard Flutter macOS runner locally when absent;
5. applies the release product name and safe Bundle Identifier;
6. optionally regenerates AppIcon sizes from one 1024x1024 PNG;
7. runs `flutter pub get` and `flutter build macos --release`;
8. injects version/build/commit/source-state/channel at compile time;
9. creates a compressed DMG containing `Bookmark.app` and an `/Applications` shortcut.

Typical outputs:

```text
build/macos/Build/Products/Release/Bookmark.app
dist/macos/Bookmark-<version>-<short-commit>.dmg
dist/macos/Bookmark-<version>-<short-commit>-dirty.dmg
```

Dirty source remains explicit instead of being confused with a repository release.

## Repository-owned RC -> stable path

Repository releases are published through the **macOS Release** GitHub Actions workflow. Do not upload an ad-hoc local DMG and call it stable.

The workflow accepts exactly two inputs:

- `channel`: `rc` or `stable`;
- `source_sha`: the full 40-character Git commit SHA to release.

The selected source must already be integrated into `main` and must already have passed the repository's authoritative CI. The workflow checks both conditions before packaging.

### 1. Publish a release candidate

Choose the exact known commit from `main`, then run **Actions -> macOS Release -> Run workflow** with:

```text
channel = rc
source_sha = <full commit SHA>
```

An RC is built only from a clean source tree. The workflow creates an immutable release identity such as:

```text
v0.1.0-rc.123
Bookmark-0.1.0-rc-1a2b3c4.dmg
```

The RC is published as a GitHub prerelease. Before publication the workflow verifies the DMG, mounts it read-only and confirms that it contains `Bookmark.app`.

Use that RC for any manual/runtime smoke checks that are appropriate for the change. #1353 evidence can be consulted where useful, but subjective visual review is not an automatic release blocker.

### 2. Promote the same source to stable

After the RC is accepted, run the same workflow again with:

```text
channel = stable
source_sha = <the exact same full commit SHA>
```

Stable publication fails closed unless GitHub Releases already contains an RC for the same semantic version **and the same source commit**. Stable does not silently switch to a newer `main` tip.

The stable tag is the semantic version, for example:

```text
v0.1.0
Bookmark-0.1.0-stable-1a2b3c4.dmg
```

An existing stable GitHub Release or tag is never replaced. Publish a new semantic version instead of mutating an old stable release.

## Retained release evidence

Each RC/stable GitHub Release retains:

- the packaged DMG;
- `<dmg>.sha256` containing its SHA-256 checksum;
- `release-provenance.json`;
- generated release notes with version/build, channel, exact source SHA, database schema version, DMG name and checksum.

`release-provenance.json` is intended to make a package identifiable without guessing from a downloaded filename. It records at least:

```json
{
  "format": "bookmark_app_release_provenance",
  "formatVersion": 1,
  "version": "0.1.0",
  "buildNumber": "1",
  "channel": "stable",
  "releaseTag": "v0.1.0",
  "sourceSha": "<full commit SHA>",
  "databaseSchemaVersion": 16,
  "artifact": "Bookmark-0.1.0-stable-1a2b3c4.dmg",
  "sha256": "<SHA-256>"
}
```

Before installing a downloaded historical package, verify its checksum, for example:

```bash
cd ~/Downloads
shasum -a 256 -c Bookmark-0.1.0-stable-1a2b3c4.dmg.sha256
```

## Rollback / reinstalling a previous known-good build

Rollback means reinstalling a previous **application package**. It never means downgrading or rewriting a Vault/database.

1. Open the repository's GitHub Releases and choose the previous known-good **stable** release.
2. Confirm its version, full source SHA and `databaseSchemaVersion` from `release-provenance.json` / release notes.
3. Download the DMG and matching `.sha256`, then verify the checksum.
4. Keep the same effective Bundle Identifier. Move the currently installed `Bookmark.app` aside and install the historical app package; do not move, restore, edit or replace the Vault as part of the app rollback.
5. If the older application cannot safely open the current Vault schema, Bookmark fails before performing a database downgrade and tells you to reinstall a newer compatible build. In that case, stop using the older app and reinstall the newer package. **Do not edit SQLite `user_version`, run reverse migrations, or restore an older backup merely to force the old binary to open current data.**

A separate backup restore is a user-data recovery operation and should be chosen only when the user intentionally wants to restore historical data, not as a normal application-version rollback.

## Release-channel safety in the packaging script

Advanced/manual callers can request repository channels explicitly:

```bash
BOOKMARK_RELEASE_CHANNEL=rc \
BOOKMARK_RELEASE_TAG=v0.1.0-rc.123 \
  bash tool/package_macos.sh
```

or:

```bash
BOOKMARK_RELEASE_CHANNEL=stable \
BOOKMARK_RELEASE_TAG=v0.1.0 \
  bash tool/package_macos.sh
```

For `rc` and `stable`, packaging fails unless:

- the Git working tree is clean;
- a release tag is supplied;
- the tag format matches the version/channel;
- the tag resolves to the exact source `HEAD`.

The GitHub workflow is the supported publication path because it additionally proves the selected commit is on `main`, verifies authoritative CI, verifies the DMG, creates checksums/provenance and retains artifacts in GitHub Releases.

## Existing local data and Bundle Identifier changes

Flutter/macOS profile data may live inside the app sandbox container, for example:

```text
~/Library/Containers/<bundle-id>/Data/Documents/BookmarkApp/Profiles/
```

Changing the Bundle Identifier can therefore make existing data appear to disappear even though the old files still exist in the old container.

`tool/package_macos.sh` protects against this: when the local generated runner already has a different Bundle Identifier and the matching container contains Bookmark profile data, the script preserves that existing Bundle Identifier instead of silently switching to `com.are4c4.bookmark`.

A future explicit Bundle Identifier migration should begin with a backup and must be treated separately from normal release packaging. The packaging and release workflows never delete, move or rewrite profile/database/media data.

## Install directly into Applications

For a first local install:

```bash
bash tool/package_macos.sh --install
```

The install step deliberately refuses to overwrite an existing `/Applications/Bookmark.app`. Move/rename the old app first when replacing a previous build; this prevents a packaging command from destructively replacing an installed application unexpectedly.

Alternatively:

```bash
bash tool/package_macos.sh --open-dmg
```

Then drag `Bookmark.app` to the `Applications` shortcut in Finder.

## App icon

A custom icon can be installed without hand-creating every macOS icon size by supplying one square 1024x1024 PNG:

```bash
BOOKMARK_ICON_SOURCE=/absolute/path/to/bookmark_icon_1024.png \
  bash tool/package_macos.sh
```

If no custom icon source is supplied, the existing generated AppIcon is preserved.

## Configure without building

To inspect/apply local product identity and provenance configuration without creating a release build:

```bash
bash tool/package_macos.sh --configure-only
```

The script prints the effective product name, Bundle Identifier, version/build, channel, release tag, commit and source state.

## Signing, notarization and automatic updates

This release workflow does **not** configure Apple Developer ID signing, notarization, Mac App Store distribution or an automatic updater. It never stores signing credentials in the repository.

Unsigned/not-notarized packages transferred to another Mac may require explicit Gatekeeper approval. Signing/notarization and automatic update delivery remain separate focused work if external distribution later requires them.

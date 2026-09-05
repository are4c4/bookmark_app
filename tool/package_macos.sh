#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="${BOOKMARK_APP_NAME:-Bookmark}"
TARGET_BUNDLE_ID="${BOOKMARK_BUNDLE_ID:-com.are4c4.bookmark}"
INSTALL_AFTER_BUILD=0
CONFIGURE_ONLY=0
OPEN_DMG=0

usage() {
  cat <<'USAGE'
Usage: bash tool/package_macos.sh [options]

Build and package Bookmark as a macOS application and DMG.

Options:
  --install          Copy the built app to /Applications after packaging.
  --configure-only   Configure/generate the local macOS runner, but do not build.
  --open-dmg         Open the resulting DMG after packaging.
  -h, --help         Show this help.

Environment:
  BOOKMARK_APP_NAME       Product name. Default: Bookmark
  BOOKMARK_BUNDLE_ID      Preferred Bundle Identifier. Default: com.are4c4.bookmark
  BOOKMARK_ICON_SOURCE    Optional 1024x1024 PNG used to regenerate AppIcon sizes.

Bundle Identifier safety:
  If the existing local runner uses another Bundle Identifier and profile data is
  found in that app container, the script preserves the existing identifier by
  default so the installed build continues to see the same local data.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --install) INSTALL_AFTER_BUILD=1 ;;
    --configure-only) CONFIGURE_ONLY=1 ;;
    --open-dmg) OPEN_DMG=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: macOS packaging must run on macOS." >&2
  exit 1
fi

for cmd in flutter xcodebuild hdiutil ditto sips; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 1
  fi
done

PUBSPEC_VERSION="$(awk '/^version:[[:space:]]*/ {print $2; exit}' pubspec.yaml)"
if [[ -z "$PUBSPEC_VERSION" ]]; then
  echo "error: pubspec.yaml must contain a top-level version." >&2
  exit 1
fi
BUILD_NAME="${PUBSPEC_VERSION%%+*}"
if [[ "$PUBSPEC_VERSION" == *+* ]]; then
  BUILD_NUMBER="${PUBSPEC_VERSION##*+}"
else
  BUILD_NUMBER="1"
fi

APPINFO="macos/Runner/Configs/AppInfo.xcconfig"
if [[ ! -f "$APPINFO" ]]; then
  echo "macOS runner is not present; generating the standard Flutter macOS runner locally..."
  flutter create --platforms=macos --project-name bookmark_app .
fi

if [[ ! -f "$APPINFO" ]]; then
  echo "error: expected $APPINFO after Flutter runner generation." >&2
  exit 1
fi

read_xcconfig_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$APPINFO"
}

set_xcconfig_value() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { replaced=0 }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      print key " = " value
      replaced=1
      next
    }
    { print }
    END {
      if (!replaced) print key " = " value
    }
  ' "$APPINFO" > "$tmp"
  mv "$tmp" "$APPINFO"
}

CURRENT_BUNDLE_ID="$(read_xcconfig_value PRODUCT_BUNDLE_IDENTIFIER || true)"
EFFECTIVE_BUNDLE_ID="$TARGET_BUNDLE_ID"

if [[ -n "$CURRENT_BUNDLE_ID" && "$CURRENT_BUNDLE_ID" != "$TARGET_BUNDLE_ID" ]]; then
  CURRENT_PROFILE_ROOT="$HOME/Library/Containers/$CURRENT_BUNDLE_ID/Data/Documents/BookmarkApp/Profiles"
  if [[ -d "$CURRENT_PROFILE_ROOT" ]]; then
    EFFECTIVE_BUNDLE_ID="$CURRENT_BUNDLE_ID"
    cat <<EOF_WARN
warning: existing Bookmark profile data was found for Bundle Identifier:
  $CURRENT_BUNDLE_ID
To avoid making that data appear missing, this build will preserve the existing
Bundle Identifier instead of switching to:
  $TARGET_BUNDLE_ID

If you later want to migrate to the new Bundle Identifier, back up the profile
folder first and perform that migration explicitly.
EOF_WARN
  fi
fi

set_xcconfig_value PRODUCT_NAME "$APP_NAME"
set_xcconfig_value PRODUCT_BUNDLE_IDENTIFIER "$EFFECTIVE_BUNDLE_ID"

ICON_SOURCE="${BOOKMARK_ICON_SOURCE:-$ROOT_DIR/assets/macos/bookmark_icon_1024.png}"
APPICON_DIR="macos/Runner/Assets.xcassets/AppIcon.appiconset"
if [[ -f "$ICON_SOURCE" ]]; then
  if [[ ! -d "$APPICON_DIR" ]]; then
    echo "error: AppIcon asset catalog is missing: $APPICON_DIR" >&2
    exit 1
  fi
  for size in 16 32 64 128 256 512 1024; do
    sips -s format png -z "$size" "$size" "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_${size}.png" >/dev/null
  done
  echo "Installed macOS AppIcon sizes from: $ICON_SOURCE"
else
  echo "No custom icon source found; preserving the existing macOS AppIcon asset set."
  echo "To install a custom icon later, set BOOKMARK_ICON_SOURCE to a 1024x1024 PNG."
fi

cat <<EOF_SUMMARY
macOS release configuration:
  Product name:      $APP_NAME
  Bundle Identifier: $EFFECTIVE_BUNDLE_ID
  Version:           $BUILD_NAME
  Build number:      $BUILD_NUMBER
EOF_SUMMARY

if [[ "$CONFIGURE_ONLY" -eq 1 ]]; then
  echo "Configuration complete (--configure-only)."
  exit 0
fi

flutter pub get
flutter build macos --release --build-name "$BUILD_NAME" --build-number "$BUILD_NUMBER"

APP_PATH="build/macos/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: release build did not produce $APP_PATH" >&2
  echo "Check PRODUCT_NAME in $APPINFO and the Flutter build output above." >&2
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist/macos"
STAGE_DIR="$DIST_DIR/.dmg-stage"
DMG_PATH="$DIST_DIR/$APP_NAME-$BUILD_NAME.dmg"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
ditto "$APP_PATH" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME $BUILD_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null
rm -rf "$STAGE_DIR"

if [[ "$INSTALL_AFTER_BUILD" -eq 1 ]]; then
  DEST="/Applications/$APP_NAME.app"
  if [[ -e "$DEST" ]]; then
    echo "error: $DEST already exists; refusing to replace it automatically." >&2
    echo "Move the existing app aside first, then rerun with --install." >&2
    exit 1
  fi
  ditto "$APP_PATH" "$DEST"
  echo "Installed: $DEST"
fi

echo "Built app: $APP_PATH"
echo "Built DMG: $DMG_PATH"
echo "Note: this is an unsigned/not-notarized personal build unless you add signing separately."

if [[ "$OPEN_DMG" -eq 1 ]]; then
  open "$DMG_PATH"
fi

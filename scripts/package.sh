#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_NAME="Gitea Helper"
SCHEME_NAME="Gitea Helper"
PROJECT_FILE="$PROJECT_ROOT/Gitea Helper.xcodeproj"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="$PROJECT_NAME.app"
ZIP_NAME="$PROJECT_NAME.zip"
ARCHIVE_APP="$DIST_DIR/$APP_NAME"
ARCHIVE_ZIP="$DIST_DIR/$ZIP_NAME"
DERIVED_DATA_DIR="$PROJECT_ROOT/build/DerivedData"
RELEASE_APP="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME"

echo "Building $PROJECT_NAME Release..."
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$RELEASE_APP" ]]; then
  echo "Release app not found: $RELEASE_APP" >&2
  exit 1
fi

echo "Preparing dist folder..."
rm -rf "$ARCHIVE_APP" "$ARCHIVE_ZIP"
mkdir -p "$DIST_DIR"
cp -R "$RELEASE_APP" "$ARCHIVE_APP"

echo "Ad-hoc signing app..."
codesign --force --deep --sign - "$ARCHIVE_APP"

echo "Creating zip..."
ditto -c -k --keepParent "$ARCHIVE_APP" "$ARCHIVE_ZIP"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$ARCHIVE_APP"

echo "Package complete:"
echo "  App: $ARCHIVE_APP"
echo "  Zip: $ARCHIVE_ZIP"

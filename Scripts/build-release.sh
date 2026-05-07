#!/usr/bin/env bash
#
# Build a Release openTalk.app and wrap it in a DMG.
#
# Two modes — controlled by environment variables:
#
#   AD-HOC (default, free)
#     No env vars set. Produces an unsigned/ad-hoc DMG. Users will hit
#     macOS Gatekeeper on first launch and have to right-click → Open
#     (or run `xattr -dr com.apple.quarantine /Applications/openTalk.app`).
#
#   NOTARIZED (Apple Developer Program required, $99/yr)
#     Set ALL of:
#       DEVELOPER_ID_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#       APPLE_ID                e.g. you@example.com
#       APPLE_TEAM_ID           e.g. ABC123XYZ4
#       APPLE_APP_PASSWORD      app-specific password from appleid.apple.com
#     Produces a signed + notarized + stapled DMG that opens cleanly on any Mac.
#
# Output: ./build/openTalk-<version>.dmg

set -euo pipefail

cd "$(dirname "$0")/.."

# --- config ----------------------------------------------------------------

SCHEME="openTalk"
PROJECT="openTalk.xcodeproj"
APP_NAME="openTalk"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' openTalk/Resources/Info.plist 2>/dev/null || echo 0.0.0)"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# Notarization mode is on iff all four env vars are non-empty.
NOTARIZE=false
if [[ -n "${DEVELOPER_ID_IDENTITY:-}" \
   && -n "${APPLE_ID:-}" \
   && -n "${APPLE_TEAM_ID:-}" \
   && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    NOTARIZE=true
fi

echo ">> openTalk v$VERSION  (notarize=$NOTARIZE)"

# --- prep ------------------------------------------------------------------

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$EXPORT_DIR"

if ! command -v xcodegen >/dev/null; then
    echo "!! xcodegen not found. brew install xcodegen" >&2
    exit 1
fi

xcodegen generate

# --- build & archive -------------------------------------------------------

echo ">> archiving..."
xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'generic/platform=macOS' \
           -archivePath "$ARCHIVE_PATH" \
           -allowProvisioningUpdates \
           archive | xcbeautify --quiet 2>/dev/null || \
xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'generic/platform=macOS' \
           -archivePath "$ARCHIVE_PATH" \
           -allowProvisioningUpdates \
           archive | tail -20

# Export the .app from the archive.
EXPORT_OPTIONS_PLIST="$BUILD_DIR/export-options.plist"
if $NOTARIZE; then
    METHOD="developer-id"
else
    METHOD="mac-application"
fi
cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$METHOD</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

echo ">> exporting..."
xcodebuild -exportArchive \
           -archivePath "$ARCHIVE_PATH" \
           -exportPath "$EXPORT_DIR" \
           -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
           -allowProvisioningUpdates 2>&1 | tail -10

if [[ ! -d "$APP_PATH" ]]; then
    echo "!! export failed: $APP_PATH not found" >&2
    exit 1
fi

# --- sign + notarize (notarized mode only) ---------------------------------

if $NOTARIZE; then
    echo ">> re-signing with Developer ID + hardened runtime..."
    codesign --force --deep --options runtime --timestamp \
             --sign "$DEVELOPER_ID_IDENTITY" \
             "$APP_PATH"
    codesign --verify --strict --verbose=2 "$APP_PATH"

    echo ">> submitting to notarytool..."
    NOTARIZE_ZIP="$BUILD_DIR/$APP_NAME-notarize.zip"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
    xcrun notarytool submit "$NOTARIZE_ZIP" \
                     --apple-id "$APPLE_ID" \
                     --team-id "$APPLE_TEAM_ID" \
                     --password "$APPLE_APP_PASSWORD" \
                     --wait
    rm -f "$NOTARIZE_ZIP"

    echo ">> stapling..."
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"
fi

# --- DMG -------------------------------------------------------------------

echo ">> creating $DMG_PATH..."
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if $NOTARIZE; then
    echo ">> stapling DMG..."
    xcrun stapler staple "$DMG_PATH"
fi

echo ""
echo "DONE — $DMG_PATH"
ls -lh "$DMG_PATH"

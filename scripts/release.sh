#!/bin/zsh
# Builds a signed, notarized and stapled Vibecabulary.dmg in build/release/.
# Needs a "Developer ID Application" certificate in the login keychain and a notarytool profile:
#   xcrun notarytool store-credentials "vibecabulary-notary" --apple-id <id> --team-id <team>
# Override with SIGN_IDENTITY / NOTARY_PROFILE. Usage: scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NAME=Vibecabulary
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: STEVEN DEWITT GLADNEY (UXCJ84DJ98)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-vibecabulary-notary}"
OUT=build/release
APP="$OUT/$NAME.app"
DMG="$OUT/$NAME.dmg"

echo "==> Checks"
swift run -c debug GlossaryChecks

echo "==> Universal build"
scripts/build-app.sh --no-install
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/$NAME.app/Contents/Info.plist)

rm -rf "$OUT" && mkdir -p "$OUT"
ditto build/$NAME.app "$APP"

echo "==> Signing $NAME $VERSION (hardened runtime, secure timestamp)"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --deep --verbose=2 "$APP"

echo "==> Disk image"
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$NAME $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "==> Notarizing (usually a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json \
  | tee "$OUT/notarization.json"
STATUS=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['status'])" "$OUT/notarization.json")
if [[ "$STATUS" != "Accepted" ]]; then
  ID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['id'])" "$OUT/notarization.json")
  xcrun notarytool log "$ID" --keychain-profile "$NOTARY_PROFILE" "$OUT/notarization-log.json" || true
  echo "Notarization status: $STATUS (log: $OUT/notarization-log.json)" >&2
  exit 1
fi

echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Gatekeeper check"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
MNT=$(mktemp -d)
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MNT" >/dev/null
spctl --assess --type execute --verbose=2 "$MNT/$NAME.app"
lipo -info "$MNT/$NAME.app/Contents/MacOS/$NAME"
hdiutil detach "$MNT" >/dev/null

shasum -a 256 "$DMG" | tee "$DMG.sha256"
ls -lh "$DMG"
echo "Done: $DMG ($NAME $VERSION)"

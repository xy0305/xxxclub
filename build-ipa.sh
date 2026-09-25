#!/bin/bash
# Mac + Xcode 16+：打出未签名 IPA，再用 Sideloadly / AltStore 签。
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-$PWD/dist}"
ARCHIVE="$OUT/XXXClub.xcarchive"
APPNAME="XXXClub"
mkdir -p "$OUT"

xcodebuild \
  -project XXXClub.xcodeproj \
  -scheme XXXClub \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM=""

APP="$ARCHIVE/Products/Applications/${APPNAME}.app"
if [ ! -d "$APP" ]; then
  echo "archive 没有产出 .app" >&2
  exit 1
fi
rm -f "$APP/archived-expanded-entitlements.xcent" "$APP/embedded.mobileprovision" || true

STAGE="$OUT/ipa-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
(
  cd "$STAGE"
  zip -qry "$OUT/${APPNAME}-unsigned.ipa" Payload
)
echo "IPA: $OUT/${APPNAME}-unsigned.ipa"

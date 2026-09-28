#!/usr/bin/env bash
#
# Hade — yerel imzalı sürüm scripti
#
# Sertifikan yalnızca bu Mac'in Keychain'inde kalır; hiçbir yere yüklenmez.
#
# Kullanım:
#   scripts/release.sh <sürüm>        # ör. scripts/release.sh 1.0.1
#
# Bir kereye mahsus kurulum (notarizasyon kimliği):
#   xcrun notarytool store-credentials "hade-notary" \
#       --apple-id "APPLE_ID_MAIL" --team-id "YOUR_TEAM_ID" \
#       --password "UYGULAMAYA_OZEL_SIFRE"
#   (App-specific password: https://account.apple.com ▸ Giriş & Güvenlik)
#
# Ortam değişkenleriyle geçersiz kılınabilir:
#   TEAM_ID, NOTARY_PROFILE, SCHEME

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Kullanım: scripts/release.sh <sürüm>   (ör. 1.0.1)"
  exit 1
fi
TAG="v$VERSION"

# Depo köküne geç.
cd "$(dirname "$0")/.."

PROJECT="Hade.xcodeproj"
SCHEME="${SCHEME:-Hade}"
NOTARY_PROFILE="${NOTARY_PROFILE:-hade-notary}"

# Team ID: env ile verilebilir; verilmezse Developer ID sertifikasından otomatik bulunur.
TEAM_ID="${TEAM_ID:-$(security find-identity -v -p codesigning \
  | grep -m1 'Developer ID Application' \
  | grep -oE '\([A-Z0-9]{10}\)' | tr -d '()')}"
if [[ -z "$TEAM_ID" ]]; then
  echo "Team ID bulunamadı. 'Developer ID Application' sertifikanızın kurulu olduğundan emin olun"
  echo "veya TEAM_ID=XXXXXXXXXX scripts/release.sh $VERSION şeklinde verin."
  exit 1
fi

WORK="$(mktemp -d)"
ARCHIVE="$WORK/Hade.xcarchive"
EXPORT="$WORK/export"
DMG="Hade-$VERSION.dmg"

echo "▶︎ (1/6) Archive (sürüm $VERSION)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  archive

echo "▶︎ (2/6) Export (Developer ID, hardened runtime)…"
cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -exportPath "$EXPORT"

APP="$EXPORT/Hade.app"
[[ -d "$APP" ]] || { echo "Hata: imzalı uygulama bulunamadı: $APP"; exit 1; }

echo "▶︎ (3/6) DMG oluştur (sürükle-bırak kurulum)…"
command -v create-dmg >/dev/null 2>&1 || brew install create-dmg
rm -f "$DMG"
SRC="$WORK/dmgsrc"; mkdir -p "$SRC"; cp -R "$APP" "$SRC/"
if ! create-dmg \
      --volname "Hade" \
      --window-pos 200 120 \
      --window-size 600 380 \
      --icon-size 120 \
      --icon "Hade.app" 160 190 \
      --app-drop-link 440 190 \
      --no-internet-enable \
      "$DMG" "$SRC"; then
  echo "  create-dmg başarısız; düz hdiutil'e geçiliyor."
  rm -f "$DMG"
  ln -s /Applications "$SRC/Applications"
  hdiutil create -volname "Hade" -srcfolder "$SRC" -ov -format UDZO "$DMG"
fi

echo "▶︎ (4/6) Notarize (Apple sunucusuna gönderiliyor)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▶︎ (5/6) Staple (onay mührü ekleniyor)…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "▶︎ (6/6) Git tag + GitHub release…"
git tag -f -a "$TAG" -m "Hade $VERSION"
git push -f origin "$TAG"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$DMG" --clobber
else
  gh release create "$TAG" "$DMG" --title "$TAG" --generate-notes
fi

echo "✅ Tamamlandı: $DMG imzalandı, notarize edildi ve $TAG olarak yayınlandı."

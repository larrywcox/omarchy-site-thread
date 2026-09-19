#!/usr/bin/env bash
# Builds "UniFi SiteThread.app" and wraps it in a drag-to-install disk image.
#
# Requirements: macOS 12 or newer and the Xcode Command Line Tools.
# Output: macos/dist/UniFi-SiteThread-<version>.dmg

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="UniFi SiteThread"
VOLUME_NAME="UniFi SiteThread"
APP="${ROOT}/dist/${APP_NAME}.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: a disk image can only be built on macOS (hdiutil is macOS-only)." >&2
  exit 1
fi

"${ROOT}/build.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist")"
DMG="${ROOT}/dist/UniFi-SiteThread-${VERSION}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

echo "==> Staging disk image contents"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"

echo "==> Creating ${DMG##*/}"
rm -f "${DMG}"
hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGE}" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  -quiet \
  "${DMG}"

echo
echo "Built: ${DMG}"
echo
echo "Install: open the image and drag UniFi SiteThread to Applications."
echo
echo "The app is ad-hoc signed, not notarised. If you move this image to"
echo "another Mac, macOS will quarantine it; clear the flag after copying:"
echo "  xattr -dr com.apple.quarantine \"/Applications/${APP_NAME}.app\""

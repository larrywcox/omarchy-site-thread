#!/usr/bin/env bash
# Builds "UniFi SiteThread.app" from the Swift package.
#
# Requirements: macOS 12 or newer and the Xcode Command Line Tools
# (xcode-select --install). No Xcode project and no external dependencies.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="UniFi SiteThread"
BUNDLE="${ROOT}/dist/${APP_NAME}.app"
CONFIGURATION="${CONFIGURATION:-release}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: UniFi SiteThread for macOS must be built on macOS." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found. Install the Xcode Command Line Tools:" >&2
  echo "       xcode-select --install" >&2
  exit 1
fi

echo "==> Building (${CONFIGURATION})"
swift build --package-path "${ROOT}" -c "${CONFIGURATION}"
BINARY="$(swift build --package-path "${ROOT}" -c "${CONFIGURATION}" --show-bin-path)/SiteThread"

if [[ ! -x "${BINARY}" ]]; then
  echo "error: built binary not found at ${BINARY}" >&2
  exit 1
fi

echo "==> Assembling ${APP_NAME}.app"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "${BINARY}" "${BUNDLE}/Contents/MacOS/SiteThread"
cp "${ROOT}/Resources/Info.plist" "${BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${BUNDLE}/Contents/PkgInfo"

# An ad-hoc signature gives the bundle a stable identity, so the keychain
# prompts once rather than on every launch.
echo "==> Signing (ad-hoc)"
codesign --force --sign - --timestamp=none "${BUNDLE}"
codesign --verify --deep --strict "${BUNDLE}"

echo
echo "Built: ${BUNDLE}"
echo "Run it:       open \"${BUNDLE}\""
echo "Install it:   cp -R \"${BUNDLE}\" /Applications/"
echo "Try the demo: SITE_THREAD_DEMO=1 \"${BUNDLE}/Contents/MacOS/SiteThread\""

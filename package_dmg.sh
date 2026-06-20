#!/bin/bash

set -euo pipefail

APP_NAME="QuickLaunch"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_TEMP_DIR="dmg-temp"
DMG_NAME="${APP_NAME}-portable.dmg"
VOLUME_NAME="${APP_NAME}"

echo "Preparing DMG distribution for ${APP_NAME}..."

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "Error: ${APP_BUNDLE} not found."
    echo "Please run 'make dist' first."
    exit 1
fi

rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

cp -R "${APP_BUNDLE}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

rm -f "${DIST_DIR}/${DMG_NAME}"
/usr/bin/hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${DMG_NAME}"

rm -rf "${DMG_TEMP_DIR}"

echo "DMG created:"
echo "  ${DIST_DIR}/${DMG_NAME}"

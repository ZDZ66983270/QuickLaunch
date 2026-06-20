#!/bin/bash

set -euo pipefail

APP_NAME="QuickLaunch"
APP_BUNDLE="build/${APP_NAME}.app"
DIST_DIR="dist"
ZIP_NAME="${APP_NAME}-portable.zip"
README_NAME="README_Distribution_Guide.txt"

echo "Preparing portable distribution for ${APP_NAME}..."

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "Error: ${APP_BUNDLE} not found."
    echo "Please run 'make app' first."
    exit 1
fi

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

cp -R "${APP_BUNDLE}" "${DIST_DIR}/"

cat > "${DIST_DIR}/${README_NAME}" <<'EOF'
QuickLaunch Distribution Guide
=============================

Package contents | 交付内容
1. QuickLaunch.app
2. QuickLaunch-portable.zip
3. QuickLaunch-portable.dmg (if `make dmg` was executed)
4. README_Distribution_Guide.txt

Recommended usage | 适用场景
- Copy to another Mac and run directly
- 直接拷贝到另一台 Mac 后运行
- No Xcode or Swift installation required on the target Mac
- 目标机无需安装 Xcode 或 Swift

First launch tips | 首次打开建议
1. Copy QuickLaunch.app to Desktop or /Applications
2. 将 QuickLaunch.app 拷贝到桌面或 /Applications
3. If macOS blocks it, right-click the app and choose Open
4. 如果系统拦截，请右键应用并选择“打开”
5. Confirm Open again in the security dialog
6. 在安全弹窗中再次确认“打开”

Notes | 注意事项
- This package is currently unsigned and not notarized
- 当前分发包默认未签名、未公证
- Gatekeeper warnings may appear on the target Mac
- 目标机可能会出现 Gatekeeper 安全提示

Rebuild package | 重新打包
- `make dist`
- `make dmg`
EOF

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${DIST_DIR}/${APP_NAME}.app" "${DIST_DIR}/${ZIP_NAME}"

echo "Portable distribution created:"
echo "  ${DIST_DIR}/${APP_NAME}.app"
echo "  ${DIST_DIR}/${ZIP_NAME}"
echo "  ${DIST_DIR}/${README_NAME}"

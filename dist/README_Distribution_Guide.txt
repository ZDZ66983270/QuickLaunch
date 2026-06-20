QuickLaunch Distribution Guide | QuickLaunch 分发说明
======================================================

Package contents | 交付内容
1. QuickLaunch.app
2. QuickLaunch-portable.zip
3. QuickLaunch-portable.dmg
4. README_Distribution_Guide.txt

Use case | 适用场景
- Copy to another Mac and run directly
- 直接拷贝到另一台 Mac 后运行
- No Xcode or Swift installation is required on the target Mac
- 目标机无需安装 Xcode 或 Swift

First launch | 首次打开
1. Copy QuickLaunch.app to Desktop or /Applications
2. 将 QuickLaunch.app 拷贝到桌面或 /Applications
3. If macOS blocks the app, right-click it and choose Open
4. 如果系统拦截，请右键应用并选择“打开”
5. Confirm Open again in the security dialog
6. 在安全弹窗中再次确认“打开”

Notes | 注意事项
- The package is currently unsigned and not notarized
- 当前分发包默认未签名、未公证
- Gatekeeper warnings may appear
- 可能触发 Gatekeeper 安全提示

Rebuild | 重新打包
- make dist
- make dmg

macOS Native Launchpad Scan Paths | macOS 原生 LaunchPad 搜索目录

  主要搜索路径：

  1. /Applications - 主应用程序目录
  2. ~/Applications - 用户应用程序目录
  3. /System/Applications - 系统应用程序（macOS 10.15 Catalina 后）
  4. /System/Applications/Utilities - 系统实用工具

  额外搜索的位置：

  5. /Applications/Utilities - 应用程序实用工具文件夹
  6. /System/Library/CoreServices - 核心服务（包含 Finder.app、Dock.app 等）
  7. /System/Library/CoreServices/Applications - 核心服务应用程序（存档实用工具、目录实用工具等）

  通过 Launch Services 数据库注册的应用：

  原生 LaunchPad 实际上不是通过直接扫描文件系统，而是通过 Launch Services 数据库 获取应用列表。这个数据库包含了：
  - 所有通过 lsregister 注册的应用
  - 用户打开过的应用程序
  - 通过 Spotlight 索引的应用程序

  原生 LaunchPad 不显示的应用：

  - 命令行工具
  - 后台服务应用
  - 某些系统级应用（如 Migration Assistant）
  - 隐藏的辅助应用程序

  你可以通过以下命令查看 Launch Services 数据库中的所有应用：
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep "path:" | grep ".app"

  我们当前的实现使用的是前4个主要目录，基本覆盖了大部分常见应用。如果要完全模拟原生行为，应该考虑使用 Launch Services API 或者增加其他系统目录。

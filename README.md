# LaunchPad Clone

一个模仿 macOS Launch Pad 功能的应用程序，在 macOS 26 取消原生 Launch Pad 后提供类似的应用启动体验。

## 功能特点

- 🚀 快速启动系统中的所有应用程序
- 🔍 实时搜索和过滤应用
- 📱 网格布局显示应用图标
- 🎨 美观的毛玻璃背景效果
- 📄 分页浏览大量应用
- 🖱️ 支持拖拽排序
- 💫 流畅的动画效果

## 系统要求

- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本（用于编译）
- Swift 5.9 或更高版本

## 编译和运行

### 方法一：使用 Make 命令

```bash
# 编译项目
make build

# 直接运行
make run

# 创建 macOS 应用包
make app

# 安装到 Applications 文件夹
sudo make install

# 清理编译文件
make clean
```

### 方法二：使用 Swift Package Manager

```bash
# 编译
swift build -c release

# 运行
swift run
```

### 方法三：创建可分发的应用

```bash
# 创建应用包
make app

# 打开应用
open build/LaunchPadClone.app
```

## 使用说明

1. **启动应用**：双击应用图标或使用命令行运行
2. **搜索应用**：在顶部搜索框输入应用名称进行过滤
3. **启动应用**：单击应用图标即可启动
4. **翻页**：点击底部的页面指示器或使用手势翻页
5. **右键菜单**：右键点击应用图标可以查看更多选项

## 快捷键

- `Command + Q`：退出应用
- `Command + F`：聚焦搜索框
- `Escape`：清空搜索

## 项目结构

```
LaunchPadClone/
├── LaunchPadApp.swift      # 应用入口
├── Models/                  # 数据模型
│   └── AppItem.swift       # 应用项模型
├── Views/                   # 视图组件
│   ├── ContentView.swift   # 主视图
│   ├── AppGridView.swift   # 应用网格
│   ├── AppIconView.swift   # 应用图标
│   ├── SearchBar.swift     # 搜索栏
│   └── PageIndicator.swift # 页面指示器
├── ViewModels/             # 视图模型
│   └── AppManager.swift    # 应用管理器
├── Services/               # 服务层
│   └── AppScanner.swift    # 应用扫描器
└── Resources/              # 资源文件
```

## 已知问题

- LSSharedFileList API 在新版本 macOS 中可能被弃用
- 某些系统应用可能无法正确显示图标

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
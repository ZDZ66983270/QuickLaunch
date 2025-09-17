# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LaunchPad Clone is a macOS native application built with SwiftUI that recreates the macOS Launch Pad functionality. It's designed to replace the native Launch Pad that was removed in macOS 26, providing application discovery and launching with modern macOS 14+ APIs.

## Build and Development Commands

### Primary Commands (via Makefile)
```bash
make build          # Build release version
make run            # Run application directly
make app            # Create macOS app bundle at build/LaunchPadClone.app
make install        # Install to /Applications (requires sudo)
make clean          # Clean build artifacts
```

### Swift Package Manager
```bash
swift build -c release    # Release build
swift run                 # Development run
```

### Testing the App
```bash
make app && open build/LaunchPadClone.app
```

## Architecture Overview

### Core Architecture Pattern
The app follows MVVM architecture with reactive state management:

- **Models**: `AppItem` (app metadata) and `AppFolder` (folder grouping)
- **ViewModels**: `AppManager` (central state management via `@ObservableObject`)
- **Views**: SwiftUI views with environment object injection
- **Services**: `AppScanner` for system app discovery

### Key State Management (AppManager)
The `AppManager` class is the central coordinator managing:
- `allApps`: Master list of discovered applications
- `displayedApps`: Current filtered/sorted view
- `dragPreviewApps`: Dynamic preview during drag operations
- `currentPage`: Pagination state
- Drag state: `isDragging`, `draggedApp`, `dragHoverIndex`

### Page Navigation System
The app uses a hybrid scrolling approach in `HorizontalPageView`:
- **Primary**: Native `ScrollView` with `.scrollTargetBehavior(.paging)` for trackpad gestures
- **Secondary**: Simultaneous `DragGesture` for mouse drag support
- Both methods sync through `scrollPosition` and `currentPage` bindings

### Drag and Drop Architecture
Implements native-style drag reordering:
1. **Start**: `startDragging()` removes item from list, creates `dragPreviewApps`
2. **Hover**: `setDragHover()` dynamically inserts placeholder at hover position
3. **End**: `endDragging()` commits final position and saves preferences

The dragged item is replaced by `DragPlaceholder` during drag operations, while other items dynamically reposition with animations.

### Application Discovery
`AppScanner` searches multiple system paths:
- `/Applications`
- `~/Applications`
- `/System/Applications`
- `/System/Applications/Utilities`

Uses `Bundle` inspection for metadata and `NSWorkspace` for icons.

## Key Technical Requirements

### Platform Requirements
- **Minimum**: macOS 14.0 (uses modern ScrollView APIs)
- **Swift**: 5.9+
- **Frameworks**: SwiftUI, AppKit, Foundation

### Critical Dependencies
- `.scrollTargetBehavior(.paging)` requires macOS 14+
- `.containerRelativeFrame(.horizontal)` for responsive layout
- `NSWorkspace.shared.icon(forFile:)` for app icons

### State Persistence
User preferences saved via `UserDefaults`:
- App positions (`AppPositions` key)
- Folder configurations (`AppFolders` key)

## Component Relationships

### View Hierarchy
```
ContentView
├── SearchBar (search filtering)
├── HorizontalPageView (page navigation)
│   └── AppGridView (per-page grid)
│       └── DraggableAppIcon (individual apps)
│           ├── AppIconView (normal state)
│           └── DragPlaceholder (drag state)
└── PageIndicator (navigation dots)
```

### Data Flow
1. `AppScanner` → `AppManager.allApps`
2. Search/filter → `AppManager.displayedApps`
3. Pagination → `appsForPage()` slicing
4. Drag operations → `dragPreviewApps` for real-time preview

## Common Customizations

### Adjusting Grid Layout
Modify in `AppManager`:
```swift
let appsPerPage = 35  // Total apps per page
let columns = 7       // Grid columns
let rows = 5          // Grid rows
```

### Page Navigation Sensitivity
Adjust in `HorizontalPageView`:
```swift
DragGesture(minimumDistance: 30)  // Mouse drag threshold
let dragThreshold = screenWidth * 0.2  // Page switch threshold
```

### Visual Styling
- App icons: 128x128 pixels (doubled from original 64x64)
- Grid spacing: 50px vertical, 40px horizontal between icons
- Drag animations: 0.2s duration with `.easeInOut`

## 🔥 关键：动态图标尺寸实现规则

### 图标尺寸处理的四条基本规则
1. **根据Scale Factor选择图标资源**：使用屏幕缩放因子来请求合适的图标资源
2. **动态计算显示尺寸**：必须用实际图标尺寸 × 0.8125系数来动态计算显示大小（绝不能用固定值）
3. **固定UI元素尺寸**：其他UI元素（间距、容器）必须保持固定
4. **占位符使用标准尺寸**：图标占位符使用固定的标准尺寸，与图标的实际动态尺寸无关

### ❌ 错误的实现模式
```swift
// 不要强制创建固定尺寸的图标
let targetSize = CGSize(width: 256, height: 256)
let resizedIcon = NSImage(size: targetSize)
// 这违反了规则1和规则2
```

### ✅ 正确的实现模式
```swift
// 第1步：根据Scale Factor请求合适的资源
let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
let targetSize = NSSize(width: 128 * screenScale, height: 128 * screenScale) // 使用128逻辑点

// 第2步：让系统选择最佳表示
if let bestRep = appIcon.bestRepresentation(for: NSRect(origin: .zero, size: targetSize),
                                            context: nil, hints: nil) {

    // 第3步：读取系统返回的实际尺寸
    let originalSize = NSSize(width: bestRep.pixelsWide, height: bestRep.pixelsHigh)

    // 第4步：用实际尺寸 × 0.8125计算显示大小
    let scaledSize = NSSize(width: originalSize.width * 0.8125,
                           height: originalSize.height * 0.8125)
}
```

### 关键技术要点
- **128逻辑点**是基础单位（不是像素）
- **screenScale**将逻辑点转换为像素来请求资源
- **bestRepresentation()**让系统选择最优图标资源
- **pixelsWide/pixelsHigh**给出实际资源尺寸
- **0.8125系数**匹配macOS LaunchPad缩放行为

### 各Scale Factor下的预期结果
| Scale Factor | 请求尺寸 | 典型资源 | 显示尺寸 |
|--------------|----------|----------|----------|
| 1× | 128×128 px | 128×128 px | 104×104 px |
| 2× | 256×256 px | 256×256 px | 208×208 px |
| 3× | 384×384 px | 384×384 px | 312×312 px |
| 4× | 512×512 px | 512×512 px | 416×416 px |

### 常见错误避免
1. 🚫 强制图标创建为固定尺寸
2. 🚫 使用固定显示值而不是动态计算
3. 🚫 在targetSize中使用像素值而不是逻辑点
4. 🚫 不读取bestRepresentation的实际资源尺寸
5. 🚫 混淆物理像素和逻辑像素

## 🎯 物理像素 vs 逻辑像素

### 核心概念
- **物理像素（Physical Pixels）**：屏幕实际的像素点，图标资源的实际尺寸
- **逻辑像素/点（Logical Pixels/Points）**：SwiftUI和AppKit中的单位，与屏幕密度无关
- **Scale Factor**：物理像素与逻辑像素的转换比例（1×、2×、3×等）

### 关键转换公式
```
物理像素 = 逻辑像素 × Scale Factor
逻辑像素 = 物理像素 ÷ Scale Factor
```

### 在图标尺寸计算中的应用
1. **bestRepresentation返回的是物理像素**：
   - 2×屏幕请求128×128像素 → 返回256×256物理像素

2. **SwiftUI的frame使用逻辑像素**：
   - 必须将物理像素转换为逻辑像素
   - 错误：`.frame(width: 208, height: 208)` 其中208是物理像素值
   - 正确：`.frame(width: 104, height: 104)` 其中104是逻辑像素值

3. **正确的IconSizeCalculator实现**：
```swift
// 物理像素 × 0.8125 ÷ screenScale = 逻辑像素
let displaySize = maxDimension * displayScaleFactor / screenScale
```

### 实际例子（2×屏幕）
- 获取图标：256×256物理像素
- 应用系数：256 × 0.8125 = 208物理像素
- 转换为逻辑像素：208 ÷ 2 = 104逻辑像素
- SwiftUI显示：104×104逻辑像素
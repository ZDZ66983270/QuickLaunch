# 拖拽分组功能设计文档

## 功能概述

设计一个类似iOS LaunchPad的拖拽分组功能：当用户将一个应用图标拖拽到另一个应用图标上时，自动创建文件夹并将两个应用分组。这是一个高级交互功能，将显著提升LaunchPad Clone的用户体验。

## 技术架构

### 1. 核心交互流程

```
用户开始拖拽应用A
    ↓
检测拖拽悬停在应用B上方
    ↓
悬停超过0.5秒触发分组预览
    ↓
应用B高亮显示分组提示
    ↓
用户松开鼠标确认分组
    ↓
弹出文件夹命名对话框
    ↓
创建AppFolder对象，重新布局
```

### 2. 状态管理设计

#### AppManager 新增属性
```swift
// 分组创建相关状态
@Published var groupCreationMode: Bool = false
@Published var hoverTargetApp: AppItem? = nil
@Published var groupingApps: [AppItem] = []
@Published var hoverStartTime: Date? = nil

// 分组悬停检测参数
let groupingHoverThreshold: TimeInterval = 0.5
```

#### 新增方法
```swift
func startGroupingHover(draggedApp: AppItem, targetApp: AppItem)
func checkGroupingCondition() -> Bool
func startGroupCreation(draggedApp: AppItem, targetApp: AppItem)
func confirmGroupCreation(name: String)
func cancelGroupCreation()
func isValidGroupingTarget(app: AppItem) -> Bool
```

### 3. 拖拽检测增强

#### DraggableAppIcon 修改
```swift
struct DraggableAppIcon: View {
    @State private var hoverTimer: Timer?
    @State private var isGroupingCandidate = false

    var body: some View {
        AppIconView(app: app, isDragTarget: $isDragTarget, isGroupingCandidate: $isGroupingCandidate)
            .onDrag { /* 现有拖拽逻辑 */ }
            .onDrop(of: [.text], delegate: EnhancedAppDropDelegate(
                app: app,
                index: index,
                appManager: appManager,
                isDragTarget: $isDragTarget,
                isGroupingCandidate: $isGroupingCandidate
            ))
    }
}
```

#### AppDropDelegate 增强
```swift
class EnhancedAppDropDelegate: DropDelegate {
    // 检测分组条件
    func dropEntered(info: DropInfo) {
        // 启动悬停计时器
        startGroupingHoverTimer()
    }

    func dropExited(info: DropInfo) {
        // 清除悬停状态
        cancelGroupingHover()
    }

    func performDrop(info: DropInfo) -> Bool {
        if appManager.groupCreationMode {
            // 执行分组创建
            return handleGroupCreation()
        } else {
            // 执行正常重排序
            return handleReordering()
        }
    }
}
```

### 4. 视觉反馈设计

#### 分组预览效果
- **目标应用高亮**: 添加蓝色发光边框
- **分组提示**: 显示"创建文件夹"文字提示
- **动画效果**: 0.3秒淡入动画

#### AppIconView 增强
```swift
struct AppIconView: View {
    @Binding var isGroupingCandidate: Bool

    var body: some View {
        Image(nsImage: app.icon ?? defaultIcon)
            .frame(width: 128, height: 128)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isGroupingCandidate ? Color.blue : Color.clear, lineWidth: 3)
                            .shadow(color: isGroupingCandidate ? .blue : .clear, radius: 8)
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: isGroupingCandidate)
    }
}
```

### 5. 文件夹组件设计

#### FolderView 组件
```swift
struct FolderView: View {
    let folder: AppFolder
    @EnvironmentObject var appManager: AppManager
    @State private var isExpanded = false

    var body: some View {
        VStack {
            // 文件夹图标（2x2缩略图网格）
            FolderIconView(folder: folder)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }

            // 文件夹名称
            Text(folder.name)
                .font(.caption)
                .lineLimit(1)

            // 展开的应用网格（可选显示）
            if isExpanded {
                FolderExpandedView(folder: folder)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
```

#### FolderIconView 子组件
```swift
struct FolderIconView: View {
    let folder: AppFolder

    var body: some View {
        ZStack {
            // 文件夹背景
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 128, height: 128)

            // 应用缩略图网格 (2x2)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(50)), count: 2), spacing: 4) {
                ForEach(folder.apps.prefix(4), id: \.id) { app in
                    Image(nsImage: app.icon ?? defaultIcon)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                }
            }
            .padding(12)
        }
    }
}
```

### 6. 分组命名对话框

#### GroupCreationDialog 组件
```swift
struct GroupCreationDialog: View {
    @Binding var isPresented: Bool
    @State private var folderName = ""
    let groupingApps: [AppItem]
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("创建文件夹")
                .font(.headline)

            // 应用预览
            HStack {
                ForEach(groupingApps.prefix(2), id: \.id) { app in
                    Image(nsImage: app.icon ?? defaultIcon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(8)
                }
            }

            // 文件夹名称输入
            TextField("文件夹名称", text: $folderName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onAppear {
                    // 自动生成默认名称
                    folderName = generateDefaultFolderName(for: groupingApps)
                }

            // 按钮
            HStack {
                Button("取消") {
                    onCancel()
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("创建") {
                    onConfirm(folderName)
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(folderName.isEmpty)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}
```

### 7. 数据模型增强

#### AppFolder 扩展
```swift
extension AppFolder {
    // 生成文件夹组合图标
    var compositeIcon: NSImage? {
        let iconSize = NSSize(width: 128, height: 128)
        let image = NSImage(size: iconSize)

        image.lockFocus()

        // 绘制背景
        NSColor.systemGray.withAlphaComponent(0.2).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: iconSize), xRadius: 16, yRadius: 16).fill()

        // 绘制应用图标缩略图 (2x2网格)
        let gridSize: CGFloat = 50
        let spacing: CGFloat = 4
        let startX = (iconSize.width - (gridSize * 2 + spacing)) / 2
        let startY = (iconSize.height - (gridSize * 2 + spacing)) / 2

        for (index, app) in apps.prefix(4).enumerated() {
            if let appIcon = app.icon {
                let row = index / 2
                let col = index % 2
                let x = startX + CGFloat(col) * (gridSize + spacing)
                let y = startY + CGFloat(row) * (gridSize + spacing)

                appIcon.draw(in: NSRect(x: x, y: y, width: gridSize, height: gridSize))
            }
        }

        image.unlockFocus()
        return image
    }

    // 智能文件夹命名
    static func generateDefaultName(for apps: [AppItem]) -> String {
        // 基于应用类型智能命名
        let categories = ["工具", "游戏", "效率", "开发", "媒体"]
        // 实现分类逻辑...
        return "新文件夹"
    }
}
```

### 8. 布局集成策略

#### AppGridView 修改
```swift
struct AppGridView: View {
    var body: some View {
        LazyVGrid(columns: columns, spacing: 40) {
            ForEach(displayItems, id: \.id) { item in
                Group {
                    if let folder = item as? AppFolder {
                        FolderView(folder: folder)
                            .environmentObject(appManager)
                    } else if let app = item as? AppItem {
                        DraggableAppIcon(app: app, index: getIndex(for: app))
                            .environmentObject(appManager)
                    }
                }
            }
        }
    }

    // 统一显示项目类型
    var displayItems: [any Identifiable] {
        var items: [any Identifiable] = []

        // 添加文件夹
        items.append(contentsOf: appManager.folders)

        // 添加未分组的应用
        let ungroupedApps = appManager.displayedApps.filter { app in
            !appManager.folders.contains { folder in
                folder.apps.contains { $0.id == app.id }
            }
        }
        items.append(contentsOf: ungroupedApps)

        return items
    }
}
```

### 9. 性能优化考虑

#### 悬停检测优化
- 使用防抖机制，避免频繁触发
- 限制悬停检测范围，提高性能
- 异步处理分组创建逻辑

#### 动画性能
- 使用 `withAnimation` 确保流畅过渡
- 限制同时播放的动画数量
- 优化图标渲染性能

### 10. 测试用例设计

#### 功能测试
1. **基础分组**: 拖拽应用A到应用B，创建文件夹
2. **分组取消**: 拖拽过程中移开鼠标，取消分组
3. **文件夹命名**: 测试自定义文件夹名称
4. **文件夹展开**: 点击文件夹展开应用列表
5. **文件夹拖拽**: 整个文件夹的拖拽重排序

#### 边界测试
1. **空文件夹处理**: 文件夹中最后一个应用被移除
2. **重复分组**: 将已分组应用再次分组
3. **大量应用**: 文件夹中包含大量应用的性能
4. **快速操作**: 连续快速拖拽操作

### 11. 实现优先级

#### P0 - 核心功能 (第一阶段)
- [x] 基础拖拽分组检测
- [x] 分组创建对话框
- [x] 简单文件夹显示
- [x] 状态管理基础架构

#### P1 - 用户体验 (第二阶段)
- [ ] 悬停视觉反馈
- [ ] 分组动画效果
- [ ] 文件夹展开功能
- [ ] 智能命名建议

#### P2 - 高级功能 (第三阶段)
- [ ] 文件夹内拖拽排序
- [ ] 文件夹重命名
- [ ] 文件夹嵌套支持
- [ ] 批量分组操作

#### P3 - 优化完善 (第四阶段)
- [ ] 性能优化
- [ ] 无障碍功能支持
- [ ] 键盘快捷键
- [ ] 导入导出分组配置

## 技术风险评估

### 高风险
- **拖拽冲突**: 分组拖拽与重排序拖拽的逻辑冲突
- **状态同步**: 复杂的拖拽状态管理可能导致bug

### 中风险
- **性能影响**: 大量应用时的渲染性能
- **动画卡顿**: 复杂动画可能影响用户体验

### 低风险
- **UI适配**: 不同屏幕尺寸的布局适配
- **数据持久化**: 文件夹数据的保存和加载

## 后续扩展方向

1. **智能分组建议**: 基于应用使用频率和类型的自动分组建议
2. **文件夹主题**: 自定义文件夹图标和颜色主题
3. **分组统计**: 显示文件夹内应用的使用统计
4. **云同步**: 跨设备同步分组配置
5. **手势支持**: 支持触控板手势操作

---

*文档版本: v1.0*
*创建日期: 2025-09-17*
*最后更新: 2025-09-17*
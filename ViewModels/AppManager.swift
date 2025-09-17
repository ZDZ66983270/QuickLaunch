import Foundation
import SwiftUI
import Combine

class AppManager: ObservableObject {
    @Published var allApps: [AppItem] = []
    @Published var displayedApps: [AppItem] = []
    @Published var dragPreviewApps: [AppItem] = []
    @Published var folders: [AppFolder] = []
    @Published var searchText: String = "" {
        didSet {
            filterApps()
        }
    }
    @Published var currentPage: Int = 0
    @Published var isDragging: Bool = false
    @Published var draggedApp: AppItem?
    @Published var dragHoverIndex: Int? = nil
    
    let appsPerPage = 35
    let columns = 7
    let rows = 5

    // 第一屏优先级应用配置（按用户指定的顺序 - 使用.app文件名）
    private let firstPagePriorityApps: [String] = [
        "com.apple.AppStore",
        "com.apple.Safari",
        "com.apple.mail",
        "com.apple.AddressBook",
        "com.apple.iCal",
        "com.apple.reminders",
        "com.apple.Notes",
        "com.apple.FaceTime",
        "com.apple.MobileSMS",
        "com.apple.Maps",
        "com.apple.findmy",
        "com.apple.PhotoBooth",
        "com.apple.Photos",
        "com.apple.Music",
        "com.apple.podcasts",
        "com.apple.TV",
        "com.apple.VoiceMemos",
        "com.apple.iWork.Keynote",
        "com.apple.iWork.Numbers",
        "com.apple.iWork.Pages",
        "com.apple.weather",
        "com.apple.news",
        "com.apple.stocks",
        "com.apple.iBooksX",
        "com.apple.clock",
        "com.apple.calculator",
        "com.apple.freeform",
        "com.apple.Home",
        "com.apple.siri.launcher",
        "com.apple.ScreenContinuity",
        "com.apple.Passwords",
        "com.apple.systempreferences",
        "com.apple.Chess",
        "com.apple.Dictionary",
        "com.apple.helpviewer"
    ]

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadApps()
    }

    /// 根据第一屏优先级进行智能排序
    private func applyFirstPagePrioritySort(to apps: [AppItem]) -> [AppItem] {
        var sortedApps: [AppItem] = []
        var remainingApps = apps

        // 第一步：按优先级顺序添加第一屏应用（使用bundleIdentifier匹配）
        for priorityBundleId in firstPagePriorityApps {
            if let app = findAndRemoveApp(bundleId: priorityBundleId, from: &remainingApps) {
                sortedApps.append(app)
            }
        }

        // 第二步：如果第一屏还没满35个，用字母顺序的其他应用补足
        if sortedApps.count < appsPerPage {
            let alphabeticalApps = remainingApps.sorted { $0.package_name.lowercased() < $1.package_name.lowercased() }
            let neededApps = min(appsPerPage - sortedApps.count, alphabeticalApps.count)
            sortedApps.append(contentsOf: Array(alphabeticalApps.prefix(neededApps)))

            // 从剩余应用中移除已添加的
            for app in Array(alphabeticalApps.prefix(neededApps)) {
                remainingApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
            }
        }

        // 第三步：剩余应用按字母顺序添加到后续屏幕
        let remainingAlphabetical = remainingApps.sorted { $0.package_name.lowercased() < $1.package_name.lowercased() }
        sortedApps.append(contentsOf: remainingAlphabetical)

        return sortedApps
    }

    /// 查找并移除指定bundleIdentifier的应用
    private func findAndRemoveApp(bundleId: String, from apps: inout [AppItem]) -> AppItem? {
        if let index = apps.firstIndex(where: { $0.bundleIdentifier == bundleId }) {
            return apps.remove(at: index)
        }
        return nil
    }

    /// 重置到默认的第一屏优先级排序（调试和重置功能）
    func resetToDefaultFirstPageSorting() {
        // 清除保存的顺序和文件夹
        UserDefaults.standard.removeObject(forKey: "AppPositions")
        UserDefaults.standard.removeObject(forKey: "AppFolders")

        // 重新加载应用
        loadApps()
    }

    
    func loadApps() {
        // 先获取新扫描的应用
        let scannedApps = AppScanner.shared.scanApplications()

        // 尝试加载保存的排序，如果没有则使用智能排序
        allApps = loadSavedPositions(from: scannedApps)

        // 重新设置位置
        for (index, _) in allApps.enumerated() {
            allApps[index].position = index
        }

        displayedApps = allApps
        loadSavedFolders()
    }
    
    func filterApps() {
        if searchText.isEmpty {
            displayedApps = allApps
        } else {
            displayedApps = allApps.filter { app in
                app.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func launchApp(_ app: AppItem) {
        app.launch()
    }
    
    
    func createFolder(name: String, apps: [AppItem]) {
        let folder = AppFolder(name: name, apps: apps, position: folders.count)
        folders.append(folder)
        
        for app in apps {
            if let index = allApps.firstIndex(where: { $0.id == app.id }) {
                allApps[index].folderId = folder.id
            }
        }
        
        saveFolders()
    }
    
    func removeFromFolder(_ app: AppItem, folder: AppFolder) {
        if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }),
           let appIndex = folders[folderIndex].apps.firstIndex(where: { $0.id == app.id }) {
            folders[folderIndex].apps.remove(at: appIndex)
            
            if let globalIndex = allApps.firstIndex(where: { $0.id == app.id }) {
                allApps[globalIndex].folderId = nil
            }
            
            if folders[folderIndex].apps.isEmpty {
                folders.remove(at: folderIndex)
            }
            
            saveFolders()
        }
    }
    
    private func savePositions() {
        // 只保存bundleIdentifier的顺序，不保存整个AppItem
        let bundleIdentifiers = allApps.map { $0.bundleIdentifier }
        UserDefaults.standard.set(bundleIdentifiers, forKey: "AppPositions")
    }

    private func loadSavedPositions(from scannedApps: [AppItem]) -> [AppItem] {
        // 尝试加载保存的排序
        guard let savedBundleIds = UserDefaults.standard.array(forKey: "AppPositions") as? [String] else {
            // 没有保存的排序，使用默认的智能排序
            return applyFirstPagePrioritySort(to: scannedApps)
        }

        var sortedApps: [AppItem] = []
        var remainingApps = scannedApps

        // 按保存的顺序恢复应用
        for bundleId in savedBundleIds {
            if let app = findAndRemoveApp(bundleId: bundleId, from: &remainingApps) {
                sortedApps.append(app)
            }
        }

        // 添加新发现的应用（可能是新安装的）到末尾，按package_name排序
        let newApps = remainingApps.sorted { $0.package_name.lowercased() < $1.package_name.lowercased() }
        sortedApps.append(contentsOf: newApps)

        return sortedApps
    }
    
    
    private func saveFolders() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(folders) {
            UserDefaults.standard.set(data, forKey: "AppFolders")
        }
    }
    
    private func loadSavedFolders() {
        if let data = UserDefaults.standard.data(forKey: "AppFolders"),
           let savedFolders = try? JSONDecoder().decode([AppFolder].self, from: data) {
            folders = savedFolders
        }
    }
    
    func numberOfPages() -> Int {
        return max(1, Int(ceil(Double(displayedApps.count) / Double(appsPerPage))))
    }
    
    func appsForPage(_ page: Int) -> [AppItem] {
        let startIndex = page * appsPerPage
        let endIndex = min(startIndex + appsPerPage, displayedApps.count)

        guard startIndex < displayedApps.count else { return [] }

        return Array(displayedApps[startIndex..<endIndex])
    }

    func dragPreviewForPage(_ page: Int) -> [AppItem] {
        guard let draggedApp = draggedApp, isDragging else {
            return appsForPage(page)
        }

        let originalApps = appsForPage(page)

        // 检查被拖拽的应用是否在当前页面
        guard originalApps.contains(where: { $0.id == draggedApp.id }) else {
            return originalApps  // 被拖拽的应用不在当前页面，返回原始列表
        }

        // 移除被拖拽的应用
        var previewApps = originalApps.filter { $0.id != draggedApp.id }

        // 如果有悬停位置，插入占位符
        if let hoverIndex = dragHoverIndex {
            let clampedIndex = max(0, min(hoverIndex, previewApps.count))
            let placeholder = AppItem(
                title: "Placeholder",
                package_name: "Placeholder",
                bundleIdentifier: "placeholder",
                url: URL(fileURLWithPath: "/"),
                position: clampedIndex
            )
            previewApps.insert(placeholder, at: clampedIndex)
        }

        return previewApps
    }

    func startDragging(_ app: AppItem) {
        draggedApp = app
        isDragging = true
        dragHoverIndex = nil
    }

    func setDragHover(at index: Int) {
        dragHoverIndex = index
    }

    func moveAppDirectly(_ draggedApp: AppItem, toIndex targetIndex: Int) {
        // 简单直接：在全局数组中移动元素
        guard let currentIndex = allApps.firstIndex(where: { $0.id == draggedApp.id }) else { return }

        // 计算目标位置在全局数组中的索引
        let pageStartIndex = currentPage * appsPerPage
        let globalTargetIndex = pageStartIndex + targetIndex
        let clampedGlobalIndex = max(0, min(globalTargetIndex, allApps.count - 1))

        // 如果位置相同，不需要移动
        if currentIndex == clampedGlobalIndex { return }

        // 移除元素并插入到新位置
        let app = allApps.remove(at: currentIndex)
        allApps.insert(app, at: clampedGlobalIndex)

        // 更新displayedApps
        displayedApps = allApps

        // 重新设置位置
        for (index, _) in allApps.enumerated() {
            allApps[index].position = index
        }

        savePositions()
    }

    func endDragging() {
        // 如果有拖拽的应用和悬停位置，执行移动
        if let draggedApp = draggedApp, let hoverIndex = dragHoverIndex {
            // 简单直接的移动逻辑
            let currentPageApps = appsForPage(currentPage)
            let globalStartIndex = currentPage * appsPerPage

            // 从原位置移除
            if let originalIndex = displayedApps.firstIndex(where: { $0.id == draggedApp.id }) {
                displayedApps.remove(at: originalIndex)
            }

            // 插入到新位置
            let targetGlobalIndex = globalStartIndex + hoverIndex
            let clampedIndex = min(targetGlobalIndex, displayedApps.count)
            displayedApps.insert(draggedApp, at: clampedIndex)

            // 更新所有位置
            allApps = displayedApps
            for (index, app) in allApps.enumerated() {
                allApps[index].position = index
            }
            savePositions()
        }

        // 清理拖拽状态
        isDragging = false
        draggedApp = nil
        dragHoverIndex = nil
        dragPreviewApps = []
    }

}
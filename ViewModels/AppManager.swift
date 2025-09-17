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
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadApps()
    }
    
    func loadApps() {
        // 先获取新扫描的应用
        let scannedApps = AppScanner.shared.scanApplications()

        // 如果有保存的顺序，按顺序重建；否则使用扫描顺序
        if let savedOrder = UserDefaults.standard.array(forKey: "AppPositions") as? [String] {
            var reorderedApps: [AppItem] = []

            // 先添加保存顺序中仍然存在的应用
            for bundleId in savedOrder {
                if let app = scannedApps.first(where: { $0.bundleIdentifier == bundleId }) {
                    reorderedApps.append(app)
                }
            }

            // 再添加新扫描到的应用（不在保存列表中的），按字母顺序
            let newApps = scannedApps.filter { !savedOrder.contains($0.bundleIdentifier) }
            let sortedNewApps = newApps.sorted { $0.name.lowercased() < $1.name.lowercased() }
            reorderedApps.append(contentsOf: sortedNewApps)

            allApps = reorderedApps
        } else {
            // 首次运行，按字母顺序排列
            allApps = scannedApps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }

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
                app.name.localizedCaseInsensitiveContains(searchText)
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
                name: "Placeholder",
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
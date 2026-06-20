import Foundation
import SwiftUI
import Combine
import os

class AppManager: ObservableObject {
    @Published var allApps: [AppItem] = []
    @Published var displayedApps: [AppItem] = []
    @Published var folders: [AppFolder] = []
    @Published var searchText: String = "" {
        didSet {
            filterApps()
        }
    }
    @Published var currentPage: Int = 0
    @Published var isDragging: Bool = false
    @Published var draggedApp: AppItem?
    @Published var draggedFolder: AppFolder?
    @Published var dragHoverIndex: Int?
    @Published var dragHoverPage: Int?
    @Published var dragHoverAppId: String?
    @Published var dragHoverFolderId: UUID?
    @Published var groupingTargetApp: AppItem?
    @Published var expandedFolder: AppFolder?
    @Published var folderDragHoverAppId: String?

    private let logger = Logger(subsystem: "com.quicklaunch.macos", category: "AppManager")

    let columns = 7
    @Published var rows = 5
    @Published var appsPerPage = 35

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

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canOrganize: Bool {
        !isSearching
    }

    init() {
        loadAppsFromCache()
    }

    func updateLayoutForScreenHeight(_ screenHeight: CGFloat) {
        if screenHeight <= 982 {
            rows = 4
            appsPerPage = columns * rows
        } else {
            rows = 5
            appsPerPage = columns * rows
        }
    }

    func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scannedApps = AppScanner.shared.scanApplications()
            let sortedApps = self.loadSavedPositions(from: scannedApps)

            DispatchQueue.main.async {
                self.allApps = sortedApps
                self.reindexApps()
                self.loadSavedFolders()
                self.refreshDisplayedApps()
                self.logger.info("Apps loaded successfully: \(scannedApps.count) apps found")
            }
        }
    }

    func filterApps() {
        if isSearching {
            displayedApps = allApps.filter { app in
                app.title.localizedCaseInsensitiveContains(searchText)
            }
            currentPage = 0
        } else {
            refreshDisplayedApps()
        }
    }

    func launchApp(_ app: AppItem) {
        app.launch()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hideQuickLaunchApp()
        }
    }

    func openFolder(_ folder: AppFolder) {
        expandedFolder = currentFolder(with: folder.id)
    }

    func closeFolder() {
        expandedFolder = nil
    }

    func renameFolder(_ folder: AppFolder, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        folders[folderIndex].name = trimmedName
        saveFolders()
        if expandedFolder?.id == folder.id {
            expandedFolder = folders[folderIndex]
        }
        refreshDisplayedApps()
    }

    func createFolder(name: String, apps: [AppItem], insertAt position: Int? = nil) {
        let uniqueApps = Array(Dictionary(grouping: apps, by: \.bundleIdentifier).compactMap { $0.value.first })
        guard uniqueApps.count >= 2 else { return }

        let insertionPosition = position ?? uniqueApps.map(\.position).min() ?? folders.count
        let folderId = UUID()
        let folderApps = uniqueApps.sorted { $0.position < $1.position }

        for app in folderApps {
            if let index = allApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                allApps[index].folderId = folderId
            }
        }

        let folder = AppFolder(
            id: folderId,
            name: name,
            apps: folderApps,
            position: insertionPosition
        )
        folders.append(folder)

        normalizeRootPositions()
        refreshDisplayedApps()
    }

    func addApp(_ app: AppItem, to folder: AppFolder) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        guard !folders[folderIndex].apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }

        if let sourceFolderId = app.folderId, sourceFolderId != folder.id {
            detachAppFromFolder(app, folderId: sourceFolderId)
        }

        if let index = allApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            allApps[index].folderId = folder.id
            folders[folderIndex].apps.append(allApps[index])
            folders[folderIndex].apps.sort { $0.position < $1.position }
            normalizeRootPositions()
            refreshDisplayedApps()
            expandedFolder = currentFolder(with: folder.id)
        }
    }

    func removeFromFolder(_ app: AppItem, folder: AppFolder) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folder.id }),
              let appIndex = folders[folderIndex].apps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
            return
        }

        folders[folderIndex].apps.remove(at: appIndex)

        if let globalIndex = allApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            allApps[globalIndex].folderId = nil
            allApps[globalIndex].position = folders[folderIndex].position
        }

        if folders[folderIndex].apps.count <= 1 {
            dissolveFolder(at: folderIndex)
        } else {
            saveFolders()
        }

        normalizeRootPositions()
        refreshDisplayedApps()
        expandedFolder = currentFolder(with: folder.id)
    }

    func moveDraggedAppToRoot(at targetIndex: Int? = nil) {
        guard let draggedApp = draggedApp else { return }
        moveApp(draggedApp, to: targetIndex)
    }

    func moveAppWithinExpandedFolder(to targetApp: AppItem) {
        guard let draggedApp = draggedApp,
              let sourceFolderId = draggedApp.folderId,
              let targetFolderId = targetApp.folderId,
              sourceFolderId == targetFolderId,
              let folderIndex = folders.firstIndex(where: { $0.id == sourceFolderId }),
              let sourceIndex = folders[folderIndex].apps.firstIndex(where: { $0.bundleIdentifier == draggedApp.bundleIdentifier }),
              let targetIndex = folders[folderIndex].apps.firstIndex(where: { $0.bundleIdentifier == targetApp.bundleIdentifier }) else {
            return
        }

        if sourceIndex == targetIndex { return }

        let movedApp = folders[folderIndex].apps.remove(at: sourceIndex)
        folders[folderIndex].apps.insert(movedApp, at: targetIndex)
        saveFolders()
        expandedFolder = folders[folderIndex]
    }

    func appendDraggedAppToExpandedFolder() {
        guard let draggedApp = draggedApp,
              let expandedFolder = expandedFolder else {
            return
        }

        if draggedApp.folderId == expandedFolder.id {
            guard let folderIndex = folders.firstIndex(where: { $0.id == expandedFolder.id }),
                  let sourceIndex = folders[folderIndex].apps.firstIndex(where: { $0.bundleIdentifier == draggedApp.bundleIdentifier }) else {
                return
            }

            let movedApp = folders[folderIndex].apps.remove(at: sourceIndex)
            folders[folderIndex].apps.append(movedApp)
            saveFolders()
            self.expandedFolder = folders[folderIndex]
            return
        }

        addApp(draggedApp, to: expandedFolder)
    }

    func setFolderDragHover(app: AppItem?) {
        folderDragHoverAppId = app?.bundleIdentifier
    }

    func isFolderDragHoverTarget(_ app: AppItem) -> Bool {
        folderDragHoverAppId == app.bundleIdentifier
    }

    func numberOfPages() -> Int {
        let count = currentEntries().count
        return max(1, Int(ceil(Double(count) / Double(appsPerPage))))
    }

    func dragPreviewForPage(_ page: Int) -> [GridEntry] {
        let originalEntries = entriesForPage(page)
        guard canOrganize, isDragging, let draggedItem = draggedItem else {
            return originalEntries
        }

        guard originalEntries.contains(where: {
            switch ($0, draggedItem) {
            case (.app(let app), .app(let draggedApp)):
                return app.bundleIdentifier == draggedApp.bundleIdentifier
            case (.folder(let folder), .folder(let draggedFolder)):
                return folder.id == draggedFolder.id
            default:
                return false
            }
        }) else {
            return originalEntries
        }

        // When hovering over an app to create a folder, keep the grid stable so
        // the dragged icon can visually overlap the target instead of reflowing
        // the surrounding icons away from it.
        if dragHoverAppId != nil || dragHoverFolderId != nil || groupingTargetApp != nil {
            return originalEntries
        }

        var previewEntries = originalEntries.filter {
            switch ($0, draggedItem) {
            case (.app(let app), .app(let draggedApp)):
                return app.bundleIdentifier != draggedApp.bundleIdentifier
            case (.folder(let folder), .folder(let draggedFolder)):
                return folder.id != draggedFolder.id
            default:
                return true
            }
        }

        if dragHoverPage == page,
           let hoverIndex = dragHoverIndex {
            let clampedIndex = max(0, min(hoverIndex, previewEntries.count))
            previewEntries.insert(.placeholder(clampedIndex), at: clampedIndex)
        }

        return previewEntries
    }

    func startDragging(_ app: AppItem) {
        guard canOrganize else { return }
        draggedApp = app
        draggedFolder = nil
        isDragging = true
        dragHoverIndex = nil
        dragHoverPage = nil
        dragHoverAppId = nil
        dragHoverFolderId = nil
        groupingTargetApp = nil
    }

    func startDragging(_ folder: AppFolder) {
        guard canOrganize else { return }
        draggedFolder = folder
        draggedApp = nil
        isDragging = true
        dragHoverIndex = nil
        dragHoverPage = nil
        dragHoverAppId = nil
        dragHoverFolderId = nil
        groupingTargetApp = nil
    }

    func setDragHover(page: Int, at index: Int) {
        guard canOrganize else { return }
        dragHoverPage = page
        dragHoverIndex = index
    }

    func setDragHoverApp(_ app: AppItem?) {
        dragHoverAppId = app?.bundleIdentifier
    }

    func setDragHoverFolder(_ folder: AppFolder?) {
        dragHoverFolderId = folder?.id
    }

    func beginGrouping(over app: AppItem) {
        groupingTargetApp = app
    }

    func cancelGrouping(over app: AppItem? = nil) {
        guard let app else {
            groupingTargetApp = nil
            return
        }

        if groupingTargetApp?.bundleIdentifier == app.bundleIdentifier {
            groupingTargetApp = nil
        }
    }

    func isGroupingCandidate(_ app: AppItem) -> Bool {
        groupingTargetApp?.bundleIdentifier == app.bundleIdentifier
    }

    func moveDraggedApp(to page: Int, index: Int) {
        guard let draggedApp = draggedApp else { return }
        moveApp(draggedApp, to: page * appsPerPage + index)
    }

    func moveDraggedFolder(to page: Int, index: Int) {
        guard let draggedFolder = draggedFolder else { return }
        moveFolder(draggedFolder, to: page * appsPerPage + index)
    }

    func moveDraggedAppToEnd(of page: Int) {
        guard let draggedApp = draggedApp else { return }
        let pageEntries = entriesForPage(page)
        moveApp(draggedApp, to: page * appsPerPage + pageEntries.count)
    }

    func moveDraggedFolderToEnd(of page: Int) {
        guard let draggedFolder = draggedFolder else { return }
        let pageEntries = entriesForPage(page)
        moveFolder(draggedFolder, to: page * appsPerPage + pageEntries.count)
    }

    func createFolderFromDraggedApp(over targetApp: AppItem) {
        guard let draggedApp = draggedApp,
              draggedApp.bundleIdentifier != targetApp.bundleIdentifier,
              draggedApp.folderId == nil,
              targetApp.folderId == nil else {
            return
        }

        createFolder(
            name: suggestedFolderName(for: [draggedApp, targetApp]),
            apps: [draggedApp, targetApp],
            insertAt: min(draggedApp.position, targetApp.position)
        )
    }

    func addDraggedApp(to folder: AppFolder) {
        guard let draggedApp = draggedApp else { return }

        addApp(draggedApp, to: folder)
    }

    func endDragging() {
        isDragging = false
        draggedApp = nil
        draggedFolder = nil
        dragHoverIndex = nil
        dragHoverPage = nil
        dragHoverAppId = nil
        dragHoverFolderId = nil
        groupingTargetApp = nil
        folderDragHoverAppId = nil
    }

    func resetToDefaultFirstPageSorting() {
        UserDefaults.standard.removeObject(forKey: "AppPositions")
        UserDefaults.standard.removeObject(forKey: "AppFolders")
        AppScanner.shared.clearCache()
        loadApps()
    }

    private func loadAppsFromCache() {
        let cachedApps = AppScanner.shared.loadFromCache()
        if !cachedApps.isEmpty {
            let sortedApps = loadSavedPositions(from: cachedApps)
            allApps = sortedApps
            reindexApps()
            loadSavedFolders()
            refreshDisplayedApps()
        }

        startBackgroundUpdate()
    }

    private func startBackgroundUpdate() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            let freshApps = AppScanner.shared.scanApplications()
            let sortedApps = self.loadSavedPositions(from: freshApps)

            DispatchQueue.main.async {
                if sortedApps.count != self.allApps.count ||
                    !sortedApps.elementsEqual(self.allApps, by: { $0.bundleIdentifier == $1.bundleIdentifier }) {
                    self.allApps = sortedApps
                    self.reindexApps()
                    self.loadSavedFolders()
                    self.refreshDisplayedApps()
                    self.logger.info("Background app update completed successfully")
                }
            }
        }
    }

    private func applyFirstPagePrioritySort(to apps: [AppItem]) -> [AppItem] {
        var sortedApps: [AppItem] = []
        var remainingApps = apps

        for priorityBundleId in firstPagePriorityApps {
            if let app = findAndRemoveApp(bundleId: priorityBundleId, from: &remainingApps) {
                sortedApps.append(app)
            }
        }

        if sortedApps.count < appsPerPage {
            let alphabeticalApps = remainingApps.sorted { $0.package_name.lowercased() < $1.package_name.lowercased() }
            let neededApps = min(appsPerPage - sortedApps.count, alphabeticalApps.count)
            sortedApps.append(contentsOf: Array(alphabeticalApps.prefix(neededApps)))

            for app in Array(alphabeticalApps.prefix(neededApps)) {
                remainingApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
            }
        }

        let remainingAlphabetical = remainingApps.sorted { $0.package_name.lowercased() < $1.package_name.lowercased() }
        sortedApps.append(contentsOf: remainingAlphabetical)

        return sortedApps
    }

    private func findAndRemoveApp(bundleId: String, from apps: inout [AppItem]) -> AppItem? {
        guard let index = apps.firstIndex(where: { $0.bundleIdentifier == bundleId }) else {
            return nil
        }

        return apps.remove(at: index)
    }

    private func savePositions() {
        let bundleIdentifiers = allApps.sorted { $0.position < $1.position }.map { $0.bundleIdentifier }
        UserDefaults.standard.set(bundleIdentifiers, forKey: "AppPositions")
    }

    private func loadSavedPositions(from scannedApps: [AppItem]) -> [AppItem] {
        guard let savedBundleIds = UserDefaults.standard.array(forKey: "AppPositions") as? [String] else {
            return applyFirstPagePrioritySort(to: scannedApps)
        }

        var sortedApps: [AppItem] = []
        var remainingApps = scannedApps

        for bundleId in savedBundleIds {
            if let app = findAndRemoveApp(bundleId: bundleId, from: &remainingApps) {
                sortedApps.append(app)
            }
        }

        let newApps = remainingApps.sorted { $0.package_name.lowercased() < $1.package_name.lowercased() }
        sortedApps.append(contentsOf: newApps)

        return sortedApps
    }

    private func saveFolders() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(folders.sorted { $0.position < $1.position }) {
            UserDefaults.standard.set(data, forKey: "AppFolders")
        }
    }

    private func loadSavedFolders() {
        allApps.indices.forEach { allApps[$0].folderId = nil }

        guard let data = UserDefaults.standard.data(forKey: "AppFolders"),
              let savedFolders = try? JSONDecoder().decode([AppFolder].self, from: data) else {
            folders = []
            return
        }

        var restoredFolders: [AppFolder] = []
        for savedFolder in savedFolders.sorted(by: { $0.position < $1.position }) {
            let restoredApps = savedFolder.apps.compactMap { savedApp in
                allApps.first(where: { $0.bundleIdentifier == savedApp.bundleIdentifier })
            }

            guard restoredApps.count >= 2 else { continue }

            for restoredApp in restoredApps {
                if let index = allApps.firstIndex(where: { $0.bundleIdentifier == restoredApp.bundleIdentifier }) {
                    allApps[index].folderId = savedFolder.id
                }
            }

            restoredFolders.append(
                AppFolder(
                    id: savedFolder.id,
                    name: savedFolder.name,
                    apps: restoredApps,
                    position: savedFolder.position
                )
            )
        }

        folders = restoredFolders
        normalizeRootPositions(save: false)
    }

    private func refreshDisplayedApps() {
        displayedApps = allApps.sorted { $0.position < $1.position }
        currentPage = min(currentPage, max(0, numberOfPages() - 1))
    }

    private func reindexApps() {
        for (index, _) in allApps.enumerated() {
            allApps[index].position = index
        }
    }

    private func currentEntries() -> [GridEntry] {
        if isSearching {
            return displayedApps.map(GridEntry.app)
        }

        return rootEntries()
    }

    private func entriesForPage(_ page: Int) -> [GridEntry] {
        let entries = currentEntries()
        let startIndex = page * appsPerPage
        let endIndex = min(startIndex + appsPerPage, entries.count)

        guard startIndex < entries.count else { return [] }
        return Array(entries[startIndex..<endIndex])
    }

    private func rootEntries() -> [GridEntry] {
        let rootApps = allApps
            .filter { $0.folderId == nil }
            .map(GridEntry.app)
        let folderEntries = folders.map(GridEntry.folder)

        return (rootApps + folderEntries).sorted { lhs, rhs in
            if lhs.position == rhs.position {
                return lhs.id < rhs.id
            }
            return lhs.position < rhs.position
        }
    }

    private func moveApp(_ app: AppItem, to targetIndex: Int?) {
        if let sourceFolderId = app.folderId {
            detachAppFromFolder(app, folderId: sourceFolderId)
        }

        var entries = rootEntries()
        if let originalIndex = entries.firstIndex(where: {
            if case .app(let currentApp) = $0 {
                return currentApp.bundleIdentifier == app.bundleIdentifier
            }
            return false
        }) {
            entries.remove(at: originalIndex)
        }

        guard let appIndex = allApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
            return
        }

        allApps[appIndex].folderId = nil
        let movingEntry = GridEntry.app(allApps[appIndex])
        let resolvedIndex = targetIndex ?? entries.count
        let clampedIndex = max(0, min(resolvedIndex, entries.count))
        entries.insert(movingEntry, at: clampedIndex)
        applyRootEntryOrder(entries)
    }

    private func moveFolder(_ folder: AppFolder, to targetIndex: Int) {
        var entries = rootEntries()
        guard let originalIndex = entries.firstIndex(where: {
            if case .folder(let currentFolder) = $0 {
                return currentFolder.id == folder.id
            }
            return false
        }) else {
            return
        }

        let movingEntry = entries.remove(at: originalIndex)
        let clampedIndex = max(0, min(targetIndex, entries.count))
        entries.insert(movingEntry, at: clampedIndex)
        applyRootEntryOrder(entries)
    }

    private func applyRootEntryOrder(_ entries: [GridEntry]) {
        applyRootEntryOrder(entries, persist: true)
    }

    private func applyRootEntryOrder(_ entries: [GridEntry], persist: Bool) {
        for (index, entry) in entries.enumerated() {
            switch entry {
            case .app(let app):
                if let appIndex = allApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                    allApps[appIndex].position = index
                }
            case .folder(let folder):
                if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
                    folders[folderIndex].position = index
                }
            case .placeholder:
                break
            }
        }

        if persist {
            savePositions()
            saveFolders()
        }
        refreshDisplayedApps()
    }

    private func normalizeRootPositions(save: Bool = true) {
        applyRootEntryOrder(rootEntries(), persist: save)
    }

    private func dissolveFolder(at folderIndex: Int) {
        let folder = folders[folderIndex]
        let releasePosition = folder.position
        let remainingApps = folder.apps

        folders.remove(at: folderIndex)

        for (offset, remainingApp) in remainingApps.enumerated() {
            if let appIndex = allApps.firstIndex(where: { $0.bundleIdentifier == remainingApp.bundleIdentifier }) {
                allApps[appIndex].folderId = nil
                allApps[appIndex].position = releasePosition + offset
            }
        }
    }

    private func currentFolder(with id: UUID) -> AppFolder? {
        folders.first(where: { $0.id == id })
    }

    private func detachAppFromFolder(_ app: AppItem, folderId: UUID) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }),
              let appIndex = folders[folderIndex].apps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
            return
        }

        folders[folderIndex].apps.remove(at: appIndex)

        if let globalIndex = allApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            allApps[globalIndex].folderId = nil
        }

        if folders[folderIndex].apps.count <= 1 {
            dissolveFolder(at: folderIndex)
        } else {
            let folder = folders[folderIndex]
            saveFolders()
            expandedFolder = currentFolder(with: folder.id)
        }
    }

    private var draggedItem: DraggedGridItem? {
        if let draggedApp {
            return .app(draggedApp)
        }

        if let draggedFolder {
            return .folder(draggedFolder)
        }

        return nil
    }

    private func suggestedFolderName(for apps: [AppItem]) -> String {
        let titles = apps.map(\.title)
        if titles.allSatisfy({ $0.localizedCaseInsensitiveContains("Safari") || $0.localizedCaseInsensitiveContains("Chrome") }) {
            return "浏览器"
        }

        if let firstTitle = titles.first, titles.count == 2 {
            return "\(firstTitle) 文件夹"
        }

        return "新文件夹"
    }
}

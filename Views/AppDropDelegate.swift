import SwiftUI

struct AppDropDelegate: DropDelegate {
    let app: AppItem
    let pageIndex: Int
    let index: Int
    let appManager: AppManager
    @Binding var isDragTarget: Bool
    @Binding var groupingTimer: Timer?

    func performDrop(info: DropInfo) -> Bool {
        defer {
            invalidateGroupingTimer()
            isDragTarget = false
            appManager.endDragging()
        }

        guard appManager.draggedApp != nil || appManager.draggedFolder != nil else {
            return false
        }

        if appManager.draggedApp != nil, appManager.isGroupingCandidate(app) {
            appManager.createFolderFromDraggedApp(over: app)
        } else if appManager.draggedFolder != nil {
            appManager.moveDraggedFolder(to: pageIndex, index: index)
        } else {
            appManager.moveDraggedApp(to: pageIndex, index: index)
        }

        return true
    }

    func dropEntered(info: DropInfo) {
        if appManager.draggedFolder != nil {
            withAnimation(.easeInOut(duration: 0.15)) {
                isDragTarget = true
            }
            appManager.setDragHover(page: pageIndex, at: index)
            appManager.setDragHoverApp(nil)
            appManager.setDragHoverFolder(nil)
            return
        }

        guard let draggedApp = appManager.draggedApp,
              draggedApp.bundleIdentifier != app.bundleIdentifier else {
            return
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            isDragTarget = true
        }
        appManager.setDragHover(page: pageIndex, at: index)
        appManager.setDragHoverApp(app)
        appManager.setDragHoverFolder(nil)

        invalidateGroupingTimer()
        groupingTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
            DispatchQueue.main.async {
                appManager.beginGrouping(over: app)
            }
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isDragTarget = false
        }
        invalidateGroupingTimer()
        appManager.setDragHoverApp(nil)
        appManager.setDragHoverFolder(nil)
        appManager.cancelGrouping(over: app)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard appManager.canOrganize else { return false }

        if appManager.draggedFolder != nil {
            return true
        }

        return appManager.draggedApp != nil &&
        appManager.draggedApp?.bundleIdentifier != app.bundleIdentifier
    }

    private func invalidateGroupingTimer() {
        groupingTimer?.invalidate()
        groupingTimer = nil
    }
}

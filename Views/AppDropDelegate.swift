import SwiftUI

struct AppDropDelegate: DropDelegate {
    let app: AppItem
    let index: Int
    let appManager: AppManager
    @Binding var isDragTarget: Bool

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedApp = appManager.draggedApp else {
            isDragTarget = false
            return false
        }

        // 设置最终的悬停位置，让endDragging处理移动
        appManager.setDragHover(at: index)

        isDragTarget = false
        appManager.endDragging()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedApp = appManager.draggedApp else { return }

        if draggedApp.id != app.id {
            withAnimation(.easeInOut(duration: 0.15)) {
                isDragTarget = true
                appManager.setDragHover(at: index)
            }
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isDragTarget = false
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        // 不允许拖拽到占位符上
        guard app.bundleIdentifier != "placeholder" else {
            return false
        }

        return appManager.draggedApp != nil && appManager.draggedApp?.id != app.id
    }
}
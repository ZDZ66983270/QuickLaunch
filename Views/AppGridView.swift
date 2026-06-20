import SwiftUI

struct AppGridView: View {
    let pageIndex: Int
    @EnvironmentObject var appManager: AppManager
    @State private var defaultIconSize: CGSize = CGSize(width: 128, height: 128)

    let columns = Array(repeating: GridItem(.fixed(180), spacing: 0, alignment: .top), count: 7)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 55) {
                ForEach(Array(appManager.dragPreviewForPage(pageIndex).enumerated()), id: \.element.id) { index, entry in
                    switch entry {
                    case .app(let app):
                        DraggableAppIcon(app: app, pageIndex: pageIndex, index: index)
                            .environmentObject(appManager)
                            .transition(.scale.combined(with: .opacity))
                    case .folder(let folder):
                        FolderView(folder: folder, pageIndex: pageIndex, index: index)
                            .environmentObject(appManager)
                            .transition(.scale.combined(with: .opacity))
                    case .placeholder:
                        DragPlaceholder(iconSize: defaultIconSize)
                    }
                }
            }
            .padding(50)
        }
        .scrollDisabled(false)
        .onAppear {
            calculateDefaultIconSize()
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            guard appManager.canOrganize, appManager.isDragging else {
                return false
            }

            if appManager.draggedFolder != nil {
                if appManager.dragHoverPage == pageIndex,
                   let hoverIndex = appManager.dragHoverIndex {
                    appManager.moveDraggedFolder(to: pageIndex, index: hoverIndex)
                } else {
                    appManager.moveDraggedFolderToEnd(of: pageIndex)
                }
            } else {
                if appManager.dragHoverPage == pageIndex,
                   let hoverIndex = appManager.dragHoverIndex,
                   appManager.groupingTargetApp == nil {
                    appManager.moveDraggedApp(to: pageIndex, index: hoverIndex)
                } else {
                    appManager.moveDraggedAppToEnd(of: pageIndex)
                }
            }
            appManager.endDragging()
            return true
        }
    }

    private func calculateDefaultIconSize() {
        defaultIconSize = IconSizeCalculator.calculateDisplaySize(for: nil)
    }
}

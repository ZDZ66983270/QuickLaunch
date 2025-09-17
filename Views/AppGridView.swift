import SwiftUI

struct AppGridView: View {
    let apps: [AppItem]
    let pageIndex: Int
    @EnvironmentObject var appManager: AppManager

    let columns = Array(repeating: GridItem(.fixed(180), spacing: 40), count: 7)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 50) {
                ForEach(Array(appManager.dragPreviewForPage(pageIndex).enumerated()), id: \.element.id) { index, app in
                    if app.bundleIdentifier == "placeholder" {
                        DragPlaceholder()
                    } else {
                        DraggableAppIcon(app: app, index: index)
                            .environmentObject(appManager)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(50)
        }
        .scrollDisabled(false)  // 重新启用垂直滚动
        .onDrop(of: [.text], isTargeted: nil) { providers in
            appManager.endDragging()
            return true
        }
    }
}
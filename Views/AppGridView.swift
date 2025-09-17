import SwiftUI

struct AppGridView: View {
    let apps: [AppItem]
    let pageIndex: Int
    @EnvironmentObject var appManager: AppManager
    @State private var defaultIconSize: CGSize = CGSize(width: 128, height: 128)

    let columns = Array(repeating: GridItem(.fixed(180), spacing: 40, alignment: .top), count: 7)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 50) {
                ForEach(Array(appManager.dragPreviewForPage(pageIndex).enumerated()), id: \.element.id) { index, app in
                    if app.bundleIdentifier == "placeholder" {
                        DragPlaceholder(iconSize: defaultIconSize)
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
        .onAppear {
            calculateDefaultIconSize()
        }
        .onDrop(of: [.text], isTargeted: nil) { providers in
            appManager.endDragging()
            return true
        }
    }

    private func calculateDefaultIconSize() {
        guard let mainScreen = NSScreen.main else {
            defaultIconSize = CGSize(width: 128, height: 128)
            return
        }

        let scaleFactor = mainScreen.backingScaleFactor
        let preferredBaseSize = IconSizeCalculator.getPreferredBaseSize(for: scaleFactor)
        let displaySize = preferredBaseSize * IconSizeCalculator.displayScaleFactor

        defaultIconSize = CGSize(width: displaySize, height: displaySize)
    }
}
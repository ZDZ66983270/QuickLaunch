import SwiftUI

struct DraggableAppIcon: View {
    let app: AppItem
    let index: Int
    @EnvironmentObject var appManager: AppManager
    @State private var isDragTarget = false

    var body: some View {
        AppIconView(app: app, isDragTarget: $isDragTarget)
            .onDrag {
                appManager.startDragging(app)
                return NSItemProvider(object: app.title as NSString)
            }
            .onDrop(of: [.text], delegate: AppDropDelegate(
                app: app,
                index: index,
                appManager: appManager,
                isDragTarget: $isDragTarget
            ))
    }
}
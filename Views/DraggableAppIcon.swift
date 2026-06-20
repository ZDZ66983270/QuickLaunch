import SwiftUI

struct DraggableAppIcon: View {
    let app: AppItem
    let pageIndex: Int
    let index: Int
    @EnvironmentObject var appManager: AppManager
    @State private var isDragTarget = false
    @State private var groupingTimer: Timer?

    var body: some View {
        Group {
            if appManager.canOrganize {
                AppIconView(
                    app: app,
                    isDragTarget: $isDragTarget,
                    isGroupingCandidate: appManager.isGroupingCandidate(app)
                )
                .onDrag {
                    appManager.startDragging(app)
                    return NSItemProvider(object: app.title as NSString)
                }
                .onDrop(of: [.text], delegate: AppDropDelegate(
                    app: app,
                    pageIndex: pageIndex,
                    index: index,
                    appManager: appManager,
                    isDragTarget: $isDragTarget,
                    groupingTimer: $groupingTimer
                ))
            } else {
                AppIconView(
                    app: app,
                    isDragTarget: $isDragTarget
                )
            }
        }
    }
}

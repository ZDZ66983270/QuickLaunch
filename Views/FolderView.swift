import SwiftUI

struct FolderView: View {
    let folder: AppFolder
    let pageIndex: Int
    let index: Int
    @EnvironmentObject var appManager: AppManager
    @State private var isDropTarget = false

    var body: some View {
        Group {
            if appManager.canOrganize {
                folderCard
                    .onDrag {
                        appManager.startDragging(folder)
                        return NSItemProvider(object: folder.name as NSString)
                    }
                    .onDrop(of: [.text], delegate: FolderDropDelegate(
                        folder: folder,
                        pageIndex: pageIndex,
                        index: index,
                        appManager: appManager,
                        isDropTarget: $isDropTarget
                    ))
            } else {
                folderCard
            }
        }
    }

    private var folderCard: some View {
        VStack(spacing: 8) {
            FolderIconView(
                folder: folder,
                isDropTarget: isDropTarget,
                isBeingDragged: appManager.draggedFolder?.id == folder.id
            )
                .onTapGesture {
                    appManager.openFolder(folder)
                }

            Text(folder.name)
                .font(.system(size: 14))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
        }
        .contentShape(Rectangle())
    }
}

struct FolderIconView: View {
    let folder: AppFolder
    var isDropTarget: Bool = false
    var isBeingDragged: Bool = false

    private let tileSize: CGFloat = 128

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.14))
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.black.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(isDropTarget ? Color.blue.opacity(0.9) : Color.white.opacity(0.16), lineWidth: isDropTarget ? 3 : 1)
                )
                .frame(width: tileSize, height: tileSize)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .opacity(isBeingDragged ? 0.55 : 1.0)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(42), spacing: 6), count: 2), spacing: 6) {
                ForEach(Array(folder.apps.prefix(4)), id: \.bundleIdentifier) { app in
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 42, height: 42)
                    }
                }
            }
        }
    }
}

struct FolderExpandedView: View {
    let folder: AppFolder
    @EnvironmentObject var appManager: AppManager
    @State private var draftName = ""
    @State private var isAppendDropTarget = false
    @State private var isBackgroundDropTarget = false
    @FocusState private var nameFieldFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(160), spacing: 18), count: 4)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .overlay {
                    if isBackgroundDropTarget {
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                            .padding(30)
                    }
                }
                .onTapGesture {
                    appManager.closeFolder()
                }
                .onDrop(of: [.text], delegate: FolderBackgroundDropDelegate(
                    appManager: appManager,
                    isTargeted: $isBackgroundDropTarget
                ))

            VStack(spacing: 20) {
                HStack {
                    TextField("文件夹名称", text: $draftName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                        .focused($nameFieldFocused)
                        .onSubmit {
                            appManager.renameFolder(folder, to: draftName)
                        }

                    Spacer()

                    Button {
                        appManager.renameFolder(folder, to: draftName)
                        appManager.closeFolder()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(folder.apps, id: \.bundleIdentifier) { app in
                            FolderAppIcon(app: app)
                                .environmentObject(appManager)
                                .contextMenu {
                                    Button("移出文件夹") {
                                        appManager.removeFromFolder(app, folder: folder)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)

                    FolderAppendDropZone(isTargeted: isAppendDropTarget)
                        .padding(.top, 12)
                        .onDrop(of: [.text], delegate: FolderAppendDropDelegate(
                            appManager: appManager,
                            isTargeted: $isAppendDropTarget
                        ))
                }
            }
            .padding(28)
            .frame(width: 760, height: 520)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(radius: 30)
        }
        .onAppear {
            draftName = folder.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nameFieldFocused = true
            }
        }
        .onDisappear {
            appManager.renameFolder(folder, to: draftName)
        }
    }
}

struct FolderAppIcon: View {
    let app: AppItem
    @EnvironmentObject var appManager: AppManager
    @State private var isDropTarget = false

    var body: some View {
        AppIconView(
            app: app,
            isDragTarget: $isDropTarget
        )
        .opacity(appManager.draggedApp?.bundleIdentifier == app.bundleIdentifier ? 0.55 : 1.0)
        .overlay(alignment: .bottom) {
            if appManager.isFolderDragHoverTarget(app) && appManager.draggedApp?.bundleIdentifier != app.bundleIdentifier {
                Capsule()
                    .fill(Color.blue.opacity(0.9))
                    .frame(width: 84, height: 4)
                    .offset(y: 6)
            }
        }
        .onDrag {
            appManager.startDragging(app)
            return NSItemProvider(object: app.title as NSString)
        }
        .onDrop(of: [.text], delegate: FolderAppDropDelegate(
            app: app,
            appManager: appManager,
            isDropTarget: $isDropTarget
        ))
    }
}

struct FolderAppendDropZone: View {
    let isTargeted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isTargeted ? Color.blue.opacity(0.18) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isTargeted ? Color.blue.opacity(0.95) : Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
            )
            .frame(height: 72)
            .overlay(
                HStack(spacing: 10) {
                    Image(systemName: "text.insert")
                        .font(.system(size: 16, weight: .semibold))
                    Text("拖到这里追加到末尾")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
            )
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}

struct FolderBackgroundDropDelegate: DropDelegate {
    let appManager: AppManager
    @Binding var isTargeted: Bool

    func performDrop(info: DropInfo) -> Bool {
        defer {
            withAnimation(.easeInOut(duration: 0.15)) {
                isTargeted = false
            }
            appManager.moveDraggedAppToRoot()
            appManager.endDragging()
            appManager.closeFolder()
        }

        return appManager.draggedApp?.folderId != nil
    }

    func dropEntered(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = true
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = false
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        appManager.canOrganize && appManager.draggedApp?.folderId != nil
    }
}

struct FolderDropDelegate: DropDelegate {
    let folder: AppFolder
    let pageIndex: Int
    let index: Int
    let appManager: AppManager
    @Binding var isDropTarget: Bool

    func performDrop(info: DropInfo) -> Bool {
        defer {
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTarget = false
            }
            appManager.endDragging()
        }

        guard appManager.draggedApp != nil || appManager.draggedFolder != nil else {
            return false
        }

        if appManager.draggedFolder != nil {
            appManager.moveDraggedFolder(to: pageIndex, index: index)
        } else {
            appManager.addDraggedApp(to: folder)
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isDropTarget = true
        }
        appManager.setDragHover(page: pageIndex, at: index)
        appManager.setDragHoverApp(nil)
        appManager.setDragHoverFolder(folder)
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isDropTarget = false
        }
        appManager.setDragHoverFolder(nil)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard appManager.canOrganize else { return false }

        if let draggedFolder = appManager.draggedFolder {
            return draggedFolder.id != folder.id
        }

        return appManager.draggedApp != nil &&
        !folder.apps.contains(where: { $0.bundleIdentifier == appManager.draggedApp?.bundleIdentifier })
    }
}

struct FolderAppDropDelegate: DropDelegate {
    let app: AppItem
    let appManager: AppManager
    @Binding var isDropTarget: Bool

    func performDrop(info: DropInfo) -> Bool {
        defer {
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTarget = false
            }
            appManager.setFolderDragHover(app: nil)
            appManager.endDragging()
        }

        guard let draggedApp = appManager.draggedApp else {
            return false
        }

        if draggedApp.folderId == app.folderId {
            appManager.moveAppWithinExpandedFolder(to: app)
        } else if let folder = appManager.expandedFolder {
            appManager.addDraggedApp(to: folder)
        }

        return true
    }

    func dropEntered(info: DropInfo) {
        guard appManager.draggedApp?.bundleIdentifier != app.bundleIdentifier else {
            return
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            isDropTarget = true
        }
        appManager.setFolderDragHover(app: app)
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isDropTarget = false
        }
        appManager.setFolderDragHover(app: nil)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard appManager.canOrganize,
              let draggedApp = appManager.draggedApp,
              draggedApp.bundleIdentifier != app.bundleIdentifier else {
            return false
        }

        if draggedApp.folderId == app.folderId {
            return true
        }

        return appManager.expandedFolder != nil
    }
}

struct FolderAppendDropDelegate: DropDelegate {
    let appManager: AppManager
    @Binding var isTargeted: Bool

    func performDrop(info: DropInfo) -> Bool {
        defer {
            withAnimation(.easeInOut(duration: 0.15)) {
                isTargeted = false
            }
            appManager.setFolderDragHover(app: nil)
            appManager.endDragging()
        }

        guard appManager.draggedApp != nil else {
            return false
        }

        appManager.appendDraggedAppToExpandedFolder()
        return true
    }

    func dropEntered(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = true
        }
        appManager.setFolderDragHover(app: nil)
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = false
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard appManager.canOrganize,
              let draggedApp = appManager.draggedApp,
              let expandedFolder = appManager.expandedFolder else {
            return false
        }

        if draggedApp.folderId == expandedFolder.id {
            return true
        }

        return !expandedFolder.apps.contains(where: { $0.bundleIdentifier == draggedApp.bundleIdentifier })
    }
}

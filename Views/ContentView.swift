import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var showingSearch = false
    @State private var wallpaperImage: NSImage?
    @State private var wallpaperURL: URL?
    @FocusState private var searchFocused: Bool
    private let wallpaperRefreshTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DesktopWallpaperBackground(image: wallpaperImage)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if appManager.expandedFolder != nil {
                            appManager.closeFolder()
                        } else {
                            minimizeWindow()
                        }
                    }

                GeometryReader { geometry in
                    let screenHeight = geometry.size.height
                    let bottomSpacing: CGFloat = screenHeight > 982 ? 90 : 30

                    VStack(spacing: 0) {
                    Spacer(minLength: 10)
                        .frame(maxHeight: 50)

                    HStack(spacing: 15) {
                        SearchBar(searchText: $appManager.searchText, isSearching: $showingSearch)
                            .frame(width: 300)
                            .focused($searchFocused)

                        Button(action: {
                            appManager.resetToDefaultFirstPageSorting()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("重置应用排序")
                    }
                    .frame(height: 40)

                    Spacer(minLength: 15)
                        .frame(maxHeight: 60)

                    HorizontalPageView(
                        currentPage: $appManager.currentPage,
                        pageCount: appManager.numberOfPages(),
                        content: (0..<appManager.numberOfPages()).map { page in
                            AnyView(AppGridView(pageIndex: page)
                                .environmentObject(appManager))
                        }
                    )
                    .layoutPriority(1) // 最高优先级，保证应用网格完整显示

                    Spacer(minLength: 20)
                        .frame(maxHeight: 80) // 网格到指示器的间距，最大80px

                    PageIndicator(currentPage: $appManager.currentPage, pageCount: appManager.numberOfPages())
                        .frame(height: 30)

                    Spacer(minLength: bottomSpacing) // 根据屏幕高度动态设置指示器下方空间
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Consume taps inside the main content area so controls like
                        // the page indicator do not bubble up to the background exit action.
                    }
                    .onAppear {
                        appManager.updateLayoutForScreenHeight(screenHeight)
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        appManager.updateLayoutForScreenHeight(newHeight)
                    }
                }

                if let folder = appManager.expandedFolder {
                    FolderExpandedView(folder: folder)
                        .environmentObject(appManager)
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(2)
                }
            }
        }
        .onAppear {
            appManager.loadApps()
            refreshWallpaper()
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshWallpaper()
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            refreshWallpaper(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshWallpaper(force: true)
        }
        .onReceive(wallpaperRefreshTimer) { _ in
            guard NSApplication.shared.isActive else { return }
            refreshWallpaper()
        }
    }

    private func minimizeWindow() {
        hideQuickLaunchApp()
    }

    private func refreshWallpaper(force: Bool = false) {
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSApplication.shared.windows.first?.screen ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = currentScreen,
              let newWallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen) else {
            wallpaperImage = nil
            wallpaperURL = nil
            return
        }

        guard force || newWallpaperURL != wallpaperURL || wallpaperImage == nil else {
            return
        }

        wallpaperURL = newWallpaperURL
        wallpaperImage = NSImage(contentsOf: newWallpaperURL)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct DesktopWallpaperBackground: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Color(red: 0x7c / 255.0, green: 0x7c / 255.0, blue: 0x7c / 255.0)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 40,
                        endRadius: 820
                    )
                )
        }
    }
}

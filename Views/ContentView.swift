import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景层，可以点击最小化
                Color(red: 0x7c/255.0, green: 0x7c/255.0, blue: 0x7c/255.0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        minimizeWindow()
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
                            AnyView(AppGridView(apps: [], pageIndex: page)
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
                    .onAppear {
                        appManager.updateLayoutForScreenHeight(screenHeight)
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        appManager.updateLayoutForScreenHeight(newHeight)
                    }
                }
                .onTapGesture {
                    minimizeWindow()
                }
            }
        }
        .onAppear {
            appManager.loadApps()
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            searchFocused = true
        }
    }

    private func minimizeWindow() {
        NSApplication.shared.terminate(nil)
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
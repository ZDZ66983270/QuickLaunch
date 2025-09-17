import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                SearchBar(searchText: $appManager.searchText, isSearching: $showingSearch)
                    .padding(.horizontal, 200)
                    .padding(.top, 40)
                    .focused($searchFocused)
                
                HorizontalPageView(
                    currentPage: $appManager.currentPage,
                    pageCount: appManager.numberOfPages(),
                    content: (0..<appManager.numberOfPages()).map { page in
                        AnyView(AppGridView(apps: [], pageIndex: page)
                            .environmentObject(appManager))
                    }
                )
                .padding(.top, 20)
                
                PageIndicator(currentPage: $appManager.currentPage, pageCount: appManager.numberOfPages())
                    .padding(.bottom, 30)
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
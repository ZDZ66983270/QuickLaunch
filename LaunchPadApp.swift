import SwiftUI
import AppKit
import os.log

@main
struct LaunchPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appManager = AppManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appManager)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About LaunchPad") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable verbose system logging
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        setenv("OS_ACTIVITY_STREAM", "disable", 1)
        setenv("CFLOG_FORCE_STDERR", "0", 1)

        // Additional log suppression for clean console output

        // 延迟设置窗口，确保窗口完全准备好
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = false  // 禁用窗口拖拽，避免与图标拖拽冲突
                window.backgroundColor = NSColor.clear

                // 全屏显示
                window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
                window.toggleFullScreen(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
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
                // 先设置基本窗口属性
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = false
                window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]

                // 获取目标屏幕
                let mouseLocation = NSEvent.mouseLocation
                let currentScreen = NSScreen.screens.first { screen in
                    NSMouseInRect(mouseLocation, screen.frame, false)
                } ?? NSScreen.main ?? NSScreen.screens.first!

                // 设置小窗口位置并立即显示
                let screenFrame = currentScreen.frame
                let initialSize = NSSize(width: 800, height: 600)
                let initialFrame = NSRect(
                    x: screenFrame.origin.x + (screenFrame.width - initialSize.width) / 2,
                    y: screenFrame.origin.y + (screenFrame.height - initialSize.height) / 2,
                    width: initialSize.width,
                    height: initialSize.height
                )
                window.setFrame(initialFrame, display: false) // 不立即刷新显示
                window.makeKeyAndOrderFront(nil) // 显示窗口

                // 使用更短的延迟立即全屏
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    window.toggleFullScreen(nil)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
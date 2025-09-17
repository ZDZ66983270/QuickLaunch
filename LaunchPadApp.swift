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
            CommandGroup(replacing: .windowArrangement) {
                Button("Exit LaunchPad") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var escapeKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable verbose system logging
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        setenv("OS_ACTIVITY_STREAM", "disable", 1)
        setenv("CFLOG_FORCE_STDERR", "0", 1)

        // Additional log suppression for clean console output

        // 设置本地ESC键监听（可以阻止默认行为）
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC键的keyCode是53
                self.minimizeWindow()
                return nil // 阻止事件继续传播
            }
            return event
        }

        // 立即设置窗口为全屏，无任何延迟
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // 设置窗口属性
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = false
                window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]

                // 获取目标屏幕
                let mouseLocation = NSEvent.mouseLocation
                let currentScreen = NSScreen.screens.first { screen in
                    NSMouseInRect(mouseLocation, screen.frame, false)
                } ?? NSScreen.main ?? NSScreen.screens.first!

                // 立即设置为全屏，无延迟
                let screenFrame = currentScreen.frame
                window.setFrame(screenFrame, display: true)
                window.makeKeyAndOrderFront(nil)
                window.toggleFullScreen(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }


    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func minimizeWindow() {
        NSApplication.shared.terminate(nil)
    }
}
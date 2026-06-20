import SwiftUI
import AppKit
import os.log

@main
struct QuickLaunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appManager = AppManager()

    init() {
        // Setup crash reporting
        setupCrashReporting()

        // Setup global error handling
        setupGlobalErrorHandling()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appManager)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 QuickLaunch") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .windowArrangement) {
                Button("退出 QuickLaunch") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var escapeKeyMonitor: Any?
    private let logger = Logger(subsystem: "com.quicklaunch.macos", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application launching...")

        do {
            NSApp.setActivationPolicy(.regular)

            // Disable verbose system logging
            setenv("OS_ACTIVITY_MODE", "disable", 1)
            setenv("OS_ACTIVITY_STREAM", "disable", 1)
            setenv("CFLOG_FORCE_STDERR", "0", 1)

            // Setup ESC key monitoring with error handling
            try setupKeyMonitoring()

            // Setup fullscreen window with error handling
            try setupFullscreenWindow()

            logger.info("Application launched successfully")
        } catch {
            logger.error("Failed to launch application: \(error.localizedDescription)")
            handleApplicationLaunchError(error)
        }
    }

    private func setupKeyMonitoring() throws {
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if event.keyCode == 53 { // ESC键的keyCode是53
                self.logger.info("ESC key pressed, hiding application")
                self.minimizeWindow()
                return nil // 阻止事件继续传播
            }
            return event
        }

        if escapeKeyMonitor == nil {
            throw AppError.keyMonitoringSetupFailed
        }
    }

    private func setupFullscreenWindow() throws {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first else {
                self.logger.error("No window available for fullscreen setup")
                return
            }

            // 设置窗口属性
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.fullScreenAllowsTiling]
            window.titlebarAppearsTransparent = true
            window.hasShadow = false
            window.backgroundColor = .clear
            window.isOpaque = false
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true

            // 获取目标屏幕
            let mouseLocation = NSEvent.mouseLocation
            let currentScreen = NSScreen.screens.first { screen in
                NSMouseInRect(mouseLocation, screen.frame, false)
            } ?? NSScreen.main ?? NSScreen.screens.first

            guard let screen = currentScreen else {
                self.logger.error("No screen available for fullscreen setup")
                return
            }

            // Use the visible frame so the app opens maximized without
            // entering a separate fullscreen space or covering the menu bar/dock.
            let targetFrame = screen.visibleFrame
            window.setFrame(targetFrame, display: true)
            window.makeKeyAndOrderFront(nil)

            self.logger.info("Launch window setup completed using visible screen frame")
        }
    }

    private func handleApplicationLaunchError(_ error: Error) {
        // Show a user-friendly error dialog
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "启动失败"
            alert.informativeText = "QuickLaunch 在启动时遇到了问题。请重试，或联系支持人员。"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "退出")
            alert.addButton(withTitle: "重试")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSApplication.shared.terminate(nil)
            } else {
                // Attempt to restart key components
                self.attemptRecovery()
            }
        }
    }

    private func attemptRecovery() {
        logger.info("Attempting application recovery...")
        // Basic recovery: try to setup key monitoring again
        do {
            try setupKeyMonitoring()
            logger.info("Recovery successful")
        } catch {
            logger.error("Recovery failed: \(error.localizedDescription)")
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag, sender.isActive {
            logger.info("Dock icon clicked while QuickLaunch is frontmost; hiding window")
            hideQuickLaunchApp()
            return false
        }

        guard let window = sender.windows.first else {
            sender.activate(ignoringOtherApps: true)
            return false
        }

        if sender.isHidden {
            sender.unhide(nil)
        }

        logger.info("Dock icon clicked while QuickLaunch is inactive, bringing window to front")
        window.makeKeyAndOrderFront(nil)
        sender.activate(ignoringOtherApps: true)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func minimizeWindow() {
        hideQuickLaunchApp()
    }
}

func hideQuickLaunchApp() {
    let app = NSApplication.shared
    app.windows.forEach { $0.orderOut(nil) }
    app.hide(nil)
}

// MARK: - Error Types and Crash Reporting

enum AppError: Error {
    case keyMonitoringSetupFailed
    case windowSetupFailed
    case applicationStateCorrupted

    var localizedDescription: String {
        switch self {
        case .keyMonitoringSetupFailed:
            return "键盘监听设置失败"
        case .windowSetupFailed:
            return "应用窗口设置失败"
        case .applicationStateCorrupted:
            return "应用状态已损坏"
        }
    }
}

// MARK: - Global Error Handling Functions

func setupCrashReporting() {
    // For now, we'll use a simple logging-based approach
    // In a production app, you would integrate with a service like Crashlytics

    NSSetUncaughtExceptionHandler { exception in
        let logger = Logger(subsystem: "com.quicklaunch.macos", category: "CrashReporter")
        logger.fault("Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "Unknown reason")")
        logger.fault("Call stack: \(exception.callStackSymbols.joined(separator: "\n"))")

        // Save crash log to file
        saveCrashLog(exception: exception)
    }
}

func setupGlobalErrorHandling() {
    // Setup signal handlers for crash detection
    signal(SIGABRT) { signal in
        let logger = Logger(subsystem: "com.quicklaunch.macos", category: "CrashReporter")
        logger.fault("Application received SIGABRT signal")
        saveCrashLog(signal: signal)
    }

    signal(SIGSEGV) { signal in
        let logger = Logger(subsystem: "com.quicklaunch.macos", category: "CrashReporter")
        logger.fault("Application received SIGSEGV signal")
        saveCrashLog(signal: signal)
    }
}

private func saveCrashLog(exception: NSException? = nil, signal: Int32? = nil) {
    let crashReport = createCrashReport(exception: exception, signal: signal)

    // Save to application support directory
    if let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        let quickLaunchDir = appSupportDir.appendingPathComponent("QuickLaunch")

        do {
            try FileManager.default.createDirectory(at: quickLaunchDir, withIntermediateDirectories: true)

            let crashLogURL = quickLaunchDir.appendingPathComponent("crash_\(Date().timeIntervalSince1970).log")
            try crashReport.write(to: crashLogURL, atomically: true, encoding: .utf8)
        } catch {
            // If we can't save the crash log, at least log it
            let logger = Logger(subsystem: "com.quicklaunch.macos", category: "CrashReporter")
            logger.fault("Failed to save crash log: \(error.localizedDescription)")
        }
    }
}

private func createCrashReport(exception: NSException? = nil, signal: Int32? = nil) -> String {
    var report = "QuickLaunch Crash Report\n"
    report += "========================\n"
    report += "Date: \(Date())\n"
    report += "Version: 1.3.0\n"
    report += "System: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"

    if let exception = exception {
        report += "\nException: \(exception.name.rawValue)\n"
        report += "Reason: \(exception.reason ?? "Unknown")\n"
        report += "Stack Trace:\n\(exception.callStackSymbols.joined(separator: "\n"))\n"
    }

    if let signal = signal {
        report += "\nSignal: \(signal)\n"
    }

    report += "\nMemory Usage:\n"
    var memoryInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    let result = withUnsafeMutablePointer(to: &memoryInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if result == KERN_SUCCESS {
        report += "Resident Memory: \(memoryInfo.resident_size / 1024 / 1024) MB\n"
        report += "Virtual Memory: \(memoryInfo.virtual_size / 1024 / 1024) MB\n"
    }

    return report
}

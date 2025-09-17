import Foundation
import AppKit

class AppScanner {
    static let shared = AppScanner()
    
    private init() {}
    
    func scanApplications() -> [AppItem] {
        var apps: [AppItem] = []
        var seenBundleIds = Set<String>()  // 用于去重
        var position = 0

        let applicationPaths = [
            "/Applications",
            "~/Applications",
            "/System/Applications",
            "/System/Applications/Utilities"
        ]

        for path in applicationPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)

            if let enumerator = FileManager.default.enumerator(at: url,
                                                               includingPropertiesForKeys: [.isApplicationKey, .localizedNameKey],
                                                               options: [.skipsHiddenFiles, .skipsPackageDescendants]) {

                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "app" {
                        // 更robust的bundle加载
                        guard let bundle = Bundle(url: fileURL) else { continue }
                        guard let bundleIdentifier = bundle.bundleIdentifier else { continue }

                        // 获取应用名称，有多种fallback
                        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                                     bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                                     fileURL.deletingPathExtension().lastPathComponent

                        // 去重：只添加之前没见过的bundleIdentifier
                        if !seenBundleIds.contains(bundleIdentifier) {
                            seenBundleIds.insert(bundleIdentifier)

                            let app = AppItem(name: appName,
                                            bundleIdentifier: bundleIdentifier,
                                            url: fileURL,
                                            position: position)
                            apps.append(app)
                            position += 1
                        }
                    }
                }
            }
        }

        // 不强制排序，保持扫描顺序或让用户控制顺序
        return apps
    }
    
    func getRecentApps() -> [AppItem] {
        var recentApps: [AppItem] = []

        // Note: LSSharedFileList API is deprecated in newer macOS versions
        // For now, we'll return an empty array
        // Alternative: Could use NSWorkspace's recently used applications

        return recentApps
    }
}
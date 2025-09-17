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

                        // 获取应用名称，优先使用本地化名称
                        let appName = getLocalizedAppName(for: fileURL, bundle: bundle)

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

    private func getLocalizedAppName(for appURL: URL, bundle: Bundle) -> String {
        // 1. 尝试使用系统metadata获取本地化名称（用于系统应用）
        if let metadataName = getSystemMetadataDisplayName(for: appURL) {
            return cleanAppName(metadataName)
        }

        // 2. 手动读取本地化的 InfoPlist.strings 文件（用于第三方应用）
        if let localizedName = getNameFromLocalizedStrings(bundle: bundle, appURL: appURL),
           !localizedName.isEmpty {
            return cleanAppName(localizedName)
        }

        // 3. 尝试获取本地化的 CFBundleDisplayName
        if let displayName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
           !displayName.isEmpty {
            return cleanAppName(displayName)
        }

        // 4. 尝试获取本地化的 CFBundleName
        if let bundleName = bundle.localizedInfoDictionary?["CFBundleName"] as? String,
           !bundleName.isEmpty {
            return cleanAppName(bundleName)
        }

        // 5. 尝试使用 FileManager 获取本地化显示名称（Finder 使用的方法）
        do {
            let resourceValues = try appURL.resourceValues(forKeys: [.localizedNameKey])
            if let localizedName = resourceValues.localizedName, !localizedName.isEmpty {
                return cleanAppName(localizedName)
            }
        } catch {
            // 忽略错误，继续尝试其他方法
        }

        // 6. 回退到非本地化的 CFBundleDisplayName
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return cleanAppName(displayName)
        }

        // 7. 回退到非本地化的 CFBundleName
        if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return cleanAppName(bundleName)
        }

        // 8. 最后使用文件名（移除.app扩展名）
        return cleanAppName(appURL.lastPathComponent)
    }

    private func cleanAppName(_ name: String) -> String {
        if name.hasSuffix(".app") {
            return String(name.dropLast(4))
        }
        return name
    }

    private func getNameFromLocalizedStrings(bundle: Bundle, appURL: URL) -> String? {
        // 检查可能的语言代码变体
        let languageCodes = ["zh-Hans", "zh-Hans-CN", "zh_CN", "zh"]

        for language in languageCodes {
            // 构建本地化字符串文件路径
            let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
            let lprojURL = resourcesURL.appendingPathComponent("\(language).lproj")
            let infoPlistStringsURL = lprojURL.appendingPathComponent("InfoPlist.strings")

            if FileManager.default.fileExists(atPath: infoPlistStringsURL.path) {
                // Use NSDictionary to read the .strings file properly (handles UTF-16 encoding)
                if let plistDict = NSDictionary(contentsOf: infoPlistStringsURL) as? [String: String] {
                    if let displayName = plistDict["CFBundleDisplayName"], !displayName.isEmpty {
                        return displayName
                    }
                    if let bundleName = plistDict["CFBundleName"], !bundleName.isEmpty {
                        return bundleName
                    }
                }
            }
        }

        return nil
    }

    private func getSystemMetadataDisplayName(for appURL: URL) -> String? {
        // 使用 MDItem 查询系统metadata获取本地化显示名称
        guard let mdItem = MDItemCreate(kCFAllocatorDefault, appURL.path as CFString) else {
            return nil
        }

        guard let displayName = MDItemCopyAttribute(mdItem, kMDItemDisplayName) else {
            return nil
        }

        // 将 CFTypeRef 转换为 String
        if CFGetTypeID(displayName) == CFStringGetTypeID() {
            let name = displayName as! CFString as String
            // 如果名称包含中文字符，则认为是有效的本地化名称
            if containsChineseCharacters(name) {
                return name
            }
        }

        return nil
    }

    private func containsChineseCharacters(_ string: String) -> Bool {
        // 检查字符串是否包含中文字符
        for character in string {
            let scalar = character.unicodeScalars.first!
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }
}
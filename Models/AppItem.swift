import Foundation
import AppKit

class AppItem: Identifiable, Hashable, Codable, ObservableObject {
    let id = UUID()
    let title: String
    let package_name: String
    let bundleIdentifier: String
    let url: URL
    var position: Int
    var folderId: UUID?

    // 预先计算好的图标，创建时就生成正确尺寸
    private var _icon: NSImage?
    private var _iconScaleFactor: CGFloat?

    private enum CodingKeys: String, CodingKey {
        case title, package_name, bundleIdentifier, url, position, folderId
    }

    init(title: String, package_name: String, bundleIdentifier: String, url: URL, position: Int = 0, folderId: UUID? = nil) {
        self.title = title
        self.package_name = package_name
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.position = position
        self.folderId = folderId

        // 立即创建正确尺寸的图标
        let currentScaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        self._iconScaleFactor = currentScaleFactor
        self._icon = Self.createIcon(for: url, scaleFactor: currentScaleFactor)
    }

    var icon: NSImage? {
        let currentScaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0

        // 如果Scale Factor没有变化，直接返回缓存的图标
        if _iconScaleFactor == currentScaleFactor, let cachedIcon = _icon {
            return cachedIcon
        }

        // Scale Factor发生变化，重新创建图标
        _iconScaleFactor = currentScaleFactor
        _icon = Self.createIcon(for: url, scaleFactor: currentScaleFactor)
        return _icon
    }

    // 静态方法：根据Scale Factor获取合适的图标资源
    private static func createIcon(for url: URL, scaleFactor: CGFloat) -> NSImage? {
        // 第1步：根据Scale Factor请求合适的资源
        let targetSize = NSSize(width: 64 * scaleFactor, height: 64 * scaleFactor) // 使用64逻辑点

        // 获取原始图标
        let appIcon = NSWorkspace.shared.icon(forFile: url.path)

        // 第2步：让系统选择最佳表示
        guard let bestRep = appIcon.bestRepresentation(for: NSRect(origin: .zero, size: targetSize),
                                                       context: nil,
                                                       hints: nil) else {
            return appIcon // 如果无法获取bestRepresentation，返回原始图标
        }

        // 第3步：读取系统返回的实际尺寸
        let originalSize = NSSize(width: CGFloat(bestRep.pixelsWide), height: CGFloat(bestRep.pixelsHigh))

        // 创建一个新的NSImage，尺寸为实际获取到的资源尺寸
        let resultIcon = NSImage(size: originalSize)

        // 绘制bestRepresentation到结果图标
        resultIcon.lockFocus()
        bestRep.draw(in: NSRect(origin: .zero, size: originalSize))
        resultIcon.unlockFocus()

        return resultIcon
    }

    // Hashable conformance
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func launch() {
        NSWorkspace.shared.open(url)
    }
}

struct AppFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var apps: [AppItem]
    var position: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, apps, position
    }

    init(id: UUID = UUID(), name: String, apps: [AppItem] = [], position: Int = 0) {
        self.id = id
        self.name = name
        self.apps = apps
        self.position = position
    }
}

enum GridEntry: Identifiable, Hashable {
    case app(AppItem)
    case folder(AppFolder)
    case placeholder(Int)

    var id: String {
        switch self {
        case .app(let app):
            return "app-\(app.bundleIdentifier)"
        case .folder(let folder):
            return "folder-\(folder.id.uuidString)"
        case .placeholder(let index):
            return "placeholder-\(index)"
        }
    }

    var position: Int {
        switch self {
        case .app(let app):
            return app.position
        case .folder(let folder):
            return folder.position
        case .placeholder(let index):
            return index
        }
    }
}

enum DraggedGridItem: Hashable {
    case app(AppItem)
    case folder(AppFolder)

    var id: String {
        switch self {
        case .app(let app):
            return "app-\(app.bundleIdentifier)"
        case .folder(let folder):
            return "folder-\(folder.id.uuidString)"
        }
    }
}

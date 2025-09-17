import Foundation
import AppKit

struct AppItem: Identifiable, Hashable, Codable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let url: URL
    var position: Int
    var folderId: UUID?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, bundleIdentifier, url, position, folderId
    }
    
    init(name: String, bundleIdentifier: String, url: URL, position: Int = 0, folderId: UUID? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.position = position
        self.folderId = folderId
    }
    
    var icon: NSImage? {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func launch() {
        NSWorkspace.shared.open(url)
    }
}

struct AppFolder: Identifiable, Hashable, Codable {
    let id = UUID()
    var name: String
    var apps: [AppItem]
    var position: Int
    
    init(name: String, apps: [AppItem] = [], position: Int = 0) {
        self.name = name
        self.apps = apps
        self.position = position
    }
}
import SwiftUI
import AppKit

struct IconSizeCalculator {
    // 显示尺寸系数 - 图标资源的实际显示大小 = 图标资源尺寸 × 0.8125
    static let displayScaleFactor: CGFloat = 0.8125

    // 计算图标的最终显示尺寸
    static func calculateDisplaySize(for icon: NSImage?) -> CGSize {
        guard let icon = icon else {
            return calculateFallbackSize()
        }

        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let iconSize = icon.size
        let maxDimension = max(iconSize.width, iconSize.height)

        // 关键修正：物理像素 × 0.8125 ÷ screenScale = 逻辑像素
        let displaySize = maxDimension * displayScaleFactor / screenScale

        return CGSize(width: displaySize, height: displaySize)
    }

    // 回退尺寸计算（当没有图标时使用）
    private static func calculateFallbackSize() -> CGSize {
        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        // 使用128逻辑点作为基础，转换为物理像素
        let baseLogicalSize: CGFloat = 128
        let basePhysicalSize = baseLogicalSize * screenScale
        // 应用显示系数并转换回逻辑像素
        let displaySize = basePhysicalSize * displayScaleFactor / screenScale
        return CGSize(width: displaySize, height: displaySize)
    }
}


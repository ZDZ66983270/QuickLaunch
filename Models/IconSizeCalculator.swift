import SwiftUI
import AppKit

struct IconSizeCalculator {
    static let displayScaleFactor: CGFloat = 0.8125

    static func calculateDisplaySize(for icon: NSImage?) -> CGSize {
        guard let icon = icon else {
            return calculateFallbackSize()
        }

        let iconSize = icon.size
        let maxDimension = max(iconSize.width, iconSize.height)
        let displaySize = maxDimension * displayScaleFactor

        return CGSize(width: displaySize, height: displaySize)
    }

    static func calculateDisplaySize(for icon: NSImage?, preferredBaseSize: CGFloat) -> CGSize {
        guard let icon = icon else {
            return calculateFallbackSize(baseSize: preferredBaseSize)
        }

        let iconSize = icon.size
        let maxDimension = max(iconSize.width, iconSize.height)

        let actualBaseSize = getClosestStandardSize(to: maxDimension, preferred: preferredBaseSize)
        let displaySize = actualBaseSize * displayScaleFactor

        return CGSize(width: displaySize, height: displaySize)
    }

    static func getPreferredBaseSize(for scaleFactor: CGFloat) -> CGFloat {
        switch scaleFactor {
        case 1.0:
            return 128
        case 2.0:
            return 256
        case 3.0:
            return 384
        case 4.0...:
            return 512
        default:
            return 256
        }
    }

    private static func getClosestStandardSize(to actualSize: CGFloat, preferred: CGFloat) -> CGFloat {
        let standardSizes: [CGFloat] = [128, 256, 384, 512]

        if actualSize <= 0 {
            return preferred
        }

        let closest = standardSizes.min { abs($0 - actualSize) < abs($1 - actualSize) }
        return closest ?? preferred
    }

    private static func calculateFallbackSize(baseSize: CGFloat = 256) -> CGSize {
        let displaySize = baseSize * displayScaleFactor
        return CGSize(width: displaySize, height: displaySize)
    }
}


// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickLaunch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "QuickLaunch",
            targets: ["QuickLaunch"]
        )
    ],
    targets: [
        .executableTarget(
            name: "QuickLaunch",
            path: ".",
            exclude: ["README.md", "Makefile", "Info.plist"],
            sources: [
                "QuickLaunchApp.swift",
                "Models/AppItem.swift",
                "Models/IconSizeCalculator.swift",
                "ViewModels/AppManager.swift",
                "Services/AppScanner.swift",
                "Views/ContentView.swift",
                "Views/AppGridView.swift",
                "Views/AppIconView.swift",
                "Views/DraggableAppIcon.swift",
                "Views/AppDropDelegate.swift",
                "Views/FolderView.swift",
                "Views/DragPlaceholder.swift",
                "Views/SearchBar.swift",
                "Views/PageIndicator.swift",
                "Views/HorizontalPageView.swift"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)

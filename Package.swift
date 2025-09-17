// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LaunchPadClone",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LaunchPadClone",
            targets: ["LaunchPadClone"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LaunchPadClone",
            path: ".",
            exclude: ["Resources", "README.md", "Makefile", "Info.plist"],
            sources: [
                "LaunchPadApp.swift",
                "Models/AppItem.swift",
                "ViewModels/AppManager.swift",
                "Services/AppScanner.swift",
                "Views/ContentView.swift",
                "Views/AppGridView.swift",
                "Views/AppIconView.swift",
                "Views/DraggableAppIcon.swift",
                "Views/AppDropDelegate.swift",
                "Views/DragPlaceholder.swift",
                "Views/SearchBar.swift",
                "Views/PageIndicator.swift",
                "Views/HorizontalPageView.swift"
            ]
        )
    ]
)
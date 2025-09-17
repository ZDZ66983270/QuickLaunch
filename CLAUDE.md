# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LaunchPad Clone is a macOS native application built with SwiftUI that recreates the macOS Launch Pad functionality. It's designed to replace the native Launch Pad that was removed in macOS 26, providing application discovery and launching with modern macOS 14+ APIs.

## Build and Development Commands

### Primary Commands (via Makefile)
```bash
make build          # Build release version
make run            # Run application directly
make app            # Create macOS app bundle at build/LaunchPadClone.app
make install        # Install to /Applications (requires sudo)
make clean          # Clean build artifacts
```

### Swift Package Manager
```bash
swift build -c release    # Release build
swift run                 # Development run
```

### Testing the App
```bash
make app && open build/LaunchPadClone.app
```

## Architecture Overview

### Core Architecture Pattern
The app follows MVVM architecture with reactive state management:

- **Models**: `AppItem` (app metadata) and `AppFolder` (folder grouping)
- **ViewModels**: `AppManager` (central state management via `@ObservableObject`)
- **Views**: SwiftUI views with environment object injection
- **Services**: `AppScanner` for system app discovery

### Key State Management (AppManager)
The `AppManager` class is the central coordinator managing:
- `allApps`: Master list of discovered applications
- `displayedApps`: Current filtered/sorted view
- `dragPreviewApps`: Dynamic preview during drag operations
- `currentPage`: Pagination state
- Drag state: `isDragging`, `draggedApp`, `dragHoverIndex`

### Page Navigation System
The app uses a hybrid scrolling approach in `HorizontalPageView`:
- **Primary**: Native `ScrollView` with `.scrollTargetBehavior(.paging)` for trackpad gestures
- **Secondary**: Simultaneous `DragGesture` for mouse drag support
- Both methods sync through `scrollPosition` and `currentPage` bindings

### Drag and Drop Architecture
Implements native-style drag reordering:
1. **Start**: `startDragging()` removes item from list, creates `dragPreviewApps`
2. **Hover**: `setDragHover()` dynamically inserts placeholder at hover position
3. **End**: `endDragging()` commits final position and saves preferences

The dragged item is replaced by `DragPlaceholder` during drag operations, while other items dynamically reposition with animations.

### Application Discovery
`AppScanner` searches multiple system paths:
- `/Applications`
- `~/Applications`
- `/System/Applications`
- `/System/Applications/Utilities`

Uses `Bundle` inspection for metadata and `NSWorkspace` for icons.

## Key Technical Requirements

### Platform Requirements
- **Minimum**: macOS 14.0 (uses modern ScrollView APIs)
- **Swift**: 5.9+
- **Frameworks**: SwiftUI, AppKit, Foundation

### Critical Dependencies
- `.scrollTargetBehavior(.paging)` requires macOS 14+
- `.containerRelativeFrame(.horizontal)` for responsive layout
- `NSWorkspace.shared.icon(forFile:)` for app icons

### State Persistence
User preferences saved via `UserDefaults`:
- App positions (`AppPositions` key)
- Folder configurations (`AppFolders` key)

## Component Relationships

### View Hierarchy
```
ContentView
├── SearchBar (search filtering)
├── HorizontalPageView (page navigation)
│   └── AppGridView (per-page grid)
│       └── DraggableAppIcon (individual apps)
│           ├── AppIconView (normal state)
│           └── DragPlaceholder (drag state)
└── PageIndicator (navigation dots)
```

### Data Flow
1. `AppScanner` → `AppManager.allApps`
2. Search/filter → `AppManager.displayedApps`
3. Pagination → `appsForPage()` slicing
4. Drag operations → `dragPreviewApps` for real-time preview

## Common Customizations

### Adjusting Grid Layout
Modify in `AppManager`:
```swift
let appsPerPage = 35  // Total apps per page
let columns = 7       // Grid columns
let rows = 5          // Grid rows
```

### Page Navigation Sensitivity
Adjust in `HorizontalPageView`:
```swift
DragGesture(minimumDistance: 30)  // Mouse drag threshold
let dragThreshold = screenWidth * 0.2  // Page switch threshold
```

### Visual Styling
- App icons: 128x128 pixels (doubled from original 64x64)
- Grid spacing: 50px vertical, 40px horizontal between icons
- Drag animations: 0.2s duration with `.easeInOut`
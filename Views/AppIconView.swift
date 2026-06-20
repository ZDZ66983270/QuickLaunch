import SwiftUI
import AppKit
import os

struct AppIconView: View {
    let app: AppItem
    @Binding var isDragTarget: Bool
    var isGroupingCandidate: Bool = false
    @EnvironmentObject var appManager: AppManager
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var iconDisplaySize: CGSize = CGSize(width: 128, height: 128)
    @State private var hasError = false

    private let logger = Logger(subsystem: "com.quicklaunch.macos", category: "AppIconView")
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconDisplaySize.width, height: iconDisplaySize.height)
                        .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.1 : 1.0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                        .animation(.spring(response: 0.1, dampingFraction: 0.9), value: isPressed)
                        .shadow(color: .black.opacity(0.3), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: iconDisplaySize.width, height: iconDisplaySize.height)
                }
                
                if appManager.isDragging {
                    if appManager.draggedApp?.id == app.id {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: iconDisplaySize.width + 8, height: iconDisplaySize.height + 8)
                    } else if isGroupingCandidate {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.blue.opacity(0.95), lineWidth: 4)
                            .frame(width: iconDisplaySize.width + 12, height: iconDisplaySize.height + 12)
                            .shadow(color: .blue.opacity(0.35), radius: 12)
                    } else if isDragTarget {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .frame(width: iconDisplaySize.width + 8, height: iconDisplaySize.height + 8)
                    }
                }
            }
            
            Text(app.title)
                .font(.system(size: 14))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, y: 1)

            if isGroupingCandidate {
                Text("创建文件夹")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            calculateIconSize()
        }
        .onChange(of: app.icon) {
            calculateIconSize()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            // 只有在没有拖拽时才响应点击
            if !appManager.isDragging {
                isPressed = true
                launchAppSafely()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
        }
        .contextMenu {
            Button("打开") {
                launchAppSafely()
            }
            
            Divider()
            
            Button("在访达中显示") {
                NSWorkspace.shared.selectFile(app.url.path, inFileViewerRootedAtPath: "")
            }
            
            Button("显示简介") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
        }
    }

    private func calculateIconSize() {
        // app.icon已经是根据Scale Factor选择的正确尺寸，直接计算显示大小
        iconDisplaySize = IconSizeCalculator.calculateDisplaySize(for: app.icon)
    }

    private func launchAppSafely() {
        do {
            logger.info("Attempting to launch app: \(app.title)")

            // Validate app before launch
            guard FileManager.default.fileExists(atPath: app.url.path) else {
                throw AppLaunchError.appNotFound
            }

            // Check if app is valid
            guard app.url.pathExtension == "app" else {
                throw AppLaunchError.invalidApp
            }

            // Launch the app through AppManager
            appManager.launchApp(app)

            logger.info("Successfully launched app: \(app.title)")
        } catch {
            logger.error("Failed to launch app \(app.title): \(error.localizedDescription)")
            handleLaunchError(error)
        }
    }

    private func handleLaunchError(_ error: Error) {
        hasError = true

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "无法启动应用"

            if let launchError = error as? AppLaunchError {
                switch launchError {
                case .appNotFound:
                    alert.informativeText = "找不到“\(app.title)”应用，它可能已被移动或删除。"
                case .invalidApp:
                    alert.informativeText = "所选项目不是有效的应用程序。"
                case .permissionDenied:
                    alert.informativeText = "启动“\(app.title)”时权限不足。"
                case .unknown(let message):
                    alert.informativeText = "发生错误：\(message)"
                }
            } else {
                alert.informativeText = error.localizedDescription
            }

            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.addButton(withTitle: "在访达中显示")

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                NSWorkspace.shared.selectFile(app.url.path, inFileViewerRootedAtPath: "")
            }
        }
    }
}

enum AppLaunchError: Error {
    case appNotFound
    case invalidApp
    case permissionDenied
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .appNotFound:
            return "Application not found"
        case .invalidApp:
            return "Invalid application"
        case .permissionDenied:
            return "Permission denied"
        case .unknown(let message):
            return message
        }
    }
}

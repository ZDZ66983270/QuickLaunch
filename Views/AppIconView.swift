import SwiftUI
import AppKit

struct AppIconView: View {
    let app: AppItem
    @Binding var isDragTarget: Bool
    @EnvironmentObject var appManager: AppManager
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var iconDisplaySize: CGSize = CGSize(width: 128, height: 128)
    
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
                        // 被拖拽的应用 - 半透明效果
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: iconDisplaySize.width + 8, height: iconDisplaySize.height + 8)
                    } else if isDragTarget {
                        // 拖放目标 - 高亮边框
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
                appManager.launchApp(app)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
        }
        .contextMenu {
            Button("Open") {
                appManager.launchApp(app)
            }
            
            Divider()
            
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(app.url.path, inFileViewerRootedAtPath: "")
            }
            
            Button("Get Info") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
        }
    }

    private func calculateIconSize() {
        // app.icon已经是根据Scale Factor选择的正确尺寸，直接计算显示大小
        iconDisplaySize = IconSizeCalculator.calculateDisplaySize(for: app.icon)
    }
}
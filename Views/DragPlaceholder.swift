import SwiftUI

struct DragPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 128, height: 128)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        .scaleEffect(0.9)
                )

            Text("")
                .font(.system(size: 14))
                .frame(width: 140, height: 32)  // 保持相同的文本区域大小
        }
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}
import SwiftUI

struct HorizontalPageView: View {
    @Binding var currentPage: Int
    let pageCount: Int
    let content: [AnyView]
    @State private var scrollPosition: Int? = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(0..<content.count, id: \.self) { index in
                    content[index]
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
            // 添加鼠标拖拽的视觉偏移
            .offset(x: dragOffset)
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition)
        .simultaneousGesture(
            // 鼠标拖拽手势 - 使用较高的最小距离来避免与触控板冲突
            DragGesture(minimumDistance: 30)
                .updating($dragOffset) { value, state, _ in
                    // 只在大幅度拖动时提供视觉反馈
                    if abs(value.translation.width) > 30 {
                        state = value.translation.width * 0.3  // 减少拖动的视觉移动量
                        if !isDragging {
                            isDragging = true
                        }
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let dragThreshold: CGFloat = 100
                    let velocity = value.predictedEndLocation.x - value.location.x

                    // 只有在大幅度拖动时才切换页面
                    if abs(value.translation.width) > dragThreshold || abs(velocity) > 500 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if value.translation.width > 0 && currentPage > 0 {
                                currentPage -= 1
                                scrollPosition = currentPage
                            } else if value.translation.width < 0 && currentPage < pageCount - 1 {
                                currentPage += 1
                                scrollPosition = currentPage
                            }
                        }
                    }
                }
        )
        .onChange(of: scrollPosition) { _, newPosition in
            if let newPosition = newPosition, newPosition != currentPage {
                currentPage = newPosition
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage != scrollPosition {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollPosition = newPage
                }
            }
        }
        .onAppear {
            scrollPosition = currentPage
        }
    }
}
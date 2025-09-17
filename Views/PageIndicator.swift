import SwiftUI

struct PageIndicator: View {
    @Binding var currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(page == currentPage ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentPage)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            currentPage = page
                        }
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    
                    if value.translation.width > threshold && currentPage > 0 {
                        withAnimation(.spring()) {
                            currentPage -= 1
                        }
                    } else if value.translation.width < -threshold && currentPage < pageCount - 1 {
                        withAnimation(.spring()) {
                            currentPage += 1
                        }
                    }
                }
        )
    }
}
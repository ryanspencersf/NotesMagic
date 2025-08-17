import SwiftUI

public struct SidePanel<Content: View>: View {
    @Binding var isOpen: Bool
    var widthRatio: CGFloat = 0.86
    var edge: Edge = .leading
    @ViewBuilder let content: () -> Content
    
    public init(isOpen: Binding<Bool>, widthRatio: CGFloat = 0.86, edge: Edge = .leading, @ViewBuilder content: @escaping () -> Content) {
        _isOpen = isOpen
        self.widthRatio = widthRatio
        self.edge = edge
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            // Scrim with 0.22 opacity
            if isOpen {
                Color.black
                    .opacity(0.22)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.22)) {
                            isOpen = false
                        }
                    }
            }
            
            // Panel content
            HStack(spacing: 0) {
                content()
                    .frame(width: UIScreen.main.bounds.width * widthRatio)
                    .background(Color(.systemBackground))
                    .offset(x: isOpen ? 0 : -UIScreen.main.bounds.width * widthRatio)
                    .animation(.easeOut(duration: 0.22), value: isOpen)
                
                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let dragDistance = value.translation.x
                    let screenWidth = UIScreen.main.bounds.width
                    let threshold = screenWidth * 0.3
                    
                    if dragDistance < -threshold {
                        withAnimation(.easeOut(duration: 0.22)) {
                            isOpen = false
                        }
                    }
                }
        )
    }
    
    private func offset(_ w: CGFloat) -> CGFloat {
        if isOpen { return 0 }
        return edge == .leading ? -w : w
    }
    
    private func drag(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onEnded { v in
                let close = edge == .leading ? v.translation.width < -30 : v.translation.width > 30
                if close { isOpen = false }
            }
    }
}

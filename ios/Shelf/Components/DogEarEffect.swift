import SwiftUI

/// Dog-ear fold animation on "Want to Read" save.
/// Triangular path in top-right corner with 3D rotation animation and haptic feedback.
struct DogEarEffect: ViewModifier {
    @Binding var isActive: Bool
    var color: Color = ShelfColors.amber
    var size: CGFloat = 24

    @State private var animating = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if isActive {
                    DogEarShape()
                        .fill(color)
                        .frame(width: size, height: size)
                        .rotation3DEffect(
                            .degrees(animating ? 0 : 90),
                            axis: (x: 1, y: -1, z: 0),
                            anchor: .topTrailing
                        )
                        .shadow(color: .black.opacity(0.15), radius: 2, x: -1, y: 1)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.4)) {
                                animating = true
                            }
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                        .onDisappear {
                            animating = false
                        }
                }
            }
    }
}

/// Triangular path for the dog-ear fold.
struct DogEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

extension View {
    func dogEarEffect(isActive: Binding<Bool>, color: Color = ShelfColors.amber) -> some View {
        modifier(DogEarEffect(isActive: isActive, color: color))
    }
}

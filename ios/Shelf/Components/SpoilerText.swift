import SwiftUI

struct SpoilerText: View {
    let text: String
    let hasSpoilers: Bool
    @State private var isRevealed = false

    var body: some View {
        if hasSpoilers && !isRevealed {
            VStack(spacing: 8) {
                Label("Contains spoilers", systemImage: "eye.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Tap to reveal") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRevealed = true
                    }
                }
                .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Text(text)
                .font(.body)
        }
    }
}

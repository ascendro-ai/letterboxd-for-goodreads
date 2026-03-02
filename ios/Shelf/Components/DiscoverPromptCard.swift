import SwiftUI

/// Prompt card shown when the feed falls back to popular/mixed content,
/// encouraging new users to follow people they know.
struct DiscoverPromptCard: View {
    var onFindPeople: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)

            Text("Find people you know")
                .font(.headline)

            Text("Follow readers to fill your feed with books they're reading and reviewing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let onFindPeople {
                Button(action: onFindPeople) {
                    Text("Find People")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

struct UserAvatarView: View {
    let url: String?
    var size: CGFloat = 36
    var username: String? = nil

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .accessibilityLabel(username.map { "\($0)'s avatar" } ?? "User avatar")
    }

    private var placeholder: some View {
        Circle()
            .fill(ShelfColors.backgroundTertiary)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(ShelfColors.textTertiary)
                    .font(.system(size: size * 0.4))
            }
    }
}

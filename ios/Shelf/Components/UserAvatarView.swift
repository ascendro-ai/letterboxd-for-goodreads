import SwiftUI

struct UserAvatarView: View {
    let url: String?
    var size: CGFloat = 36

    var body: some View {
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

    private var placeholder: some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: size * 0.4))
            }
            .accessibilityHidden(true)
    }
}

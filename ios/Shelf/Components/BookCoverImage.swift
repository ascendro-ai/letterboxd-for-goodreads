import SwiftUI

struct BookCoverImage: View {
    let url: String?
    var size: CGSize = CGSize(width: 60, height: 90)
    var cornerRadius: CGFloat = 6
    var bookTitle: String? = nil

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                            .overlay {
                                ProgressView()
                                    .tint(.secondary)
                            }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .accessibilityLabel(bookTitle.map { "\($0) cover" } ?? "Book cover")
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: size.width, height: size.height)
            .overlay {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: size.width * 0.3))
            }
    }
}

// MARK: - Hero Cover (for detail view)

struct HeroBookCover: View {
    let url: String?
    var bookTitle: String? = nil

    var body: some View {
        BookCoverImage(
            url: url,
            size: CGSize(width: 180, height: 270),
            cornerRadius: 10,
            bookTitle: bookTitle
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

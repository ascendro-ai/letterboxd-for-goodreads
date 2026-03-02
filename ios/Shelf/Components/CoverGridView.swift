/// UIKit-backed cover grid using UICollectionViewCompositionalLayout.
/// Displays book covers in a Letterboxd-style poster grid with performant scrolling.

import SwiftUI
import UIKit

struct CoverGridView: UIViewRepresentable {
    let books: [Book]
    let columns: Int
    let onBookTapped: (Book) -> Void

    func makeUIView(context: Context) -> UICollectionView {
        let layout = createLayout(columns: columns)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = context.coordinator
        collectionView.register(CoverCell.self, forCellWithReuseIdentifier: CoverCell.reuseID)

        context.coordinator.dataSource = UICollectionViewDiffableDataSource<Int, UUID>(
            collectionView: collectionView
        ) { collectionView, indexPath, bookID in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CoverCell.reuseID,
                for: indexPath
            ) as? CoverCell

            if let book = context.coordinator.parent.books.first(where: { $0.id == bookID }) {
                cell?.configure(with: book)
            }
            return cell
        }

        applySnapshot(context: context)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        applySnapshot(context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func createLayout(columns: Int) -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1.0 / CGFloat(columns) * 1.5)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: columns)

        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func applySnapshot(context: Context) {
        guard let dataSource = context.coordinator.dataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(books.map(\.id))
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICollectionViewDelegate {
        var parent: CoverGridView
        var dataSource: UICollectionViewDiffableDataSource<Int, UUID>?

        init(parent: CoverGridView) {
            self.parent = parent
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard indexPath.item < parent.books.count else { return }
            parent.onBookTapped(parent.books[indexPath.item])
        }
    }
}

// MARK: - Cover Cell

private final class CoverCell: UICollectionViewCell {
    static let reuseID = "CoverCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.backgroundColor = .systemGray5
        return iv
    }()

    private let placeholderImage: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "book.closed.fill")
        iv.tintColor = .quaternaryLabel
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.addSubview(placeholderImage)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        placeholderImage.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            placeholderImage.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            placeholderImage.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            placeholderImage.widthAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.3),
            placeholderImage.heightAnchor.constraint(equalTo: placeholderImage.widthAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with book: Book) {
        loadTask?.cancel()
        imageView.image = nil
        placeholderImage.isHidden = false
        accessibilityLabel = "\(book.title) by \(book.authors.first?.name ?? "Unknown")"

        guard let urlString = book.coverImageURL, let url = URL(string: urlString) else { return }

        loadTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                await MainActor.run {
                    self?.placeholderImage.isHidden = true
                    self?.imageView.image = image
                }
            } catch {
                // Keep placeholder on failure
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        imageView.image = nil
        placeholderImage.isHidden = false
    }
}

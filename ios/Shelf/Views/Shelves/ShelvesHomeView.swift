import SwiftUI

// MARK: - Shelf Category

enum ShelfCategory: String, CaseIterable, Identifiable {
    case reading, wantToRead, finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reading: "Currently Reading"
        case .wantToRead: "Want to Read"
        case .finished: "Favorites"
        }
    }

    var emoji: String {
        switch self {
        case .reading: "📖"
        case .wantToRead: "✨"
        case .finished: "❤️"
        }
    }
}

// MARK: - View Model

@Observable
final class ShelvesHomeViewModel {
    var currentlyReading: [UserBook] = []
    var wantToRead: [UserBook] = []
    var recentlyRead: [UserBook] = []
    var shelves: [Shelf] = []
    var isLoading = false
    var error: String?

    private let userBookService = UserBookService.shared
    private let shelfService = ShelfService.shared

    func load() async {
        isLoading = true
        error = nil

        do {
            async let readingResult = userBookService.getMyBooks(status: .reading)
            async let wantResult = userBookService.getMyBooks(status: .wantToRead)
            async let readResult = userBookService.getMyBooks(status: .read)
            async let shelvesResult = shelfService.getMyShelves()

            let (reading, want, read, fetchedShelves) = try await (
                readingResult, wantResult, readResult, shelvesResult
            )

            currentlyReading = reading.items
            wantToRead = want.items
            recentlyRead = Array(read.items.prefix(10))
            shelves = fetchedShelves
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func books(for category: ShelfCategory) -> [UserBook] {
        switch category {
        case .reading: currentlyReading
        case .wantToRead: wantToRead
        case .finished: recentlyRead
        }
    }

    func count(for category: ShelfCategory) -> Int {
        books(for: category).count
    }
}

// MARK: - Shelves Home View

struct ShelvesHomeView: View {
    @State private var viewModel = ShelvesHomeViewModel()
    @State private var selectedCategory: ShelfCategory = .reading
    @State private var showNotifications = false
    @State private var showProfile = false
    @State private var showScanner = false
    @State private var showLogBook = false
    @State private var scannedBookID: UUID?
    @State private var notificationsVM = NotificationsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: ShelfSpacing.md) {
                // Category tab bar
                categoryTabs

                if viewModel.isLoading && viewModel.currentlyReading.isEmpty {
                    loadingPlaceholder
                } else {
                    // Selected category shelf (no header — tab already labels it)
                    ShelfRowView(
                        title: selectedCategory.title,
                        icon: selectedCategory.emoji,
                        books: viewModel.books(for: selectedCategory),
                        showHeader: false
                    )

                    // Custom shelves
                    ForEach(viewModel.shelves) { shelf in
                        ShelfRowView(
                            title: shelf.name,
                            icon: "📚",
                            books: []
                        )
                    }

                    // Friends Activity link
                    NavigationLink {
                        FeedView()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.2")
                                .font(.system(size: 14))
                                .foregroundStyle(ShelfColors.textTertiary)
                            Text("Friends Activity")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(ShelfColors.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ShelfColors.textTertiary.opacity(0.5))
                        }
                        .padding(.horizontal, ShelfSpacing.page)
                        .padding(.vertical, ShelfSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, ShelfSpacing.sm)
            .padding(.bottom, 100)
        }
        .refreshable {
            await viewModel.load()
        }
        .shelfPageBackground()
        .navigationTitle("Shelf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 18) {
                    Button {
                        showLogBook = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ShelfColors.accent)
                    }
                    .accessibilityLabel("Log a book")

                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 16))
                            .foregroundStyle(ShelfColors.textPrimary)
                    }
                    .accessibilityLabel("Scan barcode")

                    Button {
                        showNotifications = true
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 16))
                            .foregroundStyle(ShelfColors.textPrimary)
                            .overlay(alignment: .topTrailing) {
                                if notificationsVM.unreadCount > 0 {
                                    Circle()
                                        .fill(ShelfColors.error)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 3, y: -2)
                                }
                            }
                    }
                    .accessibilityLabel("Notifications")

                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(ShelfColors.textPrimary)
                    }
                    .accessibilityLabel("Profile")
                }
            }
        }
        .sheet(isPresented: $showLogBook) {
            NavigationStack {
                LogView()
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView { book in
                showScanner = false
                scannedBookID = book.id
            }
        }
        .navigationDestination(item: $scannedBookID) { bookID in
            BookDetailView(bookID: bookID)
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                NotificationsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                showNotifications = false
                            }
                        }
                    }
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            MyProfileView()
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
        .task {
            await viewModel.load()
            await notificationsVM.load()
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShelfCategory.allCases) { category in
                    categoryChip(for: category)
                }
            }
            .padding(.horizontal, ShelfSpacing.page)
        }
    }

    private func categoryChip(for category: ShelfCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
            ShelfHaptics.shared.tabSwitch()
        } label: {
            HStack(spacing: 5) {
                Text(category.emoji)
                    .font(.system(size: 12))

                Text(category.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyShapeStyle(ShelfColors.accent.opacity(0.12))
                    : AnyShapeStyle(ShelfColors.textTertiary.opacity(0.06))
            )
            .foregroundStyle(isSelected ? ShelfColors.accent : ShelfColors.textSecondary)
            .clipShape(Capsule())
        }
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        VStack(spacing: ShelfSpacing.lg) {
            RoundedRectangle(cornerRadius: ShelfRadius.small)
                .fill(ShelfColors.backgroundTertiary)
                .frame(width: 160, height: 22)
                .padding(.horizontal, ShelfSpacing.page)
                .frame(maxWidth: .infinity, alignment: .leading)

            BookshelfContainer {
                WoodenShelf {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ShelfColors.backgroundTertiary)
                            .frame(width: 105, height: 148)
                    }
                }
                WoodenShelf {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ShelfColors.backgroundTertiary.opacity(0.5))
                        .frame(width: 105, height: 148)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

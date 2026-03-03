import SwiftUI

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
}

// MARK: - Shelves Home View

struct ShelvesHomeView: View {
    @State private var viewModel = ShelvesHomeViewModel()
    @State private var showNotifications = false
    @State private var showProfile = false
    @State private var notificationsVM = NotificationsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ShelfSpacing.xxl) {
                if viewModel.isLoading && viewModel.currentlyReading.isEmpty {
                    loadingPlaceholder
                } else {
                    // Currently Reading
                    ShelfRowView(
                        title: "Currently Reading",
                        books: viewModel.currentlyReading,
                        accentColor: ShelfColors.ocean
                    )

                    // Want to Read
                    ShelfRowView(
                        title: "Want to Read",
                        books: viewModel.wantToRead,
                        accentColor: ShelfColors.amber
                    )

                    // Recently Finished
                    ShelfRowView(
                        title: "Recently Finished",
                        books: viewModel.recentlyRead,
                        accentColor: ShelfColors.forest
                    )

                    // Custom shelves
                    ForEach(viewModel.shelves) { shelf in
                        ShelfRowView(
                            title: shelf.name,
                            books: [],
                            accentColor: ShelfColors.plum
                        )
                    }

                    // Friends Activity link
                    NavigationLink {
                        FeedView()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(ShelfColors.accent)
                            Text("Friends Activity")
                                .font(ShelfFonts.headlineSans)
                                .foregroundStyle(ShelfColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(ShelfFonts.caption)
                                .foregroundStyle(ShelfColors.textTertiary)
                        }
                        .padding(.horizontal, ShelfSpacing.page)
                        .padding(.vertical, ShelfSpacing.md)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, ShelfSpacing.lg)
        }
        .refreshable {
            await viewModel.load()
        }
        .shelfPageBackground()
        .navigationTitle("Shelf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: ShelfSpacing.lg) {
                    // Notifications bell
                    Button {
                        showNotifications = true
                    } label: {
                        Image(systemName: "bell")
                            .foregroundStyle(ShelfColors.textPrimary)
                            .overlay(alignment: .topTrailing) {
                                if notificationsVM.unreadCount > 0 {
                                    Circle()
                                        .fill(ShelfColors.error)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                    }
                    .accessibilityLabel("Notifications")

                    // Profile avatar
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(ShelfColors.textPrimary)
                    }
                    .accessibilityLabel("Profile")
                }
            }
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

    private var loadingPlaceholder: some View {
        VStack(spacing: ShelfSpacing.xxl) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: ShelfSpacing.md) {
                    RoundedRectangle(cornerRadius: ShelfRadius.small)
                        .fill(ShelfColors.backgroundTertiary)
                        .frame(width: 140, height: 20)
                        .padding(.horizontal, ShelfSpacing.page)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ShelfSpacing.md) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: ShelfRadius.cover)
                                    .fill(ShelfColors.backgroundTertiary)
                                    .frame(width: 110, height: 165)
                            }
                        }
                        .padding(.horizontal, ShelfSpacing.page)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

import SwiftUI

struct ManualISBNEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isbn = ""
    @State private var isLookingUp = false
    @State private var error: Error?
    let onBookFound: (Book) -> Void

    private let bookService = BookService.shared

    private var isValidISBN: Bool {
        ISBNValidator.isValid(isbn)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ShelfSpacing.xxl) {
                Image(systemName: "number")
                    .font(.system(size: 40))
                    .foregroundStyle(ShelfColors.accent)

                Text("Enter ISBN")
                    .font(ShelfFonts.headlineSans)
                    .foregroundStyle(ShelfColors.textPrimary)

                Text("Type the 10 or 13 digit ISBN found on the back cover of the book.")
                    .font(ShelfFonts.subheadlineSans)
                    .foregroundStyle(ShelfColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ShelfSpacing.xxxl)

                TextField("ISBN", text: $isbn)
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(ShelfColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(ShelfSpacing.lg)
                    .background(ShelfColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
                    .padding(.horizontal, ShelfSpacing.xxxl)

                if !isbn.isEmpty && !isValidISBN {
                    Text("Invalid ISBN format")
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.error)
                }

                Button {
                    lookup()
                } label: {
                    if isLookingUp {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    } else {
                        Text("Look Up")
                            .font(ShelfFonts.bodySansBold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                }
                .background(isValidISBN ? ShelfColors.accent : ShelfColors.backgroundTertiary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
                .disabled(!isValidISBN || isLookingUp)
                .padding(.horizontal, ShelfSpacing.xxxl)

                if let error {
                    Text(error.localizedDescription)
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.error)
                }

                Spacer()
            }
            .padding(.top, ShelfSpacing.xxxl)
            .shelfPageBackground()
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ShelfColors.accent)
                }
            }
        }
    }

    private func lookup() {
        guard isValidISBN else { return }
        isLookingUp = true
        error = nil

        Task {
            do {
                let book = try await bookService.lookupISBN(isbn)
                await MainActor.run {
                    onBookFound(book)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLookingUp = false
                }
            }
        }
    }
}

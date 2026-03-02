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
            VStack(spacing: 24) {
                Image(systemName: "number")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                Text("Enter ISBN")
                    .font(.title3.bold())

                Text("Type the 10 or 13 digit ISBN found on the back cover of the book.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("ISBN", text: $isbn)
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .font(.title3.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)

                if !isbn.isEmpty && !isValidISBN {
                    Text("Invalid ISBN format")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    lookup()
                } label: {
                    if isLookingUp {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    } else {
                        Text("Look Up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                }
                .background(isValidISBN ? Color.accentColor : Color(.systemGray4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!isValidISBN || isLookingUp)
                .padding(.horizontal, 32)

                if let error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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

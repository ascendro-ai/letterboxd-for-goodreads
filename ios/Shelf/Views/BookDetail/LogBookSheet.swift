import SwiftUI

struct LogBookSheet: View {
    @Environment(\.dismiss) private var dismiss

    let book: Book
    let existingUserBook: UserBook?
    let onSave: (LogBookRequest) -> Void

    @State private var status: ReadingStatus = .read
    @State private var rating: Double = 0
    @State private var reviewText = ""
    @State private var hasSpoilers = false
    @State private var startedAt: Date? = nil
    @State private var finishedAt: Date? = nil
    @State private var showStartDate = false
    @State private var showEndDate = false

    init(book: Book, existingUserBook: UserBook?, onSave: @escaping (LogBookRequest) -> Void) {
        self.book = book
        self.existingUserBook = existingUserBook
        self.onSave = onSave

        if let existing = existingUserBook {
            _status = State(initialValue: existing.status)
            _rating = State(initialValue: existing.rating ?? 0)
            _reviewText = State(initialValue: existing.reviewText ?? "")
            _hasSpoilers = State(initialValue: existing.hasSpoilers)
            _startedAt = State(initialValue: existing.startedAt)
            _finishedAt = State(initialValue: existing.finishedAt)
            _showStartDate = State(initialValue: existing.startedAt != nil)
            _showEndDate = State(initialValue: existing.finishedAt != nil)
        }
    }

    private var isValid: Bool {
        // Review required for new ratings (imported books exempt)
        if rating > 0 && existingUserBook == nil && reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Book header
                Section {
                    HStack(spacing: 12) {
                        BookCoverImage(url: book.coverImageURL, size: CGSize(width: 50, height: 75))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                            if let author = book.authors.first?.name {
                                Text(author)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Status
                Section("Status") {
                    Picker("Reading status", selection: $status) {
                        ForEach(ReadingStatus.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.iconName)
                                .tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Rating
                Section("Rating") {
                    VStack(spacing: 8) {
                        StarRatingView(rating: $rating, size: 36)
                        if rating > 0 {
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                // Review
                Section {
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 100)

                    if rating > 0 && existingUserBook == nil && reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("A review is required when rating a book.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !reviewText.isEmpty {
                        Toggle("Contains spoilers", isOn: $hasSpoilers)
                    }
                } header: {
                    Text("Review")
                }

                // Dates
                Section("Dates") {
                    Toggle("Started reading", isOn: $showStartDate)
                    if showStartDate {
                        DatePicker(
                            "Start date",
                            selection: Binding(
                                get: { startedAt ?? Date() },
                                set: { startedAt = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }

                    Toggle("Finished reading", isOn: $showEndDate)
                    if showEndDate {
                        DatePicker(
                            "End date",
                            selection: Binding(
                                get: { finishedAt ?? Date() },
                                set: { finishedAt = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(existingUserBook != nil ? "Edit Log" : "Log Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let request = LogBookRequest(
            workID: book.id,
            status: status,
            rating: rating > 0 ? rating : nil,
            reviewText: reviewText.isEmpty ? nil : reviewText,
            hasSpoilers: hasSpoilers,
            startedAt: showStartDate ? (startedAt ?? Date()) : nil,
            finishedAt: showEndDate ? (finishedAt ?? Date()) : nil
        )
        onSave(request)
        dismiss()
    }
}

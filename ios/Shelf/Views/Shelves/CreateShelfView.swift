import SwiftUI

struct CreateShelfView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onCreated: (Shelf) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Shelf name", text: $name)
                        .font(ShelfFonts.bodySans)
                }

                Section("Description") {
                    TextField("Optional description", text: $description)
                        .font(ShelfFonts.bodySans)
                }

                Section {
                    Toggle("Public", isOn: $isPublic)
                        .font(ShelfFonts.bodySans)
                        .tint(ShelfColors.accent)
                } footer: {
                    Text("Public shelves are visible on your profile.")
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.textSecondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(ShelfColors.error)
                            .font(ShelfFonts.caption)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShelfColors.background)
            .navigationTitle("New Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(ShelfFonts.bodySans)
                        .foregroundStyle(ShelfColors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.isEmpty || isSaving)
                        .font(ShelfFonts.bodySansBold)
                        .foregroundStyle(ShelfColors.accent)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let request = CreateShelfRequest(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    isPublic: isPublic
                )
                let shelf = try await ShelfService.shared.createShelf(request)
                onCreated(shelf)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

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
                }

                Section("Description") {
                    TextField("Optional description", text: $description)
                }

                Section {
                    Toggle("Public", isOn: $isPublic)
                } footer: {
                    Text("Public shelves are visible on your profile.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.isEmpty || isSaving)
                        .fontWeight(.semibold)
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

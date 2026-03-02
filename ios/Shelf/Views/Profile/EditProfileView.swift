import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    @State private var displayName = ""
    @State private var bio = ""
    @State private var favoriteBookIDs: [UUID] = []
    @State private var showFavoritesPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Display Name") {
                TextField("Display name", text: $displayName)
            }

            Section("Bio") {
                TextEditor(text: $bio)
                    .frame(minHeight: 80)
            }

            Section {
                Button {
                    showFavoritesPicker = true
                } label: {
                    HStack {
                        Label("Favorite Books", systemImage: "heart.fill")
                        Spacer()
                        Text("\(favoriteBookIDs.count)/4")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Choose up to 4 books to showcase on your profile.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(isSaving)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if let user = auth.currentUser {
                displayName = user.displayName ?? ""
                bio = user.bio ?? ""
                favoriteBookIDs = user.favoriteBooks ?? []
            }
        }
        .sheet(isPresented: $showFavoritesPicker) {
            FavoriteBooksPickerView { selectedIDs in
                favoriteBookIDs = selectedIDs
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let request = UpdateProfileRequest(
                    displayName: displayName.isEmpty ? nil : displayName,
                    bio: bio.isEmpty ? nil : bio,
                    favoriteBooks: favoriteBookIDs.isEmpty ? nil : favoriteBookIDs
                )
                _ = try await SocialService.shared.updateProfile(request)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

import SwiftUI

enum ReportTarget {
    case book(UUID)
    case review(UUID)
    case user(UUID)
}

enum ReportReason: String, CaseIterable {
    case inaccurateInfo = "Inaccurate information"
    case spam = "Spam"
    case harassment = "Harassment"
    case spoilers = "Unmarked spoilers"
    case inappropriate = "Inappropriate content"
    case other = "Other"
}

struct ReportContentView: View {
    @Environment(\.dismiss) private var dismiss

    let target: ReportTarget
    @State private var selectedReason: ReportReason?
    @State private var additionalInfo = ""
    @State private var isSubmitting = false
    @State private var submitted = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            if submitted {
                submittedView
            } else {
                reportForm
            }
        }
    }

    private var reportForm: some View {
        Form {
            Section("What's the issue?") {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    Button {
                        selectedReason = reason
                    } label: {
                        HStack {
                            Text(reason.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedReason == reason {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            Section("Additional details (optional)") {
                TextEditor(text: $additionalInfo)
                    .frame(minHeight: 80)
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Submit") {
                    submit()
                }
                .disabled(selectedReason == nil || isSubmitting)
                .fontWeight(.semibold)
            }
        }
    }

    private var submittedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Report Submitted")
                .font(.title3.bold())

            Text("Thank you for helping keep Shelf safe. We'll review this report.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .navigationBarBackButtonHidden()
    }

    private func submit() {
        guard let reason = selectedReason else { return }
        isSubmitting = true

        struct ReportRequest: Encodable {
            let targetType: String
            let targetID: UUID
            let reason: String
            let details: String?

            enum CodingKeys: String, CodingKey {
                case reason, details
                case targetType = "target_type"
                case targetID = "target_id"
            }
        }

        let (targetType, targetID) = targetInfo
        let request = ReportRequest(
            targetType: targetType,
            targetID: targetID,
            reason: reason.rawValue,
            details: additionalInfo.isEmpty ? nil : additionalInfo
        )

        Task {
            do {
                try await api.request(.post, path: "/me/reports", body: request)
                submitted = true
            } catch {
                // Still show submitted — don't expose backend errors for reports
                submitted = true
            }
            isSubmitting = false
        }
    }

    private var targetInfo: (String, UUID) {
        switch target {
        case .book(let id): ("book", id)
        case .review(let id): ("review", id)
        case .user(let id): ("user", id)
        }
    }
}

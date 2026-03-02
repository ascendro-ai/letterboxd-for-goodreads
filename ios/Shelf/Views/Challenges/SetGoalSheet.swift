import SwiftUI

struct SetGoalSheet: View {
    @Environment(\.dismiss) private var dismiss

    let year: Int
    let existingGoal: Int?
    let onSave: (Int) -> Void

    @State private var goalCount: Int

    init(year: Int, existingGoal: Int?, onSave: @escaping (Int) -> Void) {
        self.year = year
        self.existingGoal = existingGoal
        self.onSave = onSave
        self._goalCount = State(initialValue: existingGoal ?? 12)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(String(year))
                    .font(.title.bold())
                    .foregroundStyle(.secondary)

                Text("Reading Challenge")
                    .font(.title2.bold())

                Text("How many books do you want to read?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Goal picker
                HStack(spacing: 20) {
                    Button {
                        if goalCount > 1 { goalCount -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(goalCount > 1 ? Color.accentColor : Color(.systemGray4))
                    }
                    .disabled(goalCount <= 1)
                    .accessibilityLabel("Decrease goal")

                    Text("\(goalCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(minWidth: 80)
                        .accessibilityLabel("\(goalCount) books")

                    Button {
                        if goalCount < 999 { goalCount += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(goalCount < 999 ? Color.accentColor : Color(.systemGray4))
                    }
                    .disabled(goalCount >= 999)
                    .accessibilityLabel("Increase goal")
                }

                Text("\(goalCount) book\(goalCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onSave(goalCount)
                    dismiss()
                } label: {
                    Text(existingGoal != nil ? "Update Goal" : "Set Goal")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

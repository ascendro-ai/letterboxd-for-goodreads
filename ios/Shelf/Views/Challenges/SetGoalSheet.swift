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
            VStack(spacing: ShelfSpacing.xxxl) {
                Spacer()

                Text(String(year))
                    .font(ShelfFonts.displaySmall)
                    .foregroundStyle(ShelfColors.textSecondary)

                Text("Reading Challenge")
                    .font(ShelfFonts.displayMedium)
                    .foregroundStyle(ShelfColors.textPrimary)

                Text("How many books do you want to read?")
                    .font(ShelfFonts.subheadlineSans)
                    .foregroundStyle(ShelfColors.textSecondary)

                // Goal picker
                HStack(spacing: ShelfSpacing.xl) {
                    Button {
                        if goalCount > 1 { goalCount -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(goalCount > 1 ? ShelfColors.accent : ShelfColors.backgroundTertiary)
                    }
                    .disabled(goalCount <= 1)
                    .accessibilityLabel("Decrease goal")

                    Text("\(goalCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(ShelfColors.textPrimary)
                        .frame(minWidth: 80)
                        .accessibilityLabel("\(goalCount) books")

                    Button {
                        if goalCount < 999 { goalCount += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(goalCount < 999 ? ShelfColors.accent : ShelfColors.backgroundTertiary)
                    }
                    .disabled(goalCount >= 999)
                    .accessibilityLabel("Increase goal")
                }

                Text("\(goalCount) book\(goalCount == 1 ? "" : "s")")
                    .font(ShelfFonts.subheadlineSans)
                    .foregroundStyle(ShelfColors.textSecondary)

                Spacer()

                Button {
                    onSave(goalCount)
                    dismiss()
                } label: {
                    Text(existingGoal != nil ? "Update Goal" : "Set Goal")
                        .shelfPrimaryButton()
                }
                .padding(.horizontal, ShelfSpacing.lg)
            }
            .padding(ShelfSpacing.xxl)
            .shelfPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(ShelfFonts.bodySans)
                        .foregroundStyle(ShelfColors.accent)
                }
            }
        }
    }
}

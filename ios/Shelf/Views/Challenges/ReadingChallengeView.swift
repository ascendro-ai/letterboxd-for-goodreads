import SwiftUI

struct ReadingChallengeView: View {
    @State private var challenge: ReadingChallenge?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showSetGoal = false

    private let challengeService = ChallengeService.shared
    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        Group {
            if isLoading && challenge == nil {
                LoadingStateView()
            } else if challenge == nil {
                noGoalView
            } else if let challenge {
                challengeContent(challenge)
            }
        }
        .navigationTitle("\(String(currentYear)) Reading Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if challenge == nil { await load() }
        }
        .sheet(isPresented: $showSetGoal) {
            SetGoalSheet(year: currentYear, existingGoal: challenge?.goalCount) { goalCount in
                Task { await saveGoal(goalCount) }
            }
        }
        .shelfPageBackground()
    }

    private var noGoalView: some View {
        VStack(spacing: ShelfSpacing.xl) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(ShelfColors.accent)

            Text("Set a Reading Goal")
                .font(ShelfFonts.headlineSerif)
                .foregroundStyle(ShelfColors.textPrimary)

            Text("Challenge yourself to read more books this year.")
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ShelfSpacing.xxxl)

            Button {
                showSetGoal = true
            } label: {
                Text("Set Goal")
                    .shelfPrimaryButton()
            }
            .padding(.horizontal, ShelfSpacing.page)
        }
    }

    @ViewBuilder
    private func challengeContent(_ challenge: ReadingChallenge) -> some View {
        ScrollView {
            VStack(spacing: ShelfSpacing.xxl) {
                // Progress ring
                VStack(spacing: ShelfSpacing.md) {
                    ZStack {
                        Circle()
                            .stroke(ShelfColors.backgroundTertiary, lineWidth: 12)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: challenge.progressPercent)
                            .stroke(ShelfColors.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: challenge.progressPercent)
                        VStack(spacing: 2) {
                            Text("\(challenge.currentCount)")
                                .font(ShelfFonts.dataLarge)
                                .foregroundStyle(ShelfColors.textPrimary)
                            Text("of \(challenge.goalCount)")
                                .font(ShelfFonts.caption)
                                .foregroundStyle(ShelfColors.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(challenge.currentCount) of \(challenge.goalCount) books read")

                    Text("\(challenge.currentCount) of \(challenge.goalCount) books")
                        .font(ShelfFonts.headlineSans)
                        .foregroundStyle(ShelfColors.textPrimary)

                    if challenge.isComplete {
                        Label("Goal reached!", systemImage: "party.popper.fill")
                            .font(ShelfFonts.subheadlineSans)
                            .foregroundStyle(ShelfColors.forest)
                    }
                }

                // Edit goal
                Button {
                    showSetGoal = true
                } label: {
                    Text("Edit Goal")
                        .font(ShelfFonts.subheadlineBold)
                        .foregroundStyle(ShelfColors.accent)
                }

                // Books list
                if let books = challenge.books, !books.isEmpty {
                    VStack(alignment: .leading, spacing: ShelfSpacing.md) {
                        Text("Books Read")
                            .font(ShelfFonts.headlineSans)
                            .foregroundStyle(ShelfColors.textPrimary)
                            .padding(.horizontal, ShelfSpacing.lg)
                            .accessibilityAddTraits(.isHeader)

                        ForEach(books) { book in
                            HStack(spacing: ShelfSpacing.md) {
                                BookCoverImage(
                                    url: book.coverImageURL,
                                    size: CGSize(width: 40, height: 60),
                                    bookTitle: book.workTitle
                                )

                                VStack(alignment: .leading, spacing: ShelfSpacing.xxs) {
                                    Text(book.workTitle)
                                        .font(ShelfFonts.bodySerifBold)
                                        .lineLimit(2)
                                        .foregroundStyle(ShelfColors.textPrimary)
                                    if let author = book.authors.first {
                                        Text(author)
                                            .font(ShelfFonts.captionSerif)
                                            .foregroundStyle(ShelfColors.textSecondary)
                                    }
                                }

                                Spacer()

                                if let finished = book.finishedAt {
                                    Text(finished, format: .dateTime.month(.abbreviated).day())
                                        .font(ShelfFonts.caption)
                                        .foregroundStyle(ShelfColors.textSecondary)
                                }
                            }
                            .padding(.horizontal, ShelfSpacing.lg)

                            ShelfDivider()
                                .padding(.horizontal, ShelfSpacing.lg)
                        }
                    }
                }
            }
            .padding(.top, ShelfSpacing.lg)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        do {
            challenge = try await challengeService.getChallenge(year: currentYear)
        } catch {
            // No challenge set — show setup view
        }
        isLoading = false
    }

    @MainActor
    private func saveGoal(_ goalCount: Int) async {
        do {
            if challenge != nil {
                challenge = try await challengeService.updateChallenge(
                    year: currentYear,
                    request: UpdateChallengeRequest(goalCount: goalCount)
                )
            } else {
                challenge = try await challengeService.createChallenge(
                    CreateChallengeRequest(year: currentYear, goalCount: goalCount)
                )
            }
        } catch {
            self.error = error
        }
    }
}

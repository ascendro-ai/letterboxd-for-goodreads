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
    }

    private var noGoalView: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Set a Reading Goal")
                .font(.title3.bold())

            Text("Challenge yourself to read more books this year.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showSetGoal = true
            } label: {
                Text("Set Goal")
                    .font(.body.weight(.semibold))
                    .frame(width: 160, height: 44)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private func challengeContent(_ challenge: ReadingChallenge) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress ring
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 12)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: challenge.progressPercent)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: challenge.progressPercent)
                        VStack(spacing: 2) {
                            Text("\(challenge.currentCount)")
                                .font(.title.bold())
                            Text("of \(challenge.goalCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(challenge.currentCount) of \(challenge.goalCount) books read")

                    Text("\(challenge.currentCount) of \(challenge.goalCount) books")
                        .font(.headline)

                    if challenge.isComplete {
                        Label("Goal reached!", systemImage: "party.popper.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }

                // Edit goal
                Button {
                    showSetGoal = true
                } label: {
                    Text("Edit Goal")
                        .font(.subheadline.weight(.medium))
                }

                // Books list
                if let books = challenge.books, !books.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Books Read")
                            .font(.headline)
                            .padding(.horizontal)
                            .accessibilityAddTraits(.isHeader)

                        ForEach(books) { book in
                            HStack(spacing: 12) {
                                BookCoverImage(
                                    url: book.coverImageURL,
                                    size: CGSize(width: 40, height: 60),
                                    bookTitle: book.workTitle
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.workTitle)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(2)
                                    if let author = book.authors.first {
                                        Text(author)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if let finished = book.finishedAt {
                                    Text(finished, format: .dateTime.month(.abbreviated).day())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal)

                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 16)
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

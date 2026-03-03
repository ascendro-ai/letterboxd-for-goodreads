/// Reading statistics view with charts and stat cards.

import Charts
import SwiftUI

struct ReadingStatsView: View {
    @State private var viewModel: StatsViewModel
    @State private var selectedYear: Int?

    init(userID: UUID? = nil) {
        self._viewModel = State(initialValue: StatsViewModel(userID: userID))
    }

    var body: some View {
        content
            .navigationTitle("Reading Stats")
            .task {
                if viewModel.stats == nil {
                    await viewModel.load()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let stats = viewModel.stats {
            statsContent(stats)
        } else if let errorMessage = viewModel.error {
            ErrorStateView(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage]), retry: {
                Task { await viewModel.load() }
            })
        } else {
            LoadingStateView()
        }
    }

    @ViewBuilder
    private func statsContent(_ stats: ReadingStats) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary cards
                summaryCards(stats)

                // Current year chart
                if let breakdown = stats.currentYearStats.monthlyBreakdown, !breakdown.isEmpty {
                    monthlyChart(
                        title: "\(stats.currentYearStats.year) Reading",
                        data: breakdown,
                        booksRead: stats.currentYearStats.booksRead
                    )
                }

                // Rating distribution
                if let distribution = stats.currentYearStats.ratingDistribution, !distribution.isEmpty {
                    ratingDistributionChart(distribution)
                }

                // Top genres
                if let genres = stats.currentYearStats.topGenres, !genres.isEmpty {
                    topGenresSection(genres)
                }

                // Yearly history
                if stats.yearlyStats.count > 1 {
                    yearlyHistoryChart(stats.yearlyStats)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func summaryCards(_ stats: ReadingStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            StatCard(label: "Total Read", value: "\(stats.totalRead)", icon: "checkmark.circle.fill", color: .green)
            StatCard(label: "Currently Reading", value: "\(stats.totalReading)", icon: "book.fill", color: .blue)
            StatCard(label: "Want to Read", value: "\(stats.totalWantToRead)", icon: "bookmark.fill", color: .orange)

            if let avg = stats.averageRating {
                StatCard(label: "Avg Rating", value: String(format: "%.1f", avg), icon: "star.fill", color: .yellow)
            }

            if let pages = stats.currentYearStats.pagesRead {
                StatCard(label: "Pages This Year", value: pages.formatted(), icon: "doc.text.fill", color: .purple)
            }

            StatCard(label: "This Year", value: "\(stats.currentYearStats.booksRead)", icon: "calendar", color: .teal)
        }
    }

    @ViewBuilder
    private func monthlyChart(title: String, data: [MonthlyCount], booksRead: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("\(booksRead) books")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(data) { item in
                BarMark(
                    x: .value("Month", monthName(item.month)),
                    y: .value("Books", item.count)
                )
                .foregroundStyle(Color.accentColor)
                            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func ratingDistributionChart(_ distribution: [RatingDistribution]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating Distribution")
                .font(.headline)

            Chart(distribution) { item in
                BarMark(
                    x: .value("Rating", String(format: "%.1f", item.rating)),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Color.yellow)
                            }
            .frame(height: 160)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func topGenresSection(_ genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Genres")
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func yearlyHistoryChart(_ yearlyStats: [YearlyStats]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Yearly History")
                .font(.headline)

            Chart(yearlyStats) { item in
                BarMark(
                    x: .value("Year", String(item.year)),
                    y: .value("Books", item.booksRead)
                )
                .foregroundStyle(Color.accentColor)
                            }
            .frame(height: 160)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(month)"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

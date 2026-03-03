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
            VStack(spacing: ShelfSpacing.xxl) {
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
        .shelfPageBackground()
    }

    @ViewBuilder
    private func summaryCards(_ stats: ReadingStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: ShelfSpacing.md) {
            StatCard(label: "Total Read", value: "\(stats.totalRead)", icon: "checkmark.circle.fill", color: ShelfColors.forest)
            StatCard(label: "Currently Reading", value: "\(stats.totalReading)", icon: "book.fill", color: ShelfColors.ocean)
            StatCard(label: "Want to Read", value: "\(stats.totalWantToRead)", icon: "bookmark.fill", color: ShelfColors.amber)

            if let avg = stats.averageRating {
                StatCard(label: "Avg Rating", value: String(format: "%.1f", avg), icon: "star.fill", color: ShelfColors.starFilled)
            }

            if let pages = stats.currentYearStats.pagesRead {
                StatCard(label: "Pages This Year", value: pages.formatted(), icon: "doc.text.fill", color: ShelfColors.plum)
            }

            StatCard(label: "This Year", value: "\(stats.currentYearStats.booksRead)", icon: "calendar", color: ShelfColors.accent)
        }
    }

    @ViewBuilder
    private func monthlyChart(title: String, data: [MonthlyCount], booksRead: Int) -> some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
            Text(title)
                .font(ShelfFonts.headlineSans)
            Text("\(booksRead) books")
                .font(ShelfFonts.caption)
                .foregroundStyle(ShelfColors.textSecondary)

            Chart(data) { item in
                BarMark(
                    x: .value("Month", monthName(item.month)),
                    y: .value("Books", item.count)
                )
                .foregroundStyle(ShelfColors.accent)
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
        .background(ShelfColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
    }

    @ViewBuilder
    private func ratingDistributionChart(_ distribution: [RatingDistribution]) -> some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
            Text("Rating Distribution")
                .font(ShelfFonts.headlineSans)

            Chart(distribution) { item in
                BarMark(
                    x: .value("Rating", String(format: "%.1f", item.rating)),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(ShelfColors.starFilled)
                            }
            .frame(height: 160)
        }
        .padding()
        .background(ShelfColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
    }

    @ViewBuilder
    private func topGenresSection(_ genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
            Text("Top Genres")
                .font(ShelfFonts.headlineSans)

            FlowLayout(spacing: ShelfSpacing.xs) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(ShelfFonts.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ShelfColors.accentSubtle)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ShelfColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
    }

    @ViewBuilder
    private func yearlyHistoryChart(_ yearlyStats: [YearlyStats]) -> some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
            Text("Yearly History")
                .font(ShelfFonts.headlineSans)

            Chart(yearlyStats) { item in
                BarMark(
                    x: .value("Year", String(item.year)),
                    y: .value("Books", item.booksRead)
                )
                .foregroundStyle(ShelfColors.accent)
                            }
            .frame(height: 160)
        }
        .padding()
        .background(ShelfColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
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
        VStack(spacing: ShelfSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(ShelfFonts.dataSmall)
            Text(label)
                .font(ShelfFonts.caption)
                .foregroundStyle(ShelfColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ShelfSpacing.lg)
        .background(ShelfColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
    }
}

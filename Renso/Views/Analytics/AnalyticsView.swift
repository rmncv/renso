import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: AnalyticsViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel = viewModel {
                ScrollView {
                    VStack(spacing: 20) {
                        // Time range selector
                        TimeRangeSelector(selectedRange: Binding(
                            get: { viewModel.timeRange },
                            set: { newValue in
                                viewModel.timeRange = newValue
                                viewModel.loadData()
                            }
                        ))
                        .padding(.horizontal)

                        // Summary cards
                        HStack(spacing: 12) {
                            SummaryCard(
                                title: "Income",
                                amount: viewModel.totalIncome,
                                color: .green
                            )

                            SummaryCard(
                                title: "Expenses",
                                amount: viewModel.totalExpenses,
                                color: .red
                            )

                            SummaryCard(
                                title: "Net",
                                amount: viewModel.netIncome,
                                color: viewModel.netIncome >= 0 ? .green : .red
                            )
                        }
                        .padding(.horizontal)

                        // Category spending chart
                        if !viewModel.categorySpending.isEmpty {
                            CategorySpendingChart(spending: viewModel.categorySpending)
                                .frame(height: 300)
                                .padding()
                        }

                        // Monthly trends
                        if !viewModel.monthlyTrends.isEmpty {
                            MonthlyTrendsChart(trends: viewModel.monthlyTrends)
                                .frame(height: 250)
                                .padding()
                        }

                        // Top categories list
                        if !viewModel.categorySpending.isEmpty {
                            TopCategoriesList(spending: viewModel.categorySpending)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Analytics")
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AnalyticsViewModel(modelContext: modelContext)
            }
        }
    }
}

struct TimeRangeSelector: View {
    @Binding var selectedRange: AnalyticsTimeRange

    var body: some View {
        Picker("Time Range", selection: $selectedRange) {
            Text(AnalyticsTimeRange.week.title).tag(AnalyticsTimeRange.week)
            Text(AnalyticsTimeRange.month.title).tag(AnalyticsTimeRange.month)
            Text(AnalyticsTimeRange.threeMonths.title).tag(AnalyticsTimeRange.threeMonths)
            Text(AnalyticsTimeRange.year.title).tag(AnalyticsTimeRange.year)
            Text(AnalyticsTimeRange.all.title).tag(AnalyticsTimeRange.all)
        }
        .pickerStyle(.segmented)
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(amount.formatted(.currency(code: "UAH")))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CategorySpendingChart: View {
    let spending: [CategorySpending]

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Spending by Category")
                    .font(.headline)

                Chart(spending.prefix(5)) { item in
                    BarMark(
                        x: .value("Amount", item.total.doubleValue),
                        y: .value("Category", item.category.name)
                    )
                    .foregroundStyle(Color(hex: item.category.colorHex) ?? .blue)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }
            .padding()
        }
    }
}

struct MonthlyTrendsChart: View {
    let trends: [MonthlyTrend]

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Monthly Trends")
                    .font(.headline)

                Chart(trends) { trend in
                    LineMark(
                        x: .value("Month", trend.month, unit: .month),
                        y: .value("Income", trend.income.doubleValue)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Month", trend.month, unit: .month),
                        y: .value("Expenses", trend.expenses.doubleValue)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                }
                .chartLegend(position: .bottom)
            }
            .padding()
        }
    }
}

struct TopCategoriesList: View {
    let spending: [CategorySpending]

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Categories")
                    .font(.headline)
                    .padding(.bottom, 4)

                ForEach(spending.prefix(5)) { item in
                    HStack {
                        CategoryIconView(
                            iconName: item.category.iconName,
                            colorHex: item.category.colorHex,
                            size: 32
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("\(item.transactionCount) transactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.total.formatted(.currency(code: "UAH")))
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("\(Int(item.percentage))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if item.category.id != spending.prefix(5).last?.category.id {
                        Divider()
                    }
                }
            }
            .padding()
        }
    }
}

extension CategorySpending: Identifiable {
    var id: UUID { category.id }
}

extension MonthlyTrend: Identifiable {
    var id: Date { month }
}

#Preview {
    AnalyticsView()
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

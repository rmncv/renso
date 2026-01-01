import Foundation
import SwiftData

enum AnalyticsTimeRange {
    case week
    case month
    case threeMonths
    case year
    case all

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        case .all: return Int.max
        }
    }

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        case .year: return "Year"
        case .all: return "All Time"
        }
    }
}

struct CategorySpending {
    let category: Category
    let total: Decimal
    let transactionCount: Int
    let percentage: Double
}

struct MonthlyTrend {
    let month: Date
    let income: Decimal
    let expenses: Decimal
    let net: Decimal
}

@MainActor
@Observable
final class AnalyticsViewModel {
    private let modelContext: ModelContext
    private let converter: CurrencyConverter
    private let analytics: AnalyticsService

    // State
    var timeRange: AnalyticsTimeRange = .month
    var baseCurrency: String = "UAH"
    var isLoading = false
    var errorMessage: String?

    // Data
    var categorySpending: [CategorySpending] = []
    var monthlyTrends: [MonthlyTrend] = []
    var totalIncome: Decimal = 0
    var totalExpenses: Decimal = 0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.converter = CurrencyConverter(modelContext: modelContext)
        self.analytics = AnalyticsService.shared

        loadBaseCurrency()
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        Task {
            await loadCategorySpending()
            await loadMonthlyTrends()
        }
    }

    func loadCategorySpending() async {
        isLoading = true
        errorMessage = nil

        let startDate = getStartDate()

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startDate && $0.amount < 0 }
        )

        do {
            let transactions = try modelContext.fetch(descriptor)

            // Group by category
            let grouped = Dictionary(grouping: transactions.filter { $0.category != nil }) { $0.category! }

            var spending: [CategorySpending] = []
            var total: Decimal = 0

            for (category, categoryTransactions) in grouped {
                let categoryTotal = categoryTransactions.reduce(0) { $0 + abs($1.amount) }
                total += categoryTotal

                spending.append(CategorySpending(
                    category: category,
                    total: categoryTotal,
                    transactionCount: categoryTransactions.count,
                    percentage: 0 // Will calculate after we have total
                ))
            }

            // Calculate percentages
            categorySpending = spending.map { item in
                CategorySpending(
                    category: item.category,
                    total: item.total,
                    transactionCount: item.transactionCount,
                    percentage: total > 0 ? (item.total / total).doubleValue * 100 : 0
                )
            }.sorted { $0.total > $1.total }

            totalExpenses = total

            // Calculate income
            let incomeDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.date >= startDate && $0.amount > 0 }
            )
            let incomeTransactions = try modelContext.fetch(incomeDescriptor)
            totalIncome = incomeTransactions.reduce(0) { $0 + $1.amount }

        } catch {
            errorMessage = "Failed to load spending data: \(error.localizedDescription)"
        }

        isLoading = false
        analytics.track(.chartViewed, properties: ["type": "category_spending"])
    }

    func loadMonthlyTrends() async {
        let startDate = getStartDate()

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startDate },
            sortBy: [SortDescriptor(\Transaction.date, order: .forward)]
        )

        do {
            let transactions = try modelContext.fetch(descriptor)

            // Group by month
            let grouped = Dictionary(grouping: transactions) { transaction in
                Calendar.current.startOfMonth(for: transaction.date)
            }

            monthlyTrends = grouped.map { month, monthTransactions in
                let income = monthTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
                let expenses = monthTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }

                return MonthlyTrend(
                    month: month,
                    income: income,
                    expenses: expenses,
                    net: income - expenses
                )
            }.sorted { $0.month < $1.month }

        } catch {
            errorMessage = "Failed to load trends: \(error.localizedDescription)"
        }

        analytics.track(.chartViewed, properties: ["type": "monthly_trends"])
    }

    // MARK: - Actions

    func changeTimeRange(_ newRange: AnalyticsTimeRange) {
        timeRange = newRange
        loadData()
    }

    func refresh() async {
        await loadData()
    }

    // MARK: - Helpers

    private func getStartDate() -> Date {
        if timeRange == .all {
            return Date.distantPast
        }

        return Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
    }

    private func loadBaseCurrency() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            baseCurrency = settings.baseCurrencyCode
        }
    }

    // MARK: - Computed Properties

    var netIncome: Decimal {
        totalIncome - totalExpenses
    }

    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return (netIncome / totalIncome).doubleValue * 100
    }

    var averageMonthlyIncome: Decimal {
        guard !monthlyTrends.isEmpty else { return 0 }
        let total = monthlyTrends.reduce(0) { $0 + $1.income }
        return total / Decimal(monthlyTrends.count)
    }

    var averageMonthlyExpenses: Decimal {
        guard !monthlyTrends.isEmpty else { return 0 }
        let total = monthlyTrends.reduce(0) { $0 + $1.expenses }
        return total / Decimal(monthlyTrends.count)
    }

    var topCategory: CategorySpending? {
        categorySpending.first
    }
}


// MARK: - Calendar Extension

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

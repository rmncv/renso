import Foundation
import SwiftData

enum TransactionFilter {
    case all
    case income
    case expense
    case wallet(Wallet)
    case category(Category)
    case dateRange(from: Date, to: Date)
}

@MainActor
@Observable
final class TransactionsViewModel {
    private let modelContext: ModelContext
    private let rulesEngine: RulesEngine
    private let analytics: AnalyticsService

    // State
    var transactions: [Transaction] = []
    var isLoading = false
    var errorMessage: String?

    // Filters
    var selectedFilters: [TransactionFilter] = [.all]
    var searchText = ""

    // Sort
    var sortDescending = true

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.rulesEngine = RulesEngine(modelContext: modelContext)
        self.analytics = AnalyticsService.shared

        loadTransactions()
    }

    // MARK: - Data Loading

    func loadTransactions() {
        isLoading = true
        errorMessage = nil

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: sortDescending ? .reverse : .forward)]
        )

        do {
            var allTransactions = try modelContext.fetch(descriptor)

            // Apply filters in memory to avoid predicate issues with optionals
            for filter in selectedFilters {
                switch filter {
                case .all:
                    break

                case .income:
                    allTransactions = allTransactions.filter { $0.amount > 0 }

                case .expense:
                    allTransactions = allTransactions.filter { $0.amount < 0 }

                case .wallet(let wallet):
                    allTransactions = allTransactions.filter { $0.wallet?.id == wallet.id }

                case .category(let category):
                    allTransactions = allTransactions.filter { $0.category?.id == category.id }

                case .dateRange(let from, let to):
                    allTransactions = allTransactions.filter { $0.date >= from && $0.date <= to }
                }
            }

            // Apply search filter
            if !searchText.isEmpty {
                allTransactions = allTransactions.filter { transaction in
                    transaction.transactionDescription.localizedStandardContains(searchText)
                }
            }

            transactions = allTransactions
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - CRUD Operations

    func createTransaction(
        wallet: Wallet,
        amount: Decimal,
        description: String,
        date: Date,
        category: Category?,
        subCategory: SubCategory?,
        note: String?
    ) {
        let transaction = Transaction(
            amount: amount,
            description: description,
            date: date
        )

        transaction.wallet = wallet
        transaction.category = category
        transaction.subCategory = subCategory
        transaction.note = note

        modelContext.insert(transaction)

        do {
            try modelContext.save()

            // Apply rules if no category was set manually
            if category == nil {
                rulesEngine.applyRules(to: transaction)
            }

            loadTransactions()

            analytics.trackTransactionCreated(
                amount: amount,
                categoryName: category?.name ?? "Uncategorized",
                isIncome: amount > 0
            )
        } catch {
            errorMessage = "Failed to create transaction: \(error.localizedDescription)"
        }
    }

    func updateTransaction(
        _ transaction: Transaction,
        category: Category?,
        subCategory: SubCategory?,
        note: String?
    ) {
        transaction.category = category
        transaction.subCategory = subCategory
        transaction.note = note

        // Clear rule if category was manually set
        if category != nil {
            transaction.rule = nil
        }

        do {
            try modelContext.save()
            loadTransactions()
            analytics.track(.transactionEdited)
        } catch {
            errorMessage = "Failed to update transaction: \(error.localizedDescription)"
        }
    }

    func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)

        do {
            try modelContext.save()
            loadTransactions()
            analytics.track(.transactionDeleted)
        } catch {
            errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
        }
    }

    // MARK: - Filters

    func addFilter(_ filter: TransactionFilter) {
        // Remove "all" filter if adding specific filter
        if case .all = filter {
            selectedFilters = [.all]
        } else {
            selectedFilters.removeAll { if case .all = $0 { return true } else { return false } }
            selectedFilters.append(filter)
        }

        loadTransactions()
        analytics.track(.filterApplied)
    }

    func removeFilter(_ filter: TransactionFilter) {
        selectedFilters.removeAll { filterToCompare in
            switch (filter, filterToCompare) {
            case (.all, .all):
                return true
            case (.income, .income):
                return true
            case (.expense, .expense):
                return true
            case (.wallet(let w1), .wallet(let w2)):
                return w1.id == w2.id
            case (.category(let c1), .category(let c2)):
                return c1.id == c2.id
            default:
                return false
            }
        }

        if selectedFilters.isEmpty {
            selectedFilters = [.all]
        }

        loadTransactions()
    }

    func clearFilters() {
        selectedFilters = [.all]
        searchText = ""
        loadTransactions()
    }

    // MARK: - Bulk Operations

    func applyRulesToUncategorized() {
        let count = rulesEngine.applyRulesToUncategorized()
        loadTransactions()

        analytics.track(.ruleApplied, properties: [
            "transaction_count": count,
            "type": "bulk_uncategorized"
        ])
    }

    func categorizeTransaction(_ transaction: Transaction, category: Category, subCategory: SubCategory? = nil) {
        transaction.category = category
        transaction.subCategory = subCategory
        transaction.rule = nil

        do {
            try modelContext.save()
            loadTransactions()
            analytics.track(.transactionCategorized)
        } catch {
            errorMessage = "Failed to categorize transaction: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    var totalIncome: Decimal {
        transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    var totalExpense: Decimal {
        transactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    var netAmount: Decimal {
        totalIncome - totalExpense
    }

    var uncategorizedCount: Int {
        transactions.filter { $0.category == nil }.count
    }

    var hasActiveFilters: Bool {
        selectedFilters.count > 1 || (selectedFilters.count == 1 && !(selectedFilters.first is TransactionFilter))
    }

    // MARK: - Grouping

    func groupedByDate() -> [Date: [Transaction]] {
        Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }

    func groupedByCategory() -> [Category: [Transaction]] {
        let categorized = transactions.filter { $0.category != nil }
        return Dictionary(grouping: categorized) { $0.category! }
    }
}

import Foundation
import SwiftData

@MainActor
@Observable
final class CategoriesViewModel {
    private let modelContext: ModelContext
    private let analytics: AnalyticsService

    // State
    var expenseCategories: [Category] = []
    var incomeCategories: [Category] = []
    var isLoading = false
    var errorMessage: String?

    // Filter
    var showArchived = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.analytics = AnalyticsService.shared

        loadCategories()
    }

    // MARK: - Data Loading

    func loadCategories() {
        isLoading = true
        errorMessage = nil

        let predicate: Predicate<Category>
        if showArchived {
            predicate = #Predicate { _ in true }
        } else {
            predicate = #Predicate { !$0.isArchived }
        }

        let descriptor = FetchDescriptor<Category>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Category.sortOrder, order: .forward)]
        )

        do {
            let allCategories = try modelContext.fetch(descriptor)

            expenseCategories = allCategories.filter { $0.type == .expense }
            incomeCategories = allCategories.filter { $0.type == .income }
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - CRUD Operations

    func createCategory(
        name: String,
        type: CategoryType,
        iconName: String = "folder",
        colorHex: String = "#007AFF",
        isDefault: Bool = false
    ) {
        let category = Category(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            type: type,
            isDefault: isDefault
        )

        let existingCategories = type == .expense ? expenseCategories : incomeCategories
        category.sortOrder = existingCategories.count

        modelContext.insert(category)

        do {
            try modelContext.save()
            loadCategories()
            analytics.track(.categoryCreated, properties: ["type": type.rawValue])
        } catch {
            errorMessage = "Failed to create category: \(error.localizedDescription)"
        }
    }

    func updateCategory(
        _ category: Category,
        name: String,
        iconName: String,
        colorHex: String
    ) {
        category.name = name
        category.iconName = iconName
        category.colorHex = colorHex

        do {
            try modelContext.save()
            loadCategories()
            analytics.track(.categoryEdited)
        } catch {
            errorMessage = "Failed to update category: \(error.localizedDescription)"
        }
    }

    func archiveCategory(_ category: Category) {
        category.isArchived = true

        do {
            try modelContext.save()
            loadCategories()
        } catch {
            errorMessage = "Failed to archive category: \(error.localizedDescription)"
        }
    }

    func unarchiveCategory(_ category: Category) {
        category.isArchived = false

        do {
            try modelContext.save()
            loadCategories()
        } catch {
            errorMessage = "Failed to unarchive category: \(error.localizedDescription)"
        }
    }

    func deleteCategory(_ category: Category) {
        // Don't delete default categories
        guard !category.isDefault else {
            errorMessage = "Cannot delete default category"
            return
        }

        modelContext.delete(category)

        do {
            try modelContext.save()
            loadCategories()
            analytics.track(.categoryDeleted)
        } catch {
            errorMessage = "Failed to delete category: \(error.localizedDescription)"
        }
    }

    // MARK: - Sub-Categories

    func createSubCategory(
        parent: Category,
        name: String,
        iconName: String = "folder",
        colorHex: String = "#007AFF"
    ) {
        let subCategory = SubCategory(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            parentCategory: parent
        )

        let existingSubCategories = parent.subCategories ?? []
        subCategory.sortOrder = existingSubCategories.count

        modelContext.insert(subCategory)

        do {
            try modelContext.save()
            loadCategories()
        } catch {
            errorMessage = "Failed to create sub-category: \(error.localizedDescription)"
        }
    }

    func deleteSubCategory(_ subCategory: SubCategory) {
        modelContext.delete(subCategory)

        do {
            try modelContext.save()
            loadCategories()
        } catch {
            errorMessage = "Failed to delete sub-category: \(error.localizedDescription)"
        }
    }

    // MARK: - Reordering

    func moveCategory(from source: IndexSet, to destination: Int, type: CategoryType) {
        var categories = type == .expense ? expenseCategories : incomeCategories
        categories.move(fromOffsets: source, toOffset: destination)

        for (index, category) in categories.enumerated() {
            category.sortOrder = index
        }

        do {
            try modelContext.save()
            loadCategories()
        } catch {
            errorMessage = "Failed to reorder categories: \(error.localizedDescription)"
        }
    }

    // MARK: - Statistics

    func getCategoryUsageCount(_ category: Category) -> Int {
        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor) else {
            return 0
        }

        return allTransactions.filter { $0.category?.id == category.id }.count
    }

    func getCategoryTotalSpent(_ category: Category, last30Days: Bool = false) -> Decimal {
        let descriptor = FetchDescriptor<Transaction>()

        guard let allTransactions = try? modelContext.fetch(descriptor) else {
            return 0
        }

        var transactions = allTransactions.filter { $0.category?.id == category.id }

        if last30Days {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            transactions = transactions.filter { $0.date >= thirtyDaysAgo }
        }

        return transactions.reduce(0) { $0 + abs($1.amount) }
    }

    // MARK: - Computed Properties

    var totalExpenseCategories: Int {
        expenseCategories.count
    }

    var totalIncomeCategories: Int {
        incomeCategories.count
    }

    var customExpenseCategories: [Category] {
        expenseCategories.filter { !$0.isDefault }
    }

    var customIncomeCategories: [Category] {
        incomeCategories.filter { !$0.isDefault }
    }
}

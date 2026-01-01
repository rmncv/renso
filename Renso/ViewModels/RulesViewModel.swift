import Foundation
import SwiftData

@MainActor
@Observable
final class RulesViewModel {
    private let modelContext: ModelContext
    private let rulesEngine: RulesEngine
    private let analytics: AnalyticsService

    // State
    var rules: [Rule] = []
    var categories: [Category] = []
    var isLoading = false
    var errorMessage: String?

    // Filter
    var showInactive = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.rulesEngine = RulesEngine(modelContext: modelContext)
        self.analytics = AnalyticsService.shared

        loadCategories()
        loadRules()
    }

    // MARK: - Data Loading

    func loadRules() {
        isLoading = true
        errorMessage = nil

        let predicate: Predicate<Rule>
        if showInactive {
            predicate = #Predicate { _ in true }
        } else {
            predicate = #Predicate { $0.isActive }
        }

        let descriptor = FetchDescriptor<Rule>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Rule.priority, order: .forward)]
        )

        do {
            rules = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load rules: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadCategories() {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Category.name, order: .forward)]
        )

        do {
            categories = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD Operations

    func createRule(
        name: String,
        ruleType: RuleType,
        matchValue: String,
        category: Category,
        subCategory: SubCategory?,
        priority: Int = 30,
        isActive: Bool = true
    ) -> Bool {
        // Validate rule
        guard rulesEngine.validateRule(type: ruleType, matchValue: matchValue) else {
            errorMessage = "Invalid rule pattern"
            return false
        }

        let rule = Rule(
            name: name,
            ruleType: ruleType,
            matchValue: matchValue,
            category: category,
            subCategory: subCategory,
            priority: priority
        )

        rule.isActive = isActive

        modelContext.insert(rule)

        do {
            try modelContext.save()
            loadRules()

            analytics.trackRuleCreated(
                ruleType: ruleType.rawValue,
                categoryName: category.name
            )

            return true
        } catch {
            errorMessage = "Failed to create rule: \(error.localizedDescription)"
            return false
        }
    }

    func updateRule(
        _ rule: Rule,
        name: String,
        matchValue: String,
        category: Category,
        subCategory: SubCategory?,
        priority: Int
    ) -> Bool {
        // Validate rule
        guard rulesEngine.validateRule(type: rule.ruleType, matchValue: matchValue) else {
            errorMessage = "Invalid rule pattern"
            return false
        }

        rule.name = name
        rule.matchValue = matchValue
        rule.category = category
        rule.subCategory = subCategory
        rule.priority = priority

        do {
            try modelContext.save()
            loadRules()
            analytics.track(.ruleEdited)
            return true
        } catch {
            errorMessage = "Failed to update rule: \(error.localizedDescription)"
            return false
        }
    }

    func toggleRuleActive(_ rule: Rule) {
        rule.isActive.toggle()

        do {
            try modelContext.save()
            loadRules()
        } catch {
            errorMessage = "Failed to toggle rule: \(error.localizedDescription)"
        }
    }

    func deleteRule(_ rule: Rule) {
        modelContext.delete(rule)

        do {
            try modelContext.save()
            loadRules()
            analytics.track(.ruleDeleted)
        } catch {
            errorMessage = "Failed to delete rule: \(error.localizedDescription)"
        }
    }

    // MARK: - Rule Application

    func applyRulesToUncategorized() async -> Int {
        let count = rulesEngine.applyRulesToUncategorized()

        analytics.trackRuleApplied(
            ruleType: "bulk",
            transactionCount: count
        )

        return count
    }

    func reapplyAllRules() async -> Int {
        let count = rulesEngine.reapplyAllRules()

        analytics.trackRuleApplied(
            ruleType: "reapply_all",
            transactionCount: count
        )

        return count
    }

    func testRule(_ rule: Rule) -> [Transaction] {
        return rulesEngine.getMatchingTransactions(for: rule, limit: 10)
    }

    // MARK: - Statistics

    func getRuleStatistics(_ rule: Rule) -> (total: Int, last30Days: Int) {
        return rulesEngine.getRuleStatistics(for: rule)
    }

    // MARK: - Reordering (Priority)

    func moveRule(from source: IndexSet, to destination: Int) {
        var updatedRules = rules
        updatedRules.move(fromOffsets: source, toOffset: destination)

        // Update priorities
        for (index, rule) in updatedRules.enumerated() {
            rule.priority = index + 1
        }

        do {
            try modelContext.save()
            loadRules()
        } catch {
            errorMessage = "Failed to reorder rules: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    var activeRulesCount: Int {
        rules.filter { $0.isActive }.count
    }

    var mccRulesCount: Int {
        rules.filter { $0.ruleType == .mcc }.count
    }

    var descriptionRulesCount: Int {
        rules.filter { $0.ruleType == .description || $0.ruleType == .descriptionExact }.count
    }

    var amountRulesCount: Int {
        rules.filter { $0.ruleType == .amount }.count
    }

    var hasRules: Bool {
        !rules.isEmpty
    }
}

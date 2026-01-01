import Foundation
import SwiftData

@MainActor
final class RulesEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Apply Rules

    /// Apply rules to a single transaction
    /// - Parameter transaction: Transaction to categorize
    /// - Returns: True if a rule was applied
    @discardableResult
    func applyRules(to transaction: Transaction) -> Bool {
        // Skip if transaction already has a manually set category
        if transaction.category != nil && transaction.rule == nil {
            return false
        }

        // Fetch all active rules sorted by priority (lower number = higher priority)
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\Rule.priority, order: .forward)]
        )

        guard let rules = try? modelContext.fetch(descriptor) else {
            return false
        }

        // Try to find a matching rule
        for rule in rules {
            if matches(transaction: transaction, rule: rule) {
                applyRule(rule, to: transaction)
                return true
            }
        }

        return false
    }

    /// Apply rules to multiple transactions
    /// - Parameter transactions: Transactions to categorize
    /// - Returns: Number of transactions that were categorized
    @discardableResult
    func applyRules(to transactions: [Transaction]) -> Int {
        var categorizedCount = 0

        for transaction in transactions {
            if applyRules(to: transaction) {
                categorizedCount += 1
            }
        }

        if categorizedCount > 0 {
            try? modelContext.save()
        }

        return categorizedCount
    }

    /// Re-apply all rules to uncategorized transactions
    /// - Returns: Number of transactions that were categorized
    @discardableResult
    func applyRulesToUncategorized() -> Int {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.category == nil }
        )

        guard let transactions = try? modelContext.fetch(descriptor) else {
            return 0
        }

        return applyRules(to: transactions)
    }

    /// Re-apply all rules to all transactions (force recategorization)
    /// - Returns: Number of transactions that were categorized
    @discardableResult
    func reapplyAllRules() -> Int {
        let descriptor = FetchDescriptor<Transaction>()

        guard let transactions = try? modelContext.fetch(descriptor) else {
            return 0
        }

        // Clear existing rule-based categorizations
        for transaction in transactions {
            if transaction.rule != nil {
                transaction.category = nil
                transaction.subCategory = nil
                transaction.rule = nil
            }
        }

        return applyRules(to: transactions)
    }

    // MARK: - Rule Matching

    private func matches(transaction: Transaction, rule: Rule) -> Bool {
        switch rule.ruleType {
        case .mcc:
            return matchesMCC(transaction: transaction, rule: rule)

        case .description:
            return matchesDescription(transaction: transaction, rule: rule)

        case .descriptionExact:
            return matchesDescriptionExact(transaction: transaction, rule: rule)

        case .amount:
            return matchesAmount(transaction: transaction, rule: rule)
        }
    }

    private func matchesMCC(transaction: Transaction, rule: Rule) -> Bool {
        guard let mcc = transaction.mcc else { return false }
        return String(mcc) == rule.matchValue
    }

    private func matchesDescription(transaction: Transaction, rule: Rule) -> Bool {
        return transaction.transactionDescription.localizedCaseInsensitiveContains(rule.matchValue)
    }

    private func matchesDescriptionExact(transaction: Transaction, rule: Rule) -> Bool {
        return transaction.transactionDescription.localizedCompare(rule.matchValue) == .orderedSame
    }

    private func matchesAmount(transaction: Transaction, rule: Rule) -> Bool {
        // Match value format: "min-max" or "exact"
        let components = rule.matchValue.split(separator: "-")

        if components.count == 2 {
            // Range match
            guard let min = Decimal(string: String(components[0])),
                  let max = Decimal(string: String(components[1])) else {
                return false
            }

            let absAmount = abs(transaction.amount)
            return absAmount >= min && absAmount <= max
        } else {
            // Exact match
            guard let exactAmount = Decimal(string: rule.matchValue) else {
                return false
            }

            return abs(transaction.amount) == exactAmount
        }
    }

    // MARK: - Apply Rule

    private func applyRule(_ rule: Rule, to transaction: Transaction) {
        transaction.category = rule.category
        transaction.subCategory = rule.subCategory
        transaction.rule = rule
    }

    // MARK: - Rule Validation

    /// Validate if a rule pattern is valid
    func validateRule(type: RuleType, matchValue: String) -> Bool {
        switch type {
        case .mcc:
            // MCC should be a 4-digit number
            return matchValue.count == 4 && Int(matchValue) != nil

        case .description, .descriptionExact:
            // Description should not be empty
            return !matchValue.trimmingCharacters(in: .whitespaces).isEmpty

        case .amount:
            // Amount should be a number or range (e.g., "100-500")
            let components = matchValue.split(separator: "-")

            if components.count == 1 {
                return Decimal(string: matchValue) != nil
            } else if components.count == 2 {
                guard let min = Decimal(string: String(components[0])),
                      let max = Decimal(string: String(components[1])) else {
                    return false
                }
                return min < max
            }

            return false
        }
    }

    // MARK: - Rule Statistics

    /// Get statistics for a rule
    func getRuleStatistics(for rule: Rule) -> (total: Int, last30Days: Int) {
        let descriptor = FetchDescriptor<Transaction>()

        guard let allTransactions = try? modelContext.fetch(descriptor) else {
            return (0, 0)
        }

        let transactions = allTransactions.filter { $0.rule?.id == rule.id }
        let total = transactions.count

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30Days = transactions.filter { $0.date >= thirtyDaysAgo }.count

        return (total, last30Days)
    }

    /// Get transactions that would match a rule (for testing)
    func getMatchingTransactions(for rule: Rule, limit: Int = 10) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )

        guard let allTransactions = try? modelContext.fetch(descriptor) else {
            return []
        }

        var matchingTransactions: [Transaction] = []

        for transaction in allTransactions {
            if matches(transaction: transaction, rule: rule) {
                matchingTransactions.append(transaction)

                if matchingTransactions.count >= limit {
                    break
                }
            }
        }

        return matchingTransactions
    }
}

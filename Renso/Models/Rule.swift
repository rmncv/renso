import Foundation
import SwiftData

enum RuleType: String, Codable, CaseIterable {
    case mcc
    case description
    case descriptionExact
    case amount
}

@Model
final class Rule {
    var id: UUID = UUID()
    var name: String = ""
    private var ruleTypeRaw: String = RuleType.mcc.rawValue
    var matchValue: String = ""
    var isActive: Bool = true
    var priority: Int = 10
    var createdAt: Date = Date()

    var ruleType: RuleType {
        get { RuleType(rawValue: ruleTypeRaw) ?? .mcc }
        set { ruleTypeRaw = newValue.rawValue }
    }

    // Relationships
    var category: Category?
    var subCategory: SubCategory?

    @Relationship(inverse: \Transaction.rule)
    var appliedTransactions: [Transaction]?

    init(
        name: String,
        ruleType: RuleType,
        matchValue: String,
        category: Category,
        subCategory: SubCategory? = nil,
        priority: Int = 10
    ) {
        self.id = UUID()
        self.name = name
        self.ruleType = ruleType
        self.matchValue = matchValue
        self.category = category
        self.subCategory = subCategory
        self.priority = priority
        self.createdAt = Date()
    }
}

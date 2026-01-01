import Foundation
import SwiftData

enum CategoryType: String, Codable, CaseIterable {
    case expense
    case income
}

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "folder"
    var colorHex: String = "#007AFF"
    private var typeRaw: String = CategoryType.expense.rawValue
    var isDefault: Bool = false
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()

    var type: CategoryType {
        get { CategoryType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    // Relationships
    @Relationship(inverse: \Transaction.category)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .cascade, inverse: \SubCategory.parentCategory)
    var subCategories: [SubCategory]?

    @Relationship(deleteRule: .cascade, inverse: \Rule.category)
    var rules: [Rule]?

    // For refund linking
    @Relationship(inverse: \Transaction.refundForCategory)
    var refundTransactions: [Transaction]?

    init(
        name: String,
        iconName: String = "folder",
        colorHex: String = "#007AFF",
        type: CategoryType = .expense,
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.type = type
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}

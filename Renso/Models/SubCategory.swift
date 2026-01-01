import Foundation
import SwiftData

@Model
final class SubCategory {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "folder"
    var colorHex: String = "#007AFF"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    // Relationships
    var parentCategory: Category?

    @Relationship(inverse: \Transaction.subCategory)
    var transactions: [Transaction]?

    @Relationship(inverse: \Rule.subCategory)
    var rules: [Rule]?

    init(
        name: String,
        iconName: String = "folder",
        colorHex: String = "#007AFF",
        parentCategory: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.parentCategory = parentCategory
        self.createdAt = Date()
    }
}

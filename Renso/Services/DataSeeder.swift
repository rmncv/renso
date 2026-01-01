import Foundation
import SwiftData

@MainActor
final class DataSeeder {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func seedDefaultDataIfNeeded() async throws {
        try await seedCategoriesIfNeeded()
        try await seedUserSettingsIfNeeded()
    }

    // MARK: - Categories

    private func seedCategoriesIfNeeded() async throws {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isDefault }
        )
        let existingDefaults = try modelContext.fetch(descriptor)
        guard existingDefaults.isEmpty else { return }

        // Seed expense categories
        let expenseCategories = DefaultCategories.expenses
        for (index, cat) in expenseCategories.enumerated() {
            let category = Category(
                name: cat.name,
                iconName: cat.icon,
                colorHex: cat.color,
                type: .expense,
                isDefault: true
            )
            category.sortOrder = index
            modelContext.insert(category)

            // Create MCC-based rules for this category
            for mcc in cat.mccCodes {
                let rule = Rule(
                    name: "Auto: \(cat.name) (MCC \(mcc))",
                    ruleType: .mcc,
                    matchValue: mcc,
                    category: category,
                    priority: 10
                )
                modelContext.insert(rule)
            }
        }

        // Seed income categories
        let incomeCategories = DefaultCategories.incomes
        for (index, cat) in incomeCategories.enumerated() {
            let category = Category(
                name: cat.name,
                iconName: cat.icon,
                colorHex: cat.color,
                type: .income,
                isDefault: true
            )
            category.sortOrder = index
            modelContext.insert(category)
        }

        // Add common subscription rules
        try await seedSubscriptionRules()

        try modelContext.save()
    }

    private func seedSubscriptionRules() async throws {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.name == "Subscriptions" && $0.isDefault }
        )
        guard let subscriptionsCategory = try modelContext.fetch(descriptor).first else { return }

        let subscriptionPatterns = [
            "Netflix", "Spotify", "YouTube", "Apple", "Google",
            "Amazon Prime", "Disney+", "HBO", "Hulu", "iCloud"
        ]

        for pattern in subscriptionPatterns {
            let rule = Rule(
                name: "Description: \(pattern)",
                ruleType: .description,
                matchValue: pattern,
                category: subscriptionsCategory,
                priority: 20
            )
            modelContext.insert(rule)
        }
    }

    // MARK: - User Settings

    private func seedUserSettingsIfNeeded() async throws {
        let descriptor = FetchDescriptor<UserSettings>()
        let existing = try modelContext.fetch(descriptor)
        guard existing.isEmpty else { return }

        let settings = UserSettings()
        settings.baseCurrencyCode = "UAH"
        modelContext.insert(settings)

        try modelContext.save()
    }
}

// MARK: - Default Categories Data

enum DefaultCategories {
    struct CategoryData {
        let name: String
        let icon: String
        let color: String
        let mccCodes: [String]

        init(name: String, icon: String, color: String, mccCodes: [String] = []) {
            self.name = name
            self.icon = icon
            self.color = color
            self.mccCodes = mccCodes
        }
    }

    static let expenses: [CategoryData] = [
        CategoryData(
            name: "Groceries",
            icon: "cart.fill",
            color: "#34C759",
            mccCodes: ["5411", "5422", "5441", "5451", "5462"]
        ),
        CategoryData(
            name: "Restaurants",
            icon: "fork.knife",
            color: "#FF9500",
            mccCodes: ["5812", "5813", "5814"]
        ),
        CategoryData(
            name: "Transport",
            icon: "car.fill",
            color: "#007AFF",
            mccCodes: ["4111", "4121", "4131", "5541", "5542"]
        ),
        CategoryData(
            name: "Entertainment",
            icon: "theatermasks.fill",
            color: "#AF52DE",
            mccCodes: ["7832", "7841", "7911", "7922", "7929", "7932", "7933", "7941"]
        ),
        CategoryData(
            name: "Shopping",
            icon: "bag.fill",
            color: "#FF2D55",
            mccCodes: ["5311", "5611", "5621", "5631", "5641", "5651", "5661", "5691", "5699"]
        ),
        CategoryData(
            name: "Health",
            icon: "heart.fill",
            color: "#FF3B30",
            mccCodes: ["5912", "8011", "8021", "8031", "8041", "8042", "8043", "8049", "8050", "8062", "8071"]
        ),
        CategoryData(
            name: "Bills & Utilities",
            icon: "bolt.fill",
            color: "#FFCC00",
            mccCodes: ["4814", "4816", "4899", "4900"]
        ),
        CategoryData(
            name: "Education",
            icon: "book.fill",
            color: "#5856D6",
            mccCodes: ["8211", "8220", "8241", "8244", "8249", "8299"]
        ),
        CategoryData(
            name: "Travel",
            icon: "airplane",
            color: "#00C7BE",
            mccCodes: ["4511", "4722", "7011", "7012"]
        ),
        CategoryData(
            name: "Subscriptions",
            icon: "repeat",
            color: "#8E8E93",
            mccCodes: []
        ),
        CategoryData(
            name: "Transfers",
            icon: "arrow.left.arrow.right",
            color: "#636366",
            mccCodes: []
        ),
        CategoryData(
            name: "ATM",
            icon: "banknote.fill",
            color: "#48484A",
            mccCodes: ["6010", "6011"]
        ),
        CategoryData(
            name: "Other",
            icon: "ellipsis.circle.fill",
            color: "#AEAEB2",
            mccCodes: []
        )
    ]

    static let incomes: [CategoryData] = [
        CategoryData(name: "Salary", icon: "briefcase.fill", color: "#34C759"),
        CategoryData(name: "Freelance", icon: "laptopcomputer", color: "#007AFF"),
        CategoryData(name: "Investments", icon: "chart.line.uptrend.xyaxis", color: "#5856D6"),
        CategoryData(name: "Gifts", icon: "gift.fill", color: "#FF2D55"),
        CategoryData(name: "Refunds", icon: "arrow.uturn.backward", color: "#FF9500"),
        CategoryData(name: "Other Income", icon: "plus.circle.fill", color: "#00C7BE")
    ]
}

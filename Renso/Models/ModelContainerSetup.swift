import Foundation
import SwiftData

enum ModelContainerSetup {
    static var schema: Schema {
        Schema([
            Wallet.self,
            Transaction.self,
            Category.self,
            SubCategory.self,
            Rule.self,
            Transfer.self,
            CryptoHolding.self,
            CryptoTransaction.self,
            StockHolding.self,
            StockTransaction.self,
            ExchangeRate.self,
            UserSettings.self
        ])
    }

    static func createContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func createPreviewContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func createTestContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

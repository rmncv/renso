import Foundation
import SwiftData

struct NetWorthBreakdown {
    let totalInBaseCurrency: Decimal
    let walletsValue: Decimal
    let cryptoValue: Decimal
    let stocksValue: Decimal

    let walletBreakdown: [WalletValue]
    let cryptoBreakdown: [CryptoValue]
    let stockBreakdown: [StockValue]

    var walletsPercentage: Double {
        guard totalInBaseCurrency > 0 else { return 0 }
        return (walletsValue / totalInBaseCurrency).doubleValue * 100
    }

    var cryptoPercentage: Double {
        guard totalInBaseCurrency > 0 else { return 0 }
        return (cryptoValue / totalInBaseCurrency).doubleValue * 100
    }

    var stocksPercentage: Double {
        guard totalInBaseCurrency > 0 else { return 0 }
        return (stocksValue / totalInBaseCurrency).doubleValue * 100
    }
}

struct WalletValue {
    let wallet: Wallet
    let valueInBaseCurrency: Decimal

    var percentage: Double {
        // Will be calculated by service relative to total wallets value
        0
    }
}

struct CryptoValue {
    let holding: CryptoHolding
    let valueInBaseCurrency: Decimal
    let gainLoss: Decimal
    let gainLossPercentage: Double
}

struct StockValue {
    let holding: StockHolding
    let valueInBaseCurrency: Decimal
    let gainLoss: Decimal
    let gainLossPercentage: Double
}

@MainActor
final class NetWorthService {
    private let modelContext: ModelContext
    private let converter: CurrencyConverter

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.converter = CurrencyConverter(modelContext: modelContext)
    }

    // MARK: - Net Worth Calculation

    /// Calculate total net worth in base currency
    func calculateNetWorth(baseCurrency: String = "UAH") -> NetWorthBreakdown {
        let walletsValue = calculateWalletsValue(baseCurrency: baseCurrency)
        let cryptoValue = calculateCryptoValue(baseCurrency: baseCurrency)
        let stocksValue = calculateStocksValue(baseCurrency: baseCurrency)

        let total = walletsValue.total + cryptoValue.total + stocksValue.total

        return NetWorthBreakdown(
            totalInBaseCurrency: total,
            walletsValue: walletsValue.total,
            cryptoValue: cryptoValue.total,
            stocksValue: stocksValue.total,
            walletBreakdown: walletsValue.breakdown,
            cryptoBreakdown: cryptoValue.breakdown,
            stockBreakdown: stocksValue.breakdown
        )
    }

    // MARK: - Wallets

    private func calculateWalletsValue(baseCurrency: String) -> (total: Decimal, breakdown: [WalletValue]) {
        let descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { !$0.isArchived }
        )

        guard let wallets = try? modelContext.fetch(descriptor) else {
            return (0, [])
        }

        var breakdown: [WalletValue] = []
        var total: Decimal = 0

        for wallet in wallets {
            let valueInBase = converter.convert(
                amount: wallet.currentBalance,
                from: wallet.currencyCode,
                to: baseCurrency
            ) ?? wallet.currentBalance

            breakdown.append(WalletValue(
                wallet: wallet,
                valueInBaseCurrency: valueInBase
            ))

            total += valueInBase
        }

        return (total, breakdown)
    }

    // MARK: - Crypto

    private func calculateCryptoValue(baseCurrency: String) -> (total: Decimal, breakdown: [CryptoValue]) {
        let descriptor = FetchDescriptor<CryptoHolding>()

        guard let holdings = try? modelContext.fetch(descriptor) else {
            return (0, [])
        }

        var breakdown: [CryptoValue] = []
        var total: Decimal = 0

        for holding in holdings {
            guard holding.quantity > 0 else { continue }

            let currentValue = holding.quantity * (holding.lastPrice ?? 0)
            let costBasis = holding.quantity * holding.averagePurchasePrice

            let valueInBase = converter.convert(
                amount: currentValue,
                from: holding.purchaseCurrencyCode,
                to: baseCurrency
            ) ?? currentValue

            let costBasisInBase = converter.convert(
                amount: costBasis,
                from: holding.purchaseCurrencyCode,
                to: baseCurrency
            ) ?? costBasis

            let gainLoss = valueInBase - costBasisInBase
            let gainLossPercentage = costBasisInBase > 0 ? (gainLoss / costBasisInBase).doubleValue * 100 : 0

            breakdown.append(CryptoValue(
                holding: holding,
                valueInBaseCurrency: valueInBase,
                gainLoss: gainLoss,
                gainLossPercentage: gainLossPercentage
            ))

            total += valueInBase
        }

        return (total, breakdown)
    }

    // MARK: - Stocks

    private func calculateStocksValue(baseCurrency: String) -> (total: Decimal, breakdown: [StockValue]) {
        let descriptor = FetchDescriptor<StockHolding>()

        guard let holdings = try? modelContext.fetch(descriptor) else {
            return (0, [])
        }

        var breakdown: [StockValue] = []
        var total: Decimal = 0

        for holding in holdings {
            guard holding.quantity > 0 else { continue }

            let currentValue = holding.quantity * (holding.lastPrice ?? 0)
            let costBasis = holding.quantity * holding.averagePurchasePrice

            let valueInBase = converter.convert(
                amount: currentValue,
                from: holding.purchaseCurrencyCode,
                to: baseCurrency
            ) ?? currentValue

            let costBasisInBase = converter.convert(
                amount: costBasis,
                from: holding.purchaseCurrencyCode,
                to: baseCurrency
            ) ?? costBasis

            let gainLoss = valueInBase - costBasisInBase
            let gainLossPercentage = costBasisInBase > 0 ? (gainLoss / costBasisInBase).doubleValue * 100 : 0

            breakdown.append(StockValue(
                holding: holding,
                valueInBaseCurrency: valueInBase,
                gainLoss: gainLoss,
                gainLossPercentage: gainLossPercentage
            ))

            total += valueInBase
        }

        return (total, breakdown)
    }

    // MARK: - Simple Getters

    /// Get total value of all wallets in base currency
    func getTotalWalletsValue(baseCurrency: String = "UAH") -> Decimal {
        return calculateWalletsValue(baseCurrency: baseCurrency).total
    }

    /// Get total value of crypto portfolio in base currency
    func getTotalCryptoValue(baseCurrency: String = "UAH") -> Decimal {
        return calculateCryptoValue(baseCurrency: baseCurrency).total
    }

    /// Get total value of stock portfolio in base currency
    func getTotalStocksValue(baseCurrency: String = "UAH") -> Decimal {
        return calculateStocksValue(baseCurrency: baseCurrency).total
    }

    /// Get total net worth in base currency
    func getTotalNetWorth(baseCurrency: String = "UAH") -> Decimal {
        return getTotalWalletsValue(baseCurrency: baseCurrency) +
               getTotalCryptoValue(baseCurrency: baseCurrency) +
               getTotalStocksValue(baseCurrency: baseCurrency)
    }
}


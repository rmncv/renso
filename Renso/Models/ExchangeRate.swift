import Foundation
import SwiftData

@Model
final class ExchangeRate {
    var id: UUID = UUID()
    var fromCurrencyCode: String = ""
    var toCurrencyCode: String = ""
    var rate: Decimal = 0
    var buyRate: Decimal?
    var sellRate: Decimal?
    var source: String = "manual"
    var fetchedAt: Date = Date()

    var averageRate: Decimal {
        if let buy = buyRate, let sell = sellRate {
            return (buy + sell) / 2
        }
        return rate
    }

    var currencyPair: String {
        "\(fromCurrencyCode)/\(toCurrencyCode)"
    }

    init(
        fromCurrencyCode: String,
        toCurrencyCode: String,
        rate: Decimal,
        buyRate: Decimal? = nil,
        sellRate: Decimal? = nil,
        source: String = "manual"
    ) {
        self.id = UUID()
        self.fromCurrencyCode = fromCurrencyCode
        self.toCurrencyCode = toCurrencyCode
        self.rate = rate
        self.buyRate = buyRate
        self.sellRate = sellRate
        self.source = source
        self.fetchedAt = Date()
    }

    func convert(amount: Decimal) -> Decimal {
        amount * rate
    }

    func reverseConvert(amount: Decimal) -> Decimal {
        guard rate > 0 else { return 0 }
        return amount / rate
    }
}

import Foundation

extension Decimal {
    /// Absolute value of the decimal
    var absoluteValue: Decimal {
        self < 0 ? -self : self
    }

    /// Check if value is zero
    var isZero: Bool {
        self == 0
    }

    /// Check if value is positive (greater than zero)
    var isPositive: Bool {
        self > 0
    }

    /// Check if value is negative
    var isNegative: Bool {
        self < 0
    }

    /// Convert to Double (use sparingly, loses precision)
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    /// Round to specified decimal places
    func rounded(toPlaces places: Int) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, places, .bankers)
        return result
    }

    /// Format as string with specified decimal places
    func formatted(decimalPlaces: Int = 2) -> String {
        Formatters.decimal(self, decimalPlaces: decimalPlaces)
    }

    /// Format as currency
    func formatted(currencyCode: String, showCents: Bool = true) -> String {
        Formatters.amount(self, currencyCode: currencyCode, showCents: showCents)
    }
}

// MARK: - Arithmetic convenience
extension Decimal {
    static func / (lhs: Decimal, rhs: Int) -> Decimal {
        lhs / Decimal(rhs)
    }

    static func * (lhs: Decimal, rhs: Int) -> Decimal {
        lhs * Decimal(rhs)
    }
}

import Foundation

/// ISO 4217 Currency Code Utilities
/// Provides conversion between numeric and alphabetic currency codes
enum ISO4217 {
    /// Maps numeric ISO 4217 codes to alphabetic codes
    private static let numericToAlpha: [Int: String] = [
        980: "UAH",  // Ukrainian Hryvnia
        840: "USD",  // US Dollar
        978: "EUR",  // Euro
        826: "GBP",  // British Pound
        985: "PLN",  // Polish Zloty
        203: "CZK",  // Czech Koruna
        756: "CHF",  // Swiss Franc
        392: "JPY",  // Japanese Yen
        156: "CNY",  // Chinese Yuan
        124: "CAD",  // Canadian Dollar
        036: "AUD",  // Australian Dollar
        949: "TRY",  // Turkish Lira
        784: "AED",  // UAE Dirham
        643: "RUB",  // Russian Ruble (if needed)
        975: "BGN",  // Bulgarian Lev
        946: "RON",  // Romanian Leu
        348: "HUF",  // Hungarian Forint
        208: "DKK",  // Danish Krone
        578: "NOK",  // Norwegian Krone
        752: "SEK",  // Swedish Krona
        376: "ILS",  // Israeli Shekel
        702: "SGD",  // Singapore Dollar
        344: "HKD",  // Hong Kong Dollar
        410: "KRW",  // South Korean Won
        356: "INR",  // Indian Rupee
        986: "BRL",  // Brazilian Real
        484: "MXN",  // Mexican Peso
        710: "ZAR",  // South African Rand
        554: "NZD",  // New Zealand Dollar
        764: "THB",  // Thai Baht
        458: "MYR",  // Malaysian Ringgit
        360: "IDR",  // Indonesian Rupiah
        608: "PHP",  // Philippine Peso
        704: "VND",  // Vietnamese Dong
        682: "SAR",  // Saudi Riyal
        818: "EGP",  // Egyptian Pound
        414: "KWD",  // Kuwaiti Dinar
        634: "QAR",  // Qatari Riyal
        512: "OMR",  // Omani Rial
        048: "BHD",  // Bahraini Dinar
        400: "JOD",  // Jordanian Dinar
        144: "LKR",  // Sri Lankan Rupee
        050: "BDT",  // Bangladeshi Taka
        586: "PKR",  // Pakistani Rupee
        566: "NGN",  // Nigerian Naira
        404: "KES",  // Kenyan Shilling
        834: "TZS",  // Tanzanian Shilling
        800: "UGX",  // Ugandan Shilling
        936: "GHS",  // Ghanaian Cedi
        951: "XCD",  // East Caribbean Dollar
        932: "ZWL",  // Zimbabwean Dollar
    ]

    /// Maps alphabetic ISO 4217 codes to numeric codes
    private static let alphaToNumeric: [String: Int] = {
        Dictionary(uniqueKeysWithValues: numericToAlpha.map { ($1, $0) })
    }()

    /// Minor units (decimal places) for each currency
    private static let minorUnitsMap: [String: Int] = [
        "UAH": 2, "USD": 2, "EUR": 2, "GBP": 2, "PLN": 2,
        "CZK": 2, "CHF": 2, "CAD": 2, "AUD": 2, "TRY": 2,
        "AED": 2, "RUB": 2, "BGN": 2, "RON": 2, "DKK": 2,
        "NOK": 2, "SEK": 2, "ILS": 2, "SGD": 2, "HKD": 2,
        "INR": 2, "BRL": 2, "MXN": 2, "ZAR": 2, "NZD": 2,
        "THB": 2, "MYR": 2, "PHP": 2, "SAR": 2, "EGP": 2,
        "QAR": 2, "LKR": 2, "BDT": 2, "PKR": 2, "NGN": 2,
        "KES": 2, "GHS": 2, "XCD": 2,
        "JPY": 0, "KRW": 0, "VND": 0, "IDR": 0, "HUF": 0,
        "TZS": 0, "UGX": 0, "ZWL": 0, "CNY": 2,
        "KWD": 3, "OMR": 3, "BHD": 3, "JOD": 3,
    ]

    /// Currency symbols for display
    private static let symbolsMap: [String: String] = [
        "UAH": "₴", "USD": "$", "EUR": "€", "GBP": "£", "PLN": "zł",
        "CZK": "Kč", "CHF": "Fr", "JPY": "¥", "CNY": "¥", "CAD": "C$",
        "AUD": "A$", "TRY": "₺", "AED": "د.إ", "RUB": "₽", "BGN": "лв",
        "RON": "lei", "HUF": "Ft", "DKK": "kr", "NOK": "kr", "SEK": "kr",
        "ILS": "₪", "SGD": "S$", "HKD": "HK$", "KRW": "₩", "INR": "₹",
        "BRL": "R$", "MXN": "Mex$", "ZAR": "R", "NZD": "NZ$", "THB": "฿",
        "MYR": "RM", "IDR": "Rp", "PHP": "₱", "VND": "₫", "SAR": "﷼",
        "EGP": "E£", "KWD": "د.ك", "QAR": "﷼", "OMR": "﷼", "BHD": ".د.ب",
        "JOD": "د.ا", "LKR": "Rs", "BDT": "৳", "PKR": "₨", "NGN": "₦",
        "KES": "KSh", "TZS": "TSh", "UGX": "USh", "GHS": "₵", "XCD": "EC$",
    ]

    /// Convert numeric ISO 4217 code to alphabetic code
    static func alphaCode(for numericCode: Int) -> String? {
        numericToAlpha[numericCode]
    }

    /// Convert alphabetic ISO 4217 code to numeric code
    static func numericCode(for alphaCode: String) -> Int? {
        alphaToNumeric[alphaCode.uppercased()]
    }

    /// Get number of minor units (decimal places) for currency
    static func minorUnits(for currencyCode: String) -> Decimal {
        let places = minorUnitsMap[currencyCode.uppercased()] ?? 2
        return Decimal(sign: .plus, exponent: places, significand: 1)
    }

    /// Get decimal places count for currency
    static func decimalPlaces(for currencyCode: String) -> Int {
        minorUnitsMap[currencyCode.uppercased()] ?? 2
    }

    /// Get currency symbol
    static func symbol(for currencyCode: String) -> String {
        symbolsMap[currencyCode.uppercased()] ?? currencyCode
    }

    /// Get currency name
    static func name(for currencyCode: String) -> String {
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }

    /// Convert amount from minor units (e.g., kopiykas) to major units (e.g., hryvnia)
    static func fromMinorUnits(_ amount: Int64, currencyCode: String) -> Decimal {
        let divisor = minorUnits(for: currencyCode)
        return Decimal(amount) / divisor
    }

    /// Convert amount from major units to minor units
    static func toMinorUnits(_ amount: Decimal, currencyCode: String) -> Int64 {
        let multiplier = minorUnits(for: currencyCode)
        let result = amount * multiplier
        return NSDecimalNumber(decimal: result).int64Value
    }

    /// Common currencies for quick access
    static let commonCurrencies = ["UAH", "USD", "EUR", "GBP", "PLN", "CZK"]

    /// All supported currencies
    static var allCurrencies: [String] {
        Array(numericToAlpha.values).sorted()
    }
}

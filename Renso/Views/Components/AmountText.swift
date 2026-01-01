import SwiftUI

struct AmountText: View {
    let amount: Decimal
    let currencyCode: String
    let isIncome: Bool?
    let showSign: Bool
    let fontSize: CGFloat

    init(
        amount: Decimal,
        currencyCode: String,
        isIncome: Bool? = nil,
        showSign: Bool = true,
        fontSize: CGFloat = 17
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.isIncome = isIncome
        self.showSign = showSign
        self.fontSize = fontSize
    }

    var body: some View {
        Text(formattedAmount)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
    }

    private var formattedAmount: String {
        var formatted = Formatters.currency(abs(amount), currencyCode: currencyCode)

        if showSign {
            if let isIncome = isIncome {
                formatted = (isIncome ? "+" : "-") + formatted
            } else if amount > 0 {
                formatted = "+" + formatted
            } else if amount < 0 {
                formatted = "-" + formatted
            }
        }

        return formatted
    }

    private var color: Color {
        if let isIncome = isIncome {
            return isIncome ? .green : .red
        }

        if amount > 0 {
            return .green
        } else if amount < 0 {
            return .red
        }

        return .primary
    }
}

#Preview {
    VStack(spacing: 16) {
        AmountText(amount: 1250.50, currencyCode: "USD", isIncome: true)
        AmountText(amount: 1250.50, currencyCode: "USD", isIncome: false)
        AmountText(amount: 1250.50, currencyCode: "UAH", showSign: false, fontSize: 24)
    }
    .padding()
}

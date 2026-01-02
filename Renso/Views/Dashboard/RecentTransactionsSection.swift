import SwiftUI
import SwiftData

struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    let isLoading: Bool
    var onTransactionTap: ((Transaction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    Text("All Transactions")
                } label: {
                    Text("See All")
                        .font(.subheadline)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if transactions.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Transactions",
                    message: "Your recent transactions will appear here"
                )
                .frame(height: 200)
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions.prefix(5)) { transaction in
                        TransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTransactionTap?(transaction)
                            }

                        if transaction.id != transactions.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            if let category = transaction.category {
                CategoryIconView(
                    iconName: category.iconName,
                    colorHex: category.colorHex,
                    size: 40
                )
            } else {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let category = transaction.category {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Uncategorized")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(Formatters.smartDate(transaction.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            AmountText(
                amount: transaction.amount,
                currencyCode: transaction.wallet?.currencyCode ?? "UAH",
                isIncome: transaction.amount > 0,
                fontSize: 15
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    @Previewable @State var transactions: [Transaction] = {
        let container = try! ModelContainerSetup.createPreviewContainer()
        let context = container.mainContext

        let wallet = Wallet(name: "Main", currencyCode: "UAH", initialBalance: 10000)
        context.insert(wallet)

        let category = Category(name: "Groceries", iconName: "cart.fill", colorHex: "#34C759", type: .expense)
        context.insert(category)

        let transaction = Transaction(amount: -250, description: "Supermarket", date: Date())
        transaction.wallet = wallet
        transaction.category = category
        context.insert(transaction)

        return [transaction]
    }()

    RecentTransactionsSection(transactions: transactions, isLoading: false)
        .padding()
}

import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TransactionsViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel = viewModel {
                VStack(spacing: 0) {
                    // Search bar
                    SearchBar(text: Binding(
                        get: { viewModel.searchText },
                        set: { newValue in
                            viewModel.searchText = newValue
                            viewModel.loadTransactions()
                        }
                    ))
                    .padding()

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.transactions.isEmpty {
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No Transactions",
                            message: "Your transactions will appear here"
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.transactions) { transaction in
                                TransactionListRow(transaction: transaction)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("Transactions")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // TODO: Show add transaction sheet
                        } label: {
                            Image(systemName: "plus")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // TODO: Show filters sheet
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TransactionsViewModel(modelContext: modelContext)
            }
        }
    }
}

struct TransactionListRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            if let category = transaction.category {
                CategoryIconView(
                    iconName: category.iconName,
                    colorHex: category.colorHex,
                    size: 44
                )
            } else {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionDescription)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let category = transaction.category {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let subCategory = transaction.subCategory {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(subCategory.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            AmountText(
                amount: transaction.amount,
                currencyCode: transaction.wallet?.currencyCode ?? "UAH"
            )
            .font(.body)
            .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search transactions", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    TransactionsListView()
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

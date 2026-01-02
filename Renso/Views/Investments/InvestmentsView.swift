import SwiftUI
import SwiftData

struct InvestmentsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: InvestmentsViewModel?
    @State private var selectedTab: InvestmentTab = .crypto
    @State private var showAddCrypto = false
    @State private var showAddStock = false

    enum InvestmentTab {
        case crypto, stocks
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                VStack(spacing: 0) {
                    // Tab selector
                    Picker("Type", selection: $selectedTab) {
                        Text("Crypto").tag(InvestmentTab.crypto)
                        Text("Stocks").tag(InvestmentTab.stocks)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Content
                    if selectedTab == .crypto {
                        CryptoList(viewModel: viewModel, showAdd: $showAddCrypto)
                    } else {
                        StocksList(viewModel: viewModel, showAdd: $showAddStock)
                    }
                }
                .navigationTitle("Investments")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if selectedTab == .crypto {
                                showAddCrypto = true
                            } else {
                                showAddStock = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddCrypto) {
                    AddCryptoView()
                        .onDisappear {
                            viewModel.loadHoldings()
                        }
                }
                .sheet(isPresented: $showAddStock) {
                    AddStockView()
                        .onDisappear {
                            viewModel.loadHoldings()
                        }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InvestmentsViewModel(modelContext: modelContext)
            }
        }
    }
}

struct CryptoList: View {
    let viewModel: InvestmentsViewModel
    @Binding var showAdd: Bool

    var body: some View {
        if viewModel.cryptoHoldings.isEmpty {
            EmptyStateView(
                icon: "bitcoinsign.circle",
                title: "No Crypto Holdings",
                message: "Add your first cryptocurrency holding"
            )
        } else {
            List(viewModel.cryptoHoldings) { holding in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(holding.symbol)
                            .font(.headline)
                        Text(holding.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(holding.quantity.formatted()) \(holding.symbol)")
                            .font(.body)
                        if let price = holding.lastPrice {
                            Text(viewModel.getCryptoValue(holding).formatted(.currency(code: viewModel.baseCurrency)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct StocksList: View {
    let viewModel: InvestmentsViewModel
    @Binding var showAdd: Bool

    var body: some View {
        if viewModel.stockHoldings.isEmpty {
            EmptyStateView(
                icon: "chart.line.uptrend.xyaxis",
                title: "No Stock Holdings",
                message: "Add your first stock holding"
            )
        } else {
            List(viewModel.stockHoldings) { holding in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(holding.symbol)
                            .font(.headline)
                        Text(holding.companyName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(holding.quantity.formatted()) shares")
                            .font(.body)
                        if let price = holding.lastPrice {
                            Text(viewModel.getStockValue(holding).formatted(.currency(code: viewModel.baseCurrency)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct AddCryptoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var symbol: String = ""
    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var averagePrice: String = ""
    @State private var currencyCode: String = "USD"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Symbol (e.g., BTC)", text: $symbol)
                    .textInputAutocapitalization(.characters)
                TextField("Name", text: $name)
                TextField("Quantity", text: $quantity)
                    .keyboardType(.decimalPad)
                TextField("Average Price", text: $averagePrice)
                    .keyboardType(.decimalPad)
                Picker("Currency", selection: $currencyCode) {
                    Text("USD").tag("USD")
                    Text("UAH").tag("UAH")
                    Text("EUR").tag("EUR")
                }
            }
            .navigationTitle("Add Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCrypto()
                    }
                    .disabled(symbol.isEmpty || name.isEmpty || quantity.isEmpty || averagePrice.isEmpty)
                }
            }
        }
    }

    private func saveCrypto() {
        let viewModel = InvestmentsViewModel(modelContext: modelContext)
        viewModel.addCryptoHolding(
            symbol: symbol,
            name: name,
            coinmarketcapId: nil,
            quantity: Decimal(string: quantity) ?? 0,
            averagePrice: Decimal(string: averagePrice) ?? 0,
            currencyCode: currencyCode
        )
        dismiss()
    }
}

struct AddStockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var symbol: String = ""
    @State private var companyName: String = ""
    @State private var exchange: String = "NASDAQ"
    @State private var quantity: String = ""
    @State private var averagePrice: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Symbol (e.g., AAPL)", text: $symbol)
                    .textInputAutocapitalization(.characters)
                TextField("Company Name", text: $companyName)
                TextField("Exchange", text: $exchange)
                TextField("Quantity (shares)", text: $quantity)
                    .keyboardType(.decimalPad)
                TextField("Average Price per Share", text: $averagePrice)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveStock()
                    }
                    .disabled(symbol.isEmpty || companyName.isEmpty || quantity.isEmpty || averagePrice.isEmpty)
                }
            }
        }
    }

    private func saveStock() {
        let viewModel = InvestmentsViewModel(modelContext: modelContext)
        viewModel.addStockHolding(
            symbol: symbol,
            companyName: companyName,
            exchange: exchange,
            yahooTicker: symbol,
            quantity: Decimal(string: quantity) ?? 0,
            averagePrice: Decimal(string: averagePrice) ?? 0,
            currencyCode: "USD"
        )
        dismiss()
    }
}

#Preview {
    NavigationStack {
        InvestmentsView()
    }
    .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

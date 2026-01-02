import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel = viewModel {
                List {
                    // Monobank Section
                    Section {
                        NavigationLink {
                            MonobankSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Monobank")
                                        .font(.body)

                                    if viewModel.isMonobankConnected {
                                        if let name = viewModel.monobankClientName {
                                            Text(name)
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        } else {
                                            Text("Connected")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                    } else if viewModel.hasMonobankToken {
                                        Text("Token configured")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Not configured")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Integrations")
                    }

                    // Data Management
                    Section {
                        NavigationLink {
                            WalletsManagementView()
                        } label: {
                            Label("Wallets", systemImage: "wallet.pass.fill")
                        }

                        NavigationLink {
                            InvestmentsManagementView()
                        } label: {
                            Label("Investments", systemImage: "chart.line.uptrend.xyaxis")
                        }

                        NavigationLink {
                            CategoriesManagementView()
                        } label: {
                            Label("Categories", systemImage: "tag.fill")
                        }

                        NavigationLink {
                            RulesManagementView()
                        } label: {
                            Label("Auto-Categorization Rules", systemImage: "wand.and.stars")
                        }
                    } header: {
                        Text("Data Management")
                    }

                    // Preferences
                    Section {
                        NavigationLink {
                            CurrencySettingsView()
                        } label: {
                            HStack {
                                Label("Base Currency", systemImage: "dollarsign.circle.fill")
                                Spacer()
                                Text(viewModel.baseCurrency)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Preferences")
                    }

                    // App Info
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("About")
                    }
                }
                .navigationTitle("Settings")
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(modelContext: modelContext)
            }
        }
    }
}

// MARK: - Monobank Settings

struct MonobankSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                MonobankSettingsContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Monobank")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(modelContext: modelContext)
            }
        }
    }
}

struct MonobankSettingsContent: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        Form {
            // Connection Status Section
            Section {
                HStack {
                    Image(systemName: viewModel.isMonobankConnected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.isMonobankConnected ? .green : .secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isMonobankConnected ? "Connected" : "Not Connected")
                            .font(.body)
                        
                        if let clientName = viewModel.monobankClientName {
                            Text(clientName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.isValidating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                
                if viewModel.isMonobankConnected {
                    HStack {
                        Text("Accounts")
                        Spacer()
                        Text("\(viewModel.monobankAccountsCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(viewModel.lastSyncText)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Connection Status")
            }
            
            // Actions Section
            Section {
                Button {
                    Task {
                        await viewModel.validateMonobankConnection()
                        if viewModel.errorMessage != nil {
                            showError = true
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isValidating {
                            ProgressView()
                                .controlSize(.small)
                            Text("Validating...")
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Validate Connection")
                        }
                    }
                }
                .disabled(viewModel.isValidating || viewModel.isSyncing)
                
                Button {
                    Task {
                        await viewModel.syncWithMonobank()
                        if viewModel.errorMessage != nil {
                            showError = true
                        } else if viewModel.successMessage != nil {
                            showSuccess = true
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Syncing...")
                        } else {
                            Image(systemName: "arrow.down.circle")
                            Text("Sync Now")
                        }
                    }
                }
                .disabled(viewModel.isValidating || viewModel.isSyncing || !viewModel.hasMonobankToken)
            } header: {
                Text("Actions")
            } footer: {
                if viewModel.hasMonobankToken {
                    Text("Token is configured in the app. Sync will fetch your accounts and transactions.")
                } else {
                    Text("⚠️ Token not configured. Add your Monobank token to Secrets.swift")
                }
            }
        }
        .task {
            // Validate connection on appear
            await viewModel.validateMonobankConnection()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                viewModel.successMessage = nil
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
}

// MARK: - Currency Settings

struct CurrencySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var isRefreshing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let exchangeRateService = ExchangeRateService.shared

    var body: some View {
        List {
            Section {
                ForEach(ISO4217.commonCurrencies, id: \.self) { currency in
                    CurrencyRow(
                        currency: currency,
                        isSelected: viewModel?.baseCurrency == currency,
                        onSelect: { selectCurrency(currency) }
                    )
                }
            } header: {
                Text("Common Currencies")
            }

            Section {
                ForEach(ISO4217.allCurrencies.filter { !ISO4217.commonCurrencies.contains($0) }, id: \.self) { currency in
                    CurrencyRow(
                        currency: currency,
                        isSelected: viewModel?.baseCurrency == currency,
                        onSelect: { selectCurrency(currency) }
                    )
                }
            } header: {
                Text("All Currencies")
            }

            Section {
                Button {
                    Task {
                        await refreshRates()
                    }
                } label: {
                    HStack {
                        Label("Update Exchange Rates", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isRefreshing)

                if let lastUpdated = exchangeRateService.lastUpdated {
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(Formatters.smartDate(lastUpdated))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Exchange Rates")
            } footer: {
                Text("Exchange rates are fetched from Monobank and used to convert amounts to your base currency.")
            }
        }
        .navigationTitle("Base Currency")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(modelContext: modelContext)
            }

            // Auto-refresh if rates are old
            if exchangeRateService.needsRefresh() {
                Task {
                    await refreshRates()
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func selectCurrency(_ currency: String) {
        viewModel?.updateBaseCurrency(currency)
    }

    private func refreshRates() async {
        isRefreshing = true

        do {
            try await exchangeRateService.fetchRates()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isRefreshing = false
    }
}

struct CurrencyRow: View {
    let currency: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(ISO4217.symbol(for: currency))
                            .font(.headline)
                            .frame(width: 32, alignment: .leading)

                        Text(currency)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Text(ISO4217.name(for: currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder Views

struct WalletsManagementView: View {
    var body: some View {
        WalletsListView()
    }
}

struct InvestmentsManagementView: View {
    var body: some View {
        InvestmentsView()
    }
}

struct CategoriesManagementView: View {
    var body: some View {
        CategoriesListView()
    }
}

struct RulesManagementView: View {
    var body: some View {
        RulesListView()
    }
}

#Preview {
    SettingsView()
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

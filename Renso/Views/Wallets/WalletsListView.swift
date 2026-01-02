import SwiftUI
import SwiftData

struct WalletsListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WalletsViewModel?
    @State private var showAddWallet = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                List {
                    ForEach(viewModel.wallets) { wallet in
                        WalletRow(wallet: wallet)
                    }
                }
                .navigationTitle("Wallets")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddWallet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddWallet) {
                    AddWalletView()
                        .onDisappear {
                            viewModel.loadWallets()
                        }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = WalletsViewModel(modelContext: modelContext)
            }
        }
    }
}

struct WalletRow: View {
    let wallet: Wallet

    var body: some View {
        HStack {
            Image(systemName: wallet.iconName)
                .font(.title2)
                .foregroundStyle(Color(hex: wallet.colorHex) ?? .blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(wallet.walletType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }

            Spacer()

            Text(wallet.currentBalance.formatted(.currency(code: wallet.currencyCode)))
                .font(.body)
                .fontWeight(.semibold)
        }
    }
}

struct AddWalletView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var walletType: WalletType = .other
    @State private var currencyCode: String = "UAH"
    @State private var initialBalance: String = "0"
    @State private var selectedIcon: String = "wallet.pass"
    @State private var selectedColor: String = "#007AFF"
    @State private var useCustomIcon: Bool = false

    @State private var showError = false
    @State private var errorMessage = ""

    let availableIcons = [
        "wallet.pass", "creditcard", "banknote", "dollarsign.circle", "eurosign.circle",
        "building.columns", "bitcoinsign.circle", "chart.line.uptrend.xyaxis"
    ]
    let availableColors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#5856D6", "#AF52DE"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wallet Name", text: $name)

                    Picker("Type", selection: $walletType) {
                        ForEach(WalletType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.defaultIcon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }

                    Picker("Currency", selection: $currencyCode) {
                        Text("UAH").tag("UAH")
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                    }

                    TextField("Initial Balance", text: $initialBalance)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Basic Info")
                }

                Section {
                    Toggle("Use Custom Icon", isOn: $useCustomIcon)

                    if useCustomIcon {
                        Picker("Icon", selection: $selectedIcon) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Label(icon, systemImage: icon)
                            }
                        }
                    } else {
                        HStack {
                            Text("Default Icon")
                            Spacer()
                            Image(systemName: walletType.defaultIcon)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Color")
                        Spacer()
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color) ?? .blue)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                } header: {
                    Text("Appearance")
                }
            }
            .navigationTitle("New Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWallet()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveWallet() {
        let balance = Decimal(string: initialBalance) ?? 0

        let wallet = Wallet(
            name: name,
            currencyCode: currencyCode,
            initialBalance: balance,
            walletType: walletType,
            iconName: useCustomIcon ? selectedIcon : nil,
            colorHex: selectedColor
        )

        modelContext.insert(wallet)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        WalletsListView()
    }
    .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

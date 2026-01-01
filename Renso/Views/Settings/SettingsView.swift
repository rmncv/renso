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

                                    if viewModel.hasMonobankToken {
                                        Text("Connected")
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
                        HStack {
                            Label("Base Currency", systemImage: "dollarsign.circle.fill")
                            Spacer()
                            Text(viewModel.baseCurrency)
                                .foregroundStyle(.secondary)
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
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var isSyncing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section {
                SecureField("Monobank API Token", text: $token)
                    .textContentType(.password)

                Button {
                    Task {
                        await syncMonobank()
                    }
                } label: {
                    if isSyncing {
                        HStack {
                            ProgressView()
                            Text("Syncing...")
                        }
                    } else {
                        Text("Connect & Sync")
                    }
                }
                .disabled(token.isEmpty || isSyncing)
            } header: {
                Text("API Token")
            } footer: {
                Text("Get your token from Monobank app: Profile → API → Get token")
            }
        }
        .navigationTitle("Monobank")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sync Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func syncMonobank() async {
        isSyncing = true

        do {
            let service = MonobankSyncService(modelContext: modelContext, token: token)
            _ = try await service.performFullSync()

            // Save token in settings
            let descriptor = FetchDescriptor<UserSettings>()
            if let settings = try? modelContext.fetch(descriptor).first {
                settings.hasMonobankToken = true
                try? modelContext.save()
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSyncing = false
    }
}

// MARK: - Placeholder Views

struct WalletsManagementView: View {
    var body: some View {
        Text("Wallets Management")
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct InvestmentsManagementView: View {
    var body: some View {
        Text("Investments Management")
            .navigationTitle("Investments")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoriesManagementView: View {
    var body: some View {
        Text("Categories Management")
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct RulesManagementView: View {
    var body: some View {
        Text("Rules Management")
            .navigationTitle("Rules")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

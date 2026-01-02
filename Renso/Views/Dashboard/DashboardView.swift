import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.denysrumiantsev.Renso", category: "DashboardView")

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NavigationRouter.self) private var router
    @State private var viewModel: DashboardViewModel?
    @State private var isInitialLoad = true
    @State private var showAddTransaction = false
    @State private var selectedTransaction: Transaction?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    ScrollView {
                        VStack(spacing: 20) {
                            NetWorthCard(viewModel: viewModel)
                            
                            if viewModel.uncategorizedCountThisMonth > 0 {
                                UncategorizedTransactionsCard(count: viewModel.uncategorizedCountThisMonth) {
                                    router.navigateToUncategorizedTransactions()
                                }
                            }

                            if viewModel.hasInvestments {
                                InvestmentsOverviewCard(viewModel: viewModel)
                            }

                            RecentTransactionsSection(
                                transactions: viewModel.recentTransactions,
                                isLoading: viewModel.isLoadingTransactions,
                                onTransactionTap: { transaction in
                                    selectedTransaction = transaction
                                }
                            )
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                } else {
                    LoadingView("Loading dashboard...")
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if let viewModel = viewModel {
                        Button {
                            Task {
                                await viewModel.refreshPrices()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isRefreshingPrices)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionFormView(transaction: nil)
                    .onDisappear {
                        Task {
                            await viewModel?.refresh()
                        }
                    }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionFormView(transaction: transaction)
                    .onDisappear {
                        Task {
                            await viewModel?.refresh()
                        }
                    }
            }
            .onAppear {
                logger.info("📱 DashboardView onAppear (isInitialLoad: \(self.isInitialLoad))")
                
                if viewModel == nil {
                    logger.info("🆕 Creating DashboardViewModel")
                    viewModel = DashboardViewModel(modelContext: modelContext)
                    isInitialLoad = true
                } else if !isInitialLoad {
                    // Refresh when returning to the view (e.g., from Settings)
                    logger.info("🔄 Refreshing dashboard data")
                    Task {
                        await viewModel?.refresh()
                    }
                }
                isInitialLoad = false
                
                // Trigger Monobank sync if needed (throttled to 30 seconds)
                logger.info("🏦 Checking if Monobank sync needed...")
                viewModel?.triggerMonobankSyncIfNeeded()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Refresh when app becomes active again
                if newPhase == .active, let viewModel = viewModel {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

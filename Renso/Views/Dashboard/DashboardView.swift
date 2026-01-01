import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    ScrollView {
                        VStack(spacing: 20) {
                            NetWorthCard(viewModel: viewModel)

                            if viewModel.hasInvestments {
                                InvestmentsOverviewCard(viewModel: viewModel)
                            }

                            RecentTransactionsSection(
                                transactions: viewModel.recentTransactions,
                                isLoading: viewModel.isLoadingTransactions
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
            .onAppear {
                if viewModel == nil {
                    viewModel = DashboardViewModel(modelContext: modelContext)
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

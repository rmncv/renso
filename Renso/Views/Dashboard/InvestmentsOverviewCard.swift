import SwiftUI

struct InvestmentsOverviewCard: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.green)

                    Text("Investments")
                        .font(.headline)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let netWorth = viewModel.netWorth {
                    HStack(spacing: 20) {
                        if viewModel.cryptoHoldingsCount > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Crypto")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("\(viewModel.cryptoHoldingsCount)")
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text(Formatters.currency(netWorth.cryptoValue, currencyCode: viewModel.baseCurrency))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if viewModel.stockHoldingsCount > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Stocks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("\(viewModel.stockHoldingsCount)")
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text(Formatters.currency(netWorth.stocksValue, currencyCode: viewModel.baseCurrency))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    InvestmentsOverviewCard(
        viewModel: DashboardViewModel(
            modelContext: try! ModelContainerSetup.createPreviewContainer().mainContext
        )
    )
    .padding()
}

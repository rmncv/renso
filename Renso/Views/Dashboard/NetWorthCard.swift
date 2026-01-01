import SwiftUI

struct NetWorthCard: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Worth")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if viewModel.isLoadingNetWorth {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(viewModel.totalNetWorthFormatted)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                    }

                    Spacer()

                    Image(systemName: "chart.pie.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }

                if let netWorth = viewModel.netWorth, !viewModel.isLoadingNetWorth {
                    Divider()

                    VStack(spacing: 12) {
                        BreakdownRow(
                            icon: "wallet.pass.fill",
                            title: "Wallets",
                            amount: netWorth.walletsValue,
                            percentage: netWorth.walletsPercentage,
                            currencyCode: viewModel.baseCurrency,
                            color: .blue
                        )

                        if netWorth.cryptoValue > 0 {
                            BreakdownRow(
                                icon: "bitcoinsign.circle.fill",
                                title: "Crypto",
                                amount: netWorth.cryptoValue,
                                percentage: netWorth.cryptoPercentage,
                                currencyCode: viewModel.baseCurrency,
                                color: .orange
                            )
                        }

                        if netWorth.stocksValue > 0 {
                            BreakdownRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Stocks",
                                amount: netWorth.stocksValue,
                                percentage: netWorth.stocksPercentage,
                                currencyCode: viewModel.baseCurrency,
                                color: .green
                            )
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

struct BreakdownRow: View {
    let icon: String
    let title: String
    let amount: Decimal
    let percentage: Double
    let currencyCode: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.currency(amount, currencyCode: currencyCode))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(String(format: "%.1f%%", percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NetWorthCard(
        viewModel: DashboardViewModel(
            modelContext: try! ModelContainerSetup.createPreviewContainer().mainContext
        )
    )
    .padding()
}

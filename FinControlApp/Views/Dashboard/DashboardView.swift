import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPrivacyHidden: Bool
    @State private var viewModel = DashboardViewModel()
    @State private var selectionTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthAndPrivacyHeader

                    if let snapshot = viewModel.snapshot {
                        bentoSummaryGrid(snapshot)

                        InteractiveChartsView(
                            categorySpendings: snapshot.categorySpendings,
                            invoicePoints: snapshot.invoiceCompositionPoints,
                            isPrivacyHidden: isPrivacyHidden
                        )

                        budgetThermometerCard(snapshot.categorySpendings)
                    } else if viewModel.isLoading {
                        ProgressView("Calculando resumo financeiro...")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FinControl Pro")
            .navigationBarTitleDisplayMode(.large)
            .sensoryFeedback(.selection, trigger: selectionTrigger)
            .onAppear {
                viewModel.isPrivacyHidden = isPrivacyHidden
                viewModel.configure(container: modelContext.container)
            }
            .onReceive(NotificationCenter.default.publisher(for: .finControlDataDidChange)) { _ in
                Task { await viewModel.load() }
            }
        }
    }

    private var monthAndPrivacyHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    selectionTrigger.toggle()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        viewModel.shiftMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Text(Formatters.monthYearTitle(month: viewModel.selectedMonth, year: viewModel.selectedYear))
                    .font(.headline.weight(.semibold))
                    .contentTransition(.numericText())
                    .frame(minWidth: 130)

                Button {
                    selectionTrigger.toggle()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        viewModel.shiftMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            Spacer()

            Button {
                selectionTrigger.toggle()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    isPrivacyHidden.toggle()
                    viewModel.isPrivacyHidden = isPrivacyHidden
                }
            } label: {
                Image(systemName: isPrivacyHidden ? "eye.slash.fill" : "eye.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(isPrivacyHidden ? .orange : .primary)
            }
            .accessibilityLabel(isPrivacyHidden ? "Mostrar valores" : "Ocultar valores")
        }
    }

    private func bentoSummaryGrid(_ snapshot: DashboardSnapshot) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Card 1: Saldo Total em Contas
                GlassCardView(cornerRadius: 20, padding: 14, tintColor: .blue) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Saldo em Contas", systemImage: "building.columns.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        AnimatedCurrencyText(
                            value: snapshot.totalAccountsBalance,
                            font: .system(.title3, design: .rounded, weight: .bold),
                            isPrivacyHidden: isPrivacyHidden
                        )

                        Text("Receita pessoal: \(Formatters.currency(snapshot.monthlyPersonalIncome))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .redacted(reason: isPrivacyHidden ? .placeholder : [])
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Card 2: Patrimônio Investido + Rentabilidade (%)
                GlassCardView(cornerRadius: 20, padding: 14, tintColor: .green) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Investimentos", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        AnimatedCurrencyText(
                            value: snapshot.totalInvestmentsCurrentBalance,
                            font: .system(.title3, design: .rounded, weight: .bold),
                            isPrivacyHidden: isPrivacyHidden
                        )

                        Text(Formatters.percentage(snapshot.investmentReturnPercentage))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(snapshot.investmentReturnPercentage >= 0 ? .green : .red)
                            .redacted(reason: isPrivacyHidden ? .placeholder : [])
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Card 3: Fatura do Mês (Meu Gasto Real + A Receber de Terceiros)
            GlassCardView(cornerRadius: 20, padding: 16, tintColor: .indigo) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Fatura do Mês • Meu Gasto Real", systemImage: "creditcard.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        AnimatedCurrencyText(
                            value: snapshot.monthlyPersonalCardCost,
                            font: .system(.title2, design: .rounded, weight: .bold),
                            isPrivacyHidden: isPrivacyHidden
                        )

                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.left.circle.fill")
                                .foregroundStyle(.green)
                            Text("A Receber de Terceiros:")
                                .foregroundStyle(.secondary)
                            AnimatedCurrencyText(
                                value: snapshot.monthlyThirdPartyReceivable,
                                font: .system(.caption, design: .rounded, weight: .bold),
                                color: .green,
                                isPrivacyHidden: isPrivacyHidden
                            )
                        }
                        .font(.caption)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Fatura Bruta")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        AnimatedCurrencyText(
                            value: snapshot.monthlyGrossInvoiceTotal,
                            font: .system(.subheadline, design: .rounded, weight: .semibold),
                            color: .secondary,
                            isPrivacyHidden: isPrivacyHidden
                        )
                    }
                }
            }
        }
    }

    private func budgetThermometerCard(_ categories: [CategorySpendingSummary]) -> some View {
        let budgeted = categories.filter { ($0.budget ?? 0) > 0 }

        return GlassCardView(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Termômetro de Metas", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Apenas gastos próprios")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if budgeted.isEmpty {
                    Text("Nenhuma categoria com teto mensal definido.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(budgeted) { item in
                        let budget = item.budget ?? 1
                        let ratio = min(max(item.spent / budget, 0), 1)
                        let barColor = alertColor(for: item.alertLevel, fallbackHex: item.colorHex)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(item.name, systemImage: item.iconName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(hex: item.colorHex))

                                Spacer()

                                Text("\(Int(item.percentage.rounded()))%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(barColor)

                                Text("(\(Formatters.currency(item.spent)) / \(Formatters.currency(budget)))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .redacted(reason: isPrivacyHidden ? .placeholder : [])
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.18))
                                    Capsule()
                                        .fill(barColor.gradient)
                                        .frame(width: geo.size.width * ratio)
                                        .animation(.spring(duration: 0.35, bounce: 0.15), value: ratio)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
    }

    private func alertColor(for level: BudgetAlertLevel, fallbackHex: String) -> Color {
        switch level {
        case .normal: return Color(hex: fallbackHex)
        case .warning80: return .yellow
        case .critical100: return .red
        }
    }
}

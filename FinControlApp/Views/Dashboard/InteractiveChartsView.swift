import SwiftUI
import Charts

enum DashboardChartMode: String, CaseIterable, Sendable {
    case expensesByCategory = "Gastos por Categoria"
    case invoiceComposition = "Composição da Fatura"
}

struct InteractiveChartsView: View {
    let categorySpendings: [CategorySpendingSummary]
    let invoicePoints: [InvoiceCompositionPoint]
    var isPrivacyHidden: Bool = false

    @State private var mode: DashboardChartMode = .expensesByCategory
    @State private var selectedAngleValue: Double?
    @State private var selectedCardName: String?
    @State private var selectionTrigger = false

    private var totalCategorySpending: Double {
        categorySpendings.reduce(0.0) { $0 + $1.spent }
    }

    private var selectedCategory: CategorySpendingSummary? {
        guard let selectedAngleValue else { return nil }
        var cumulative = 0.0
        for item in categorySpendings where item.spent > 0 {
            cumulative += item.spent
            if selectedAngleValue <= cumulative {
                return item
            }
        }
        return nil
    }

    private var selectedCardSummary: (card: String, own: Double, third: Double, prepaid: Double)? {
        guard let selectedCardName else { return nil }
        let cardPoints = invoicePoints.filter { $0.cardName == selectedCardName }
        guard !cardPoints.isEmpty else { return nil }
        let own = cardPoints.first(where: { $0.segment == "Meus Gastos" })?.amount ?? 0
        let third = cardPoints.first(where: { $0.segment == "Terceiros" })?.amount ?? 0
        let prepaid = cardPoints.first(where: { $0.segment == "Abatimentos" })?.amount ?? 0
        return (selectedCardName, own, third, prepaid)
    }

    var body: some View {
        GlassCardView(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Tipo de Gráfico", selection: $mode.animation(.spring(duration: 0.35, bounce: 0.15))) {
                    ForEach(DashboardChartMode.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in
                    selectionTrigger.toggle()
                    selectedAngleValue = nil
                    selectedCardName = nil
                }

                if mode == .expensesByCategory {
                    categoryDonutSection
                } else {
                    invoiceStackedBarSection
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionTrigger)
    }

    // MARK: - SectorMark (Gastos Reais por Categoria)

    private var categoryDonutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCategory?.name ?? "Total de Gastos Reais")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    AnimatedCurrencyText(
                        value: selectedCategory?.spent ?? totalCategorySpending,
                        font: .system(.title2, design: .rounded, weight: .bold),
                        isPrivacyHidden: isPrivacyHidden
                    )
                }
                Spacer()
                if let selectedCategory, totalCategorySpending > 0 {
                    let share = (selectedCategory.spent / totalCategorySpending) * 100.0
                    Text("\(Int(share.rounded()))% do mês")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: selectedCategory.colorHex).opacity(0.18), in: Capsule())
                        .foregroundStyle(Color(hex: selectedCategory.colorHex))
                }
            }

            let chartItems = categorySpendings.filter { $0.spent > 0 }
            if chartItems.isEmpty {
                emptyChartPlaceholder(text: "Sem gastos próprios registrados neste mês.")
            } else {
                Chart(chartItems) { item in
                    SectorMark(
                        angle: .value("Valor", item.spent),
                        innerRadius: .ratio(0.62),
                        outerRadius: selectedCategory?.id == item.id ? .ratio(1.0) : .ratio(0.92),
                        angularInset: 2
                    )
                    .cornerRadius(6)
                    .foregroundStyle(Color(hex: item.colorHex))
                    .opacity(selectedCategory == nil || selectedCategory?.id == item.id ? 1.0 : 0.45)
                }
                .chartAngleSelection(value: $selectedAngleValue)
                .onChange(of: selectedAngleValue) { _, newValue in
                    if newValue != nil {
                        selectionTrigger.toggle()
                    }
                }
                .frame(height: 220)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 6) {
                    ForEach(chartItems) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: item.colorHex))
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - BarMark (Composição da Fatura)

    private var invoiceStackedBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = selectedCardSummary {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.card)
                        .font(.subheadline.weight(.bold))
                    HStack(spacing: 12) {
                        Label("Meus: \(Formatters.currency(summary.own))", systemImage: "circle.fill")
                            .foregroundStyle(.blue)
                        Label("Terceiros: \(Formatters.currency(summary.third))", systemImage: "circle.fill")
                            .foregroundStyle(.orange)
                        if summary.prepaid > 0 {
                            Label("Abatido: \(Formatters.currency(summary.prepaid))", systemImage: "circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                }
            } else {
                Text("Deslize sobre as barras para inspecionar cada cartão")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if invoicePoints.isEmpty {
                emptyChartPlaceholder(text: "Nenhuma movimentação de cartão neste mês.")
            } else {
                Chart(invoicePoints) { point in
                    BarMark(
                        x: .value("Cartão", point.cardName),
                        y: .value("Valor", point.amount)
                    )
                    .foregroundStyle(by: .value("Segmento", point.segment))
                    .cornerRadius(6)
                }
                .chartForegroundStyleScale([
                    "Meus Gastos": Color(hex: "#0A84FF"),
                    "Terceiros": Color(hex: "#FF9F0A"),
                    "Abatimentos": Color(hex: "#30D158")
                ])
                .chartXSelection(value: $selectedCardName)
                .onChange(of: selectedCardName) { _, newValue in
                    if newValue != nil {
                        selectionTrigger.toggle()
                    }
                }
                .frame(height: 220)
            }
        }
    }

    private func emptyChartPlaceholder(text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }
}

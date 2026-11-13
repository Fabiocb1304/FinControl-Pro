import SwiftUI
import SwiftData
import Charts

struct InvestmentsPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var viewModel = InvestmentViewModel()

    @State private var selectedAngleValue: Double?
    @State private var showNewContributionSheet = false
    @State private var selectedInvestmentForContribution: InvestmentDTO?
    @State private var editingBalanceInvestment: InvestmentDTO?
    @State private var selectionTrigger = false

    var isPrivacyHidden: Bool = false

    private var selectedAllocationSlice: AssetAllocationSlice? {
        guard let selectedAngleValue,
              let slices = viewModel.portfolio?.allocations else { return nil }
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.totalValue
            if selectedAngleValue <= cumulative {
                return slice
            }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let portfolio = viewModel.portfolio {
                        consolidatedSummaryCard(portfolio)

                        allocationChartCard(portfolio)

                        assetsGroupedList(portfolio)
                    } else if viewModel.isLoading {
                        ProgressView("Carregando carteira...")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Investimentos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedInvestmentForContribution = nil
                        showNewContributionSheet = true
                    } label: {
                        Label("Novo Aporte", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectionTrigger)
            .sensoryFeedback(.success, trigger: viewModel.actionSuccessTrigger)
            .onAppear {
                viewModel.configure(container: modelContext.container)
            }
            .onReceive(NotificationCenter.default.publisher(for: .finControlDataDidChange)) { _ in
                Task { await viewModel.load() }
            }
            .sheet(isPresented: $showNewContributionSheet) {
                NewContributionSheet(
                    existingInvestment: selectedInvestmentForContribution,
                    accounts: accounts
                ) { name, assetClass, institution, amount, debitAccountID in
                    Task {
                        await viewModel.addContribution(
                            investmentID: selectedInvestmentForContribution?.persistentID,
                            name: name,
                            assetClass: assetClass,
                            institution: institution,
                            amount: amount,
                            debitAccountID: debitAccountID
                        )
                    }
                }
            }
            .sheet(item: $editingBalanceInvestment) { investment in
                UpdateInvestmentBalanceSheet(investment: investment) { newBalance in
                    Task {
                        await viewModel.updateBalance(
                            investmentID: investment.persistentID,
                            newBalance: newBalance
                        )
                    }
                }
            }
        }
    }

    private func consolidatedSummaryCard(_ portfolio: InvestmentPortfolioSnapshot) -> some View {
        let isPositive = portfolio.profitAmount >= 0

        return GlassCardView(cornerRadius: 20, padding: 18, tintColor: isPositive ? .green : .red) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Patrimônio Total Investido")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                AnimatedCurrencyText(
                    value: portfolio.totalCurrentBalance,
                    font: .system(size: 32, weight: .bold, design: .rounded),
                    isPrivacyHidden: isPrivacyHidden
                )

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Valor Aplicado")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        AnimatedCurrencyText(
                            value: portfolio.totalInvested,
                            font: .system(.subheadline, design: .rounded, weight: .semibold),
                            color: .secondary,
                            isPrivacyHidden: isPrivacyHidden
                        )
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lucro / Prejuízo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            AnimatedCurrencyText(
                                value: portfolio.profitAmount,
                                font: .system(.subheadline, design: .rounded, weight: .bold),
                                color: isPositive ? .green : .red,
                                isPrivacyHidden: isPrivacyHidden,
                                showSign: true
                            )
                            Text("(\(Formatters.percentage(portfolio.profitPercentage)))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isPositive ? .green : .red)
                                .redacted(reason: isPrivacyHidden ? .placeholder : [])
                        }
                    }
                }
            }
        }
    }

    private func allocationChartCard(_ portfolio: InvestmentPortfolioSnapshot) -> some View {
        GlassCardView(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedAllocationSlice?.assetClass.localizedTitle ?? "Alocação por Classe")
                            .font(.headline.weight(.bold))
                        if let slice = selectedAllocationSlice {
                            Text("\(Formatters.currency(slice.totalValue)) (\(Int(slice.percentage.rounded()))%)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: slice.assetClass.colorHex))
                                .redacted(reason: isPrivacyHidden ? .placeholder : [])
                        } else {
                            Text("Toque ou deslize nas fatias")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                if portfolio.allocations.isEmpty {
                    Text("Adicione ativos para visualizar a alocação.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Chart(portfolio.allocations) { slice in
                        SectorMark(
                            angle: .value("Valor", slice.totalValue),
                            innerRadius: .ratio(0.60),
                            outerRadius: selectedAllocationSlice?.id == slice.id ? .ratio(1.0) : .ratio(0.92),
                            angularInset: 2
                        )
                        .cornerRadius(6)
                        .foregroundStyle(Color(hex: slice.assetClass.colorHex))
                    }
                    .chartAngleSelection(value: $selectedAngleValue)
                    .onChange(of: selectedAngleValue) { _, newValue in
                        if newValue != nil {
                            selectionTrigger.toggle()
                        }
                    }
                    .frame(height: 200)

                    HStack(spacing: 12) {
                        ForEach(portfolio.allocations) { slice in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: slice.assetClass.colorHex))
                                    .frame(width: 8, height: 8)
                                Text("\(slice.assetClass.localizedTitle) \(Int(slice.percentage.rounded()))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func assetsGroupedList(_ portfolio: InvestmentPortfolioSnapshot) -> some View {
        let grouped = Dictionary(grouping: portfolio.investments) { $0.assetClass }

        return LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(AssetClass.allCases, id: \.self) { assetClass in
                if let items = grouped[assetClass], !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(assetClass.localizedTitle, systemImage: assetClass.systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(hex: assetClass.colorHex))
                            .padding(.horizontal, 4)

                        ForEach(items) { asset in
                            GlassCardView(cornerRadius: 18, padding: 14) {
                                VStack(spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(asset.name)
                                                .font(.subheadline.weight(.bold))
                                            Text(asset.institution)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            AnimatedCurrencyText(
                                                value: asset.currentBalance,
                                                font: .system(.headline, design: .rounded, weight: .bold),
                                                isPrivacyHidden: isPrivacyHidden
                                            )
                                            Text(Formatters.percentage(asset.profitPercentage))
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(asset.profitAmount >= 0 ? .green : .red)
                                                .redacted(reason: isPrivacyHidden ? .placeholder : [])
                                        }
                                    }

                                    HStack(spacing: 10) {
                                        Button {
                                            selectedInvestmentForContribution = asset
                                            showNewContributionSheet = true
                                        } label: {
                                            Label("Novo Aporte", systemImage: "plus.circle")
                                                .font(.caption.weight(.semibold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            editingBalanceInvestment = asset
                                        } label: {
                                            Label("Atualizar Saldo", systemImage: "arrow.triangle.2.circlepath")
                                                .font(.caption.weight(.semibold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct NewContributionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingInvestment: InvestmentDTO?
    let accounts: [Account]
    let onSave: (String, AssetClass, String, Double, PersistentIdentifier?) -> Void

    @State private var name: String = ""
    @State private var assetClass: AssetClass = .fixedIncome
    @State private var institution: String = ""
    @State private var amountText: String = ""
    @State private var shouldDebitAccount: Bool = true
    @State private var selectedAccountID: PersistentIdentifier?

    private var parsedAmount: Double {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0.0
    }

    var body: some View {
        NavigationStack {
            Form {
                if existingInvestment == nil {
                    Section("Novo Ativo") {
                        TextField("Nome (ex: Tesouro Selic, IVVB11)", text: $name)
                        Picker("Classe", selection: $assetClass) {
                            ForEach(AssetClass.allCases, id: \.self) { item in
                                Text(item.localizedTitle).tag(item)
                            }
                        }
                        TextField("Corretora / Instituição", text: $institution)
                    }
                } else if let existing = existingInvestment {
                    Section("Ativo") {
                        Text(existing.name).fontWeight(.semibold)
                        Text(existing.institution).foregroundStyle(.secondary)
                    }
                }

                Section("Valor do Aporte") {
                    TextField("Valor (R$)", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Origem do Recurso") {
                    Toggle("Debitar automaticamente de uma conta", isOn: $shouldDebitAccount)
                    if shouldDebitAccount {
                        Picker("Conta", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                Text("\(account.name) (\(Formatters.currency(account.currentBalance)))")
                                    .tag(Optional(account.persistentModelID))
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingInvestment == nil ? "Novo Aporte" : "Aportar em \(existingInvestment?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        let finalName = existingInvestment?.name ?? name
                        let finalClass = existingInvestment?.assetClass ?? assetClass
                        let finalInst = existingInvestment?.institution ?? institution
                        onSave(
                            finalName,
                            finalClass,
                            finalInst,
                            parsedAmount,
                            shouldDebitAccount ? selectedAccountID : nil
                        )
                        dismiss()
                    }
                    .disabled(parsedAmount <= 0 || (existingInvestment == nil && name.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
            .onAppear {
                selectedAccountID = accounts.first?.persistentModelID
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct UpdateInvestmentBalanceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let investment: InvestmentDTO
    let onSave: (Double) -> Void

    @State private var balanceText: String = ""

    private var parsedBalance: Double? {
        let normalized = balanceText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(investment.name) {
                    HStack {
                        Text("Saldo Anterior")
                        Spacer()
                        Text(Formatters.currency(investment.currentBalance))
                            .foregroundStyle(.secondary)
                    }
                    TextField("Novo Saldo Atual (R$)", text: $balanceText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Atualizar Saldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        if let value = parsedBalance {
                            onSave(value)
                        }
                        dismiss()
                    }
                    .disabled(parsedBalance == nil)
                }
            }
            .onAppear {
                balanceText = String(format: "%.2f", investment.currentBalance)
            }
        }
        .presentationDetents([.medium])
    }
}

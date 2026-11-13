import SwiftUI
import SwiftData

struct InvoiceDetailView: View {
    let card: CardMetrics
    @Bindable var viewModel: CreditCardViewModel
    let namespace: Namespace.ID
    var isPrivacyHidden: Bool = false
    let onClose: () -> Void

    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var settlingSingleTx: TransactionDTO?
    @State private var showPayInvoiceSheet: Bool = false
    @State private var paymentAccountID: PersistentIdentifier?
    @State private var selectionTrigger: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardHeroHeader

                if let detail = viewModel.invoiceDetail {
                    invoiceThreeIndicators(detail)

                    Picker("Filtro", selection: $viewModel.selectedFilter.animation(.spring(duration: 0.35, bounce: 0.15))) {
                        ForEach(InvoiceFilterTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedFilter) { _, _ in
                        selectionTrigger.toggle()
                    }

                    filteredContent(detail)
                } else {
                    ProgressView("Carregando fatura...")
                        .padding(.top, 32)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .sensoryFeedback(.success, trigger: viewModel.settlementSuccessTrigger)
        .task {
            await viewModel.loadInvoiceDetail(for: card.cardID)
        }
        .sheet(item: $settlingSingleTx) { tx in
            SettlementActionSheet(
                title: "Receber / Abater Parcela",
                amount: tx.amount,
                accounts: accounts
            ) { type, accountID in
                Task {
                    await viewModel.settleTransaction(
                        transactionID: tx.persistentID,
                        type: type,
                        destinationAccountID: accountID
                    )
                }
            }
        }
        .sheet(isPresented: $showPayInvoiceSheet) {
            payInvoiceSheet
        }
    }

    private var cardHeroHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Fatura de \(Formatters.monthYearTitle(month: viewModel.selectedMonth, year: viewModel.selectedYear))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        onClose()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            HStack {
                Label("Fecha dia \(card.closingDay)", systemImage: "calendar")
                Spacer()
                Label("Vence dia \(card.dueDay)", systemImage: "clock")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: card.colorHex), Color(hex: card.colorHex).opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .matchedGeometryEffect(id: "card-\(card.uuid.uuidString)", in: namespace)
    }

    private func invoiceThreeIndicators(_ detail: InvoiceDetailSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                GlassCardView(cornerRadius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fatura Bruta")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        AnimatedCurrencyText(
                            value: detail.grossTotal,
                            font: .system(.headline, design: .rounded, weight: .bold),
                            isPrivacyHidden: isPrivacyHidden
                        )
                        Text("Total do banco")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCardView(cornerRadius: 18, padding: 14, tintColor: .blue) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meu Custo Real")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                        AnimatedCurrencyText(
                            value: detail.ownTotal,
                            font: .system(.headline, design: .rounded, weight: .bold),
                            color: .blue,
                            isPrivacyHidden: isPrivacyHidden
                        )
                        Text("Impacto no orçamento")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GlassCardView(cornerRadius: 18, padding: 14, tintColor: .green) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Saldo Líquido a Pagar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(detail.status.localizedTitle)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                        AnimatedCurrencyText(
                            value: detail.netPayable,
                            font: .system(.title3, design: .rounded, weight: .bold),
                            isPrivacyHidden: isPrivacyHidden
                        )
                        if detail.prepaidAmount > 0 {
                            Text("Já abatido antecipadamente: \(Formatters.currency(detail.prepaidAmount))")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    if detail.status != .paid && detail.netPayable > 0 {
                        Button {
                            paymentAccountID = accounts.first?.persistentModelID
                            showPayInvoiceSheet = true
                        } label: {
                            Text("Pagar Fatura")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func filteredContent(_ detail: InvoiceDetailSnapshot) -> some View {
        switch viewModel.selectedFilter {
        case .overview:
            transactionsLazyList(detail.allTransactions, detail: detail)
        case .myExpenses:
            transactionsLazyList(detail.ownTransactions, detail: detail)
        case .thirdPartyByPerson:
            ThirdPartyLoansView(
                summaries: detail.borrowerSummaries,
                isPrivacyHidden: isPrivacyHidden
            ) { summary, type, accountID in
                Task {
                    await viewModel.settleBorrowerMonthly(
                        borrowerID: summary.borrowerID,
                        invoiceID: summary.invoiceID,
                        amount: summary.pendingAmount > 0.01 ? summary.pendingAmount : summary.totalDue,
                        type: type,
                        destinationAccountID: accountID
                    )
                }
            }
        }
    }

    private func transactionsLazyList(_ items: [TransactionDTO], detail: InvoiceDetailSnapshot) -> some View {
        LazyVStack(spacing: 10) {
            if items.isEmpty {
                GlassCardView(cornerRadius: 18, padding: 24) {
                    Text("Nenhuma compra registrada nesta visão.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(items) { tx in
                    let chargeText: String? = tx.isThirdParty ? Formatters.whatsAppChargeMessage(
                        borrowerName: tx.borrowerName ?? "Amigo(a)",
                        cardName: detail.cardName,
                        month: detail.month,
                        year: detail.year,
                        items: [(tx.title, tx.installmentBadge, tx.amount)],
                        pendingAmount: tx.amount
                    ) : nil

                    SwipeableTransactionRow(
                        transaction: tx,
                        isPrivacyHidden: isPrivacyHidden,
                        onSettleTapped: tx.isThirdParty && !tx.isPaidOrSettled ? {
                            settlingSingleTx = tx
                        } : nil,
                        whatsAppChargeText: chargeText
                    )
                }
            }
        }
    }

    private var payInvoiceSheet: some View {
        NavigationStack {
            Form {
                if let detail = viewModel.invoiceDetail {
                    Section {
                        HStack {
                            Text("Saldo líquido")
                            Spacer()
                            AnimatedCurrencyText(
                                value: detail.netPayable,
                                font: .system(.headline, design: .rounded, weight: .bold)
                            )
                        }
                    }
                    Section("Debitar de qual conta?") {
                        Picker("Conta", selection: $paymentAccountID) {
                            Text("Apenas marcar como paga").tag(Optional<PersistentIdentifier>.none)
                            ForEach(accounts) { account in
                                Text("\(account.name) (\(Formatters.currency(account.currentBalance)))")
                                    .tag(Optional(account.persistentModelID))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pagar Fatura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showPayInvoiceSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        if let invoiceID = viewModel.invoiceDetail?.invoiceID {
                            Task {
                                await viewModel.payInvoice(invoiceID: invoiceID, accountID: paymentAccountID)
                            }
                        }
                        showPayInvoiceSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

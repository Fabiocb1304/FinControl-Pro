import SwiftUI
import SwiftData

/// Displays third-party credit card loans grouped by `Borrower`, with matchedGeometryEffect
/// expansion, quick settlement ("Abater Valor") and WhatsApp formatted summary sharing.
struct ThirdPartyLoansView: View {
    let summaries: [BorrowerMonthlySummary]
    var isPrivacyHidden: Bool = false
    let onSettle: (BorrowerMonthlySummary, SettlementType, PersistentIdentifier?) -> Void

    @Query(sort: \Account.name) private var accounts: [Account]
    @Namespace private var borrowerNamespace
    @State private var expandedBorrowerKey: String?
    @State private var settlingSummary: BorrowerMonthlySummary?
    @State private var selectionTrigger = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        LazyVStack(spacing: 12) {
            if summaries.isEmpty {
                GlassCardView(cornerRadius: 20, padding: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Nenhum gasto de terceiro neste período")
                            .font(.subheadline.weight(.semibold))
                        Text("Quando você emprestar seu cartão, o controle por pessoa aparecerá aqui.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(summaries) { summary in
                    borrowerCard(summary)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .sheet(item: $settlingSummary) { summary in
            SettlementActionSheet(
                title: "Baixa de \(summary.borrowerName)",
                amount: summary.pendingAmount > 0 ? summary.pendingAmount : summary.totalDue,
                accounts: accounts
            ) { type, accountID in
                onSettle(summary, type, accountID)
            }
        }
    }

    @ViewBuilder
    private func borrowerCard(_ summary: BorrowerMonthlySummary) -> some View {
        let isExpanded = expandedBorrowerKey == summary.id
        let chargeText = whatsAppSummary(for: summary)

        GlassCardView(cornerRadius: 20, padding: 14, tintColor: statusColor(summary.status)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: summary.avatarColorHex).opacity(0.2))
                            .frame(width: 44, height: 44)
                        Text(initials(summary.borrowerName))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(hex: summary.avatarColorHex))
                    }
                    .matchedGeometryEffect(id: "avatar-\(summary.id)", in: borrowerNamespace)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(summary.borrowerName)
                            .font(.headline)
                        HStack(spacing: 6) {
                            Text(summary.cardName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            statusBadge(summary.status)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        AnimatedCurrencyText(
                            value: summary.pendingAmount > 0.01 ? summary.pendingAmount : summary.totalDue,
                            font: .system(.headline, design: .rounded, weight: .bold),
                            color: summary.pendingAmount > 0.01 ? .orange : .green,
                            isPrivacyHidden: isPrivacyHidden
                        )
                        Text(summary.pendingAmount > 0.01 ? "Pendente" : "Total do mês")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectionTrigger.toggle()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        expandedBorrowerKey = isExpanded ? nil : summary.id
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        ForEach(summary.transactions) { tx in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tx.title)
                                        .font(.caption.weight(.semibold))
                                    if let badge = tx.installmentBadge {
                                        Text("Parcela \(badge)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                AnimatedCurrencyText(
                                    value: tx.amount,
                                    font: .system(.caption, design: .rounded, weight: .bold),
                                    isPrivacyHidden: isPrivacyHidden
                                )
                            }
                            .padding(.vertical, 2)
                        }

                        if summary.receivedInAccount > 0 || summary.appliedToInvoice > 0 {
                            Divider()
                            HStack {
                                Text("Já acertado:")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Formatters.currency(summary.receivedInAccount + summary.appliedToInvoice))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 10) {
                    if summary.pendingAmount > 0.01 {
                        Button {
                            settlingSummary = summary
                        } label: {
                            Label("Abater Valor", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if let url = Formatters.whatsAppURL(phone: summary.borrowerPhone, message: chargeText) {
                            openURL(url)
                        }
                    } label: {
                        Label("Enviar Resumo", systemImage: "message.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color(hex: "#25D366").opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(Color(hex: "#1CA851"))
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: chargeText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .padding(9)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private func statusBadge(_ status: BorrowerMonthlyStatus) -> some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.16), in: Capsule())
            .foregroundStyle(statusColor(status))
    }

    private func statusColor(_ status: BorrowerMonthlyStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .partial: return .yellow
        case .receivedInAccount: return .mint
        case .appliedToInvoice, .mixedSettled: return .green
        }
    }

    private func initials(_ name: String) -> String {
        let chars = name.split(separator: " ").prefix(2).compactMap(\.first)
        return chars.isEmpty ? "?" : String(chars).uppercased()
    }

    private func whatsAppSummary(for summary: BorrowerMonthlySummary) -> String {
        Formatters.whatsAppChargeMessage(
            borrowerName: summary.borrowerName,
            cardName: summary.cardName,
            month: summary.month,
            year: summary.year,
            items: summary.transactions.map { ($0.title, $0.installmentBadge, $0.amount) },
            pendingAmount: summary.pendingAmount > 0.01 ? summary.pendingAmount : summary.totalDue
        )
    }
}

struct SettlementActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let amount: Double
    let accounts: [Account]
    let onConfirm: (SettlementType, PersistentIdentifier?) -> Void

    @State private var selectedType: SettlementType = .appliedToInvoice
    @State private var selectedAccountID: PersistentIdentifier?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Valor a acertar")
                        Spacer()
                        AnimatedCurrencyText(
                            value: amount,
                            font: .system(.headline, design: .rounded, weight: .bold),
                            color: .green
                        )
                    }
                }

                Section("Como deseja registrar?") {
                    Picker("Tipo de Baixa", selection: $selectedType) {
                        ForEach(SettlementType.allCases, id: \.self) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(selectedType.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if selectedType == .receivedInAccount {
                    Section("Conta de Destino") {
                        Picker("Conta", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                Text("\(account.name) (\(Formatters.currency(account.currentBalance)))")
                                    .tag(Optional(account.persistentModelID))
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        onConfirm(selectedType, selectedType == .receivedInAccount ? selectedAccountID : nil)
                        dismiss()
                    }
                    .disabled(selectedType == .receivedInAccount && selectedAccountID == nil)
                }
            }
            .onAppear {
                selectedAccountID = accounts.first?.persistentModelID
            }
        }
        .presentationDetents([.medium])
    }
}

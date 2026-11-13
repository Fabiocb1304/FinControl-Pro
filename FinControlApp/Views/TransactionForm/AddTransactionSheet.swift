import SwiftUI
import SwiftData

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \CreditCard.name) private var creditCards: [CreditCard]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Borrower.name) private var borrowers: [Borrower]

    @State private var amountCents: Int = 0
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var paymentMethod: PaymentMethod = .creditCard
    @State private var isIncome: Bool = false
    @State private var installments: Int = 1
    @State private var isThirdParty: Bool = false

    @State private var selectedAccountID: PersistentIdentifier?
    @State private var destinationAccountID: PersistentIdentifier?
    @State private var selectedCardID: PersistentIdentifier?
    @State private var selectedCategoryID: PersistentIdentifier?
    @State private var selectedBorrowerID: PersistentIdentifier?

    @State private var showNewBorrowerSheet: Bool = false
    @State private var newBorrowerName: String = ""
    @State private var newBorrowerPhone: String = ""
    @State private var isSaving: Bool = false
    @State private var saveSuccessTrigger: Bool = false
    @State private var selectionTrigger: Bool = false
    @State private var errorMessage: String?

    private var amountValue: Double {
        Double(amountCents) / 100.0
    }

    private var filteredCategories: [Category] {
        if paymentMethod == .creditCard {
            return categories.filter { !$0.isIncome }
        }
        return categories.filter { $0.isIncome == isIncome }
    }

    private var canSave: Bool {
        guard amountCents > 0, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        switch paymentMethod {
        case .creditCard:
            if selectedCardID == nil { return false }
            if isThirdParty && selectedBorrowerID == nil { return false }
            return true
        case .debitPix:
            return selectedAccountID != nil
        case .transfer:
            return selectedAccountID != nil && destinationAccountID != nil && selectedAccountID != destinationAccountID
        case .reimbursement:
            return selectedAccountID != nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    amountDisplayCard

                    methodSelector

                    detailsFormCard

                    if paymentMethod == .creditCard {
                        creditCardOptionsCard
                    }

                    customNumericKeypad
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Novo Lançamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveTransaction() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Salvar")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                bootstrapDefaultSelections()
            }
            .sensoryFeedback(.selection, trigger: selectionTrigger)
            .sensoryFeedback(.success, trigger: saveSuccessTrigger)
            .sheet(isPresented: $showNewBorrowerSheet) {
                quickNewBorrowerSheet
            }
            .alert("Não foi possível salvar", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var amountDisplayCard: some View {
        GlassCardView(cornerRadius: 20, padding: 18) {
            VStack(spacing: 8) {
                Text(paymentMethod == .creditCard ? "Valor da Compra" : (isIncome ? "Valor da Receita" : "Valor da Movimentação"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                AnimatedCurrencyText(
                    value: amountValue,
                    font: .system(size: 38, weight: .bold, design: .rounded),
                    color: amountDisplayColor
                )

                if paymentMethod == .creditCard && installments > 1 && amountValue > 0 {
                    let perInstallment = amountValue / Double(installments)
                    Text("\(installments)x de \(Formatters.currency(perInstallment))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var amountDisplayColor: Color {
        if paymentMethod == .creditCard {
            return isThirdParty ? .orange : .primary
        }
        if paymentMethod == .transfer { return .blue }
        return isIncome ? .green : .primary
    }

    private var methodSelector: some View {
        VStack(spacing: 10) {
            Picker("Método", selection: $paymentMethod) {
                Text("Cartão").tag(PaymentMethod.creditCard)
                Text("Débito / Pix").tag(PaymentMethod.debitPix)
                Text("Transferência").tag(PaymentMethod.transfer)
            }
            .pickerStyle(.segmented)
            .onChange(of: paymentMethod) { _, newValue in
                selectionTrigger.toggle()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    if newValue != .creditCard {
                        isThirdParty = false
                    }
                    selectedCategoryID = filteredCategories.first?.persistentModelID
                }
            }

            if paymentMethod == .debitPix {
                Picker("Tipo", selection: $isIncome) {
                    Text("Saída (Despesa)").tag(false)
                    Text("Entrada (Receita)").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: isIncome) { _, _ in
                    selectionTrigger.toggle()
                    selectedCategoryID = filteredCategories.first?.persistentModelID
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: paymentMethod)
    }

    private var detailsFormCard: some View {
        GlassCardView(cornerRadius: 20, padding: 14) {
            VStack(spacing: 12) {
                TextField("Descrição (ex: Mercado, Passagem...)", text: $title)
                    .font(.body)
                    .padding(10)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                DatePicker("Data", selection: $date, displayedComponents: .date)
                    .environment(\.locale, Formatters.ptBR)

                if paymentMethod == .debitPix || paymentMethod == .transfer {
                    HStack {
                        Text(paymentMethod == .transfer ? "Conta de Origem" : "Conta")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Conta", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                Text(account.name).tag(Optional(account.persistentModelID))
                            }
                        }
                        .tint(.primary)
                    }
                }

                if paymentMethod == .transfer {
                    HStack {
                        Text("Conta de Destino")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Destino", selection: $destinationAccountID) {
                            ForEach(accounts) { account in
                                Text(account.name).tag(Optional(account.persistentModelID))
                            }
                        }
                        .tint(.primary)
                    }
                }

                if paymentMethod == .creditCard {
                    HStack {
                        Text("Cartão")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Cartão", selection: $selectedCardID) {
                            ForEach(creditCards) { card in
                                Text(card.name).tag(Optional(card.persistentModelID))
                            }
                        }
                        .tint(.primary)
                    }
                }

                if !isThirdParty && paymentMethod != .transfer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categoria")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filteredCategories) { cat in
                                    let isSelected = selectedCategoryID == cat.persistentModelID
                                    Button {
                                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                            selectedCategoryID = cat.persistentModelID
                                        }
                                        selectionTrigger.toggle()
                                    } label: {
                                        Label(cat.name, systemImage: cat.iconName)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                isSelected
                                                ? Color(hex: cat.colorHex).opacity(0.22)
                                                : Color(.tertiarySystemFill),
                                                in: Capsule()
                                            )
                                            .overlay {
                                                Capsule()
                                                    .strokeBorder(isSelected ? Color(hex: cat.colorHex) : .clear, lineWidth: 1.5)
                                            }
                                            .foregroundStyle(isSelected ? Color(hex: cat.colorHex) : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isThirdParty)
    }

    private var creditCardOptionsCard: some View {
        GlassCardView(cornerRadius: 20, padding: 14, tintColor: isThirdParty ? .orange : nil) {
            VStack(spacing: 14) {
                HStack {
                    Label("Parcelamento", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("Parcelas", selection: $installments) {
                        ForEach(1...24, id: \.self) { count in
                            Text(count == 1 ? "À vista (1x)" : "\(count)x").tag(count)
                        }
                    }
                    .tint(.primary)
                }

                Divider()

                Toggle(isOn: $isThirdParty.animation(.spring(duration: 0.35, bounce: 0.15))) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Emprestei o Cartão para alguém?")
                                .font(.subheadline.weight(.semibold))
                            Text("Não entra nos seus gastos pessoais nem nas metas.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.2.badge.key.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .tint(.orange)
                .onChange(of: isThirdParty) { _, newValue in
                    selectionTrigger.toggle()
                    if newValue && selectedBorrowerID == nil {
                        selectedBorrowerID = borrowers.first?.persistentModelID
                    }
                }

                if isThirdParty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Quem vai pagar?")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showNewBorrowerSheet = true
                            } label: {
                                Label("Novo Contato", systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(borrowers) { borrower in
                                    let isSelected = selectedBorrowerID == borrower.persistentModelID
                                    Button {
                                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                            selectedBorrowerID = borrower.persistentModelID
                                        }
                                        selectionTrigger.toggle()
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: borrower.avatarColorHex).opacity(isSelected ? 1.0 : 0.25))
                                                    .frame(width: 44, height: 44)
                                                Text(borrower.initials)
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(isSelected ? .white : Color(hex: borrower.avatarColorHex))
                                            }
                                            Text(borrower.name)
                                                .font(.caption2.weight(.medium))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(
                                            isSelected ? Color.orange.opacity(0.14) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var customNumericKeypad: some View {
        let keys = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["00", "0", "⌫"]
        ]

        return GlassCardView(cornerRadius: 20, padding: 10) {
            VStack(spacing: 8) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                handleKeyTap(key)
                            } label: {
                                Text(key)
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var quickNewBorrowerSheet: some View {
        NavigationStack {
            Form {
                Section("Dados do Contato") {
                    TextField("Nome completo", text: $newBorrowerName)
                    TextField("WhatsApp (DDD + número)", text: $newBorrowerPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Novo Contato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showNewBorrowerSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") {
                        Task { await createBorrower() }
                    }
                    .disabled(newBorrowerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func handleKeyTap(_ key: String) {
        selectionTrigger.toggle()
        if key == "⌫" {
            amountCents /= 10
        } else if key == "00" {
            guard amountCents < 1_000_000_00 else { return }
            amountCents *= 100
        } else if let digit = Int(key) {
            guard amountCents < 10_000_000_00 else { return }
            amountCents = (amountCents * 10) + digit
        }
    }

    private func bootstrapDefaultSelections() {
        if selectedAccountID == nil {
            selectedAccountID = accounts.first?.persistentModelID
        }
        if destinationAccountID == nil {
            destinationAccountID = accounts.dropFirst().first?.persistentModelID ?? accounts.first?.persistentModelID
        }
        if selectedCardID == nil {
            selectedCardID = creditCards.first?.persistentModelID
        }
        if selectedCategoryID == nil {
            selectedCategoryID = filteredCategories.first?.persistentModelID
        }
        if selectedBorrowerID == nil {
            selectedBorrowerID = borrowers.first?.persistentModelID
        }
    }

    private func createBorrower() async {
        let trimmed = newBorrowerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let palette = ["#FF9F0A", "#BF5AF2", "#64D2FF", "#30D158", "#FF375F"]
        let colorHex = palette[borrowers.count % palette.count]
        let engine = FinanceEngineActor(modelContainer: modelContext.container)

        do {
            let newID = try await engine.createBorrower(
                name: trimmed,
                phone: newBorrowerPhone.isEmpty ? nil : newBorrowerPhone,
                avatarColorHex: colorHex
            )
            selectedBorrowerID = newID
            newBorrowerName = ""
            newBorrowerPhone = ""
            showNewBorrowerSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveTransaction() async {
        isSaving = true
        defer { isSaving = false }

        let kind: TransactionKind
        switch paymentMethod {
        case .creditCard:
            kind = .expense
        case .debitPix:
            kind = isIncome ? .income : .expense
        case .transfer:
            kind = .transfer
        case .reimbursement:
            kind = .thirdPartyReimbursement
        }

        let input = NewTransactionInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amountValue,
            date: date,
            paymentMethod: paymentMethod,
            kind: kind,
            installments: paymentMethod == .creditCard ? installments : 1,
            isThirdParty: paymentMethod == .creditCard && isThirdParty,
            accountID: selectedAccountID,
            destinationAccountID: destinationAccountID,
            cardID: selectedCardID,
            categoryID: isThirdParty ? nil : selectedCategoryID,
            borrowerID: isThirdParty ? selectedBorrowerID : nil
        )

        let engine = FinanceEngineActor(modelContainer: modelContext.container)
        do {
            let alerts = try await engine.recordTransaction(input)
            await NotificationService.shared.dispatchBudgetAlerts(alerts)
            saveSuccessTrigger.toggle()
            NotificationCenter.default.post(name: .finControlDataDidChange, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

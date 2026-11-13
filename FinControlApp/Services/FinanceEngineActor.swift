import Foundation
import SwiftData

// MARK: - Sendable DTOs & Inputs

enum BudgetAlertLevel: Sendable, Hashable {
    case normal
    case warning80
    case critical100
}

struct CategorySpendingSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let persistentID: PersistentIdentifier
    let name: String
    let iconName: String
    let colorHex: String
    let spent: Double
    let budget: Double?

    var percentage: Double {
        guard let budget, budget > 0 else { return 0 }
        return (spent / budget) * 100.0
    }

    var alertLevel: BudgetAlertLevel {
        guard let budget, budget > 0 else { return .normal }
        let pct = (spent / budget) * 100.0
        if pct >= 100.0 { return .critical100 }
        if pct >= 80.0 { return .warning80 }
        return .normal
    }
}

struct InvoiceCompositionPoint: Identifiable, Sendable, Hashable {
    let id: String
    let cardName: String
    let segment: String
    let amount: Double
    let colorHex: String
}

struct DashboardSnapshot: Sendable {
    let month: Int
    let year: Int
    let totalAccountsBalance: Double
    let totalInvestedAmount: Double
    let totalInvestmentsCurrentBalance: Double
    let investmentReturnPercentage: Double
    let monthlyPersonalIncome: Double
    let monthlyPersonalCardCost: Double
    let monthlyThirdPartyReceivable: Double
    let monthlyGrossInvoiceTotal: Double
    let monthlyPrepaidAmount: Double
    let categorySpendings: [CategorySpendingSummary]
    let invoiceCompositionPoints: [InvoiceCompositionPoint]
}

struct CardMetrics: Identifiable, Sendable, Hashable {
    var id: PersistentIdentifier { cardID }
    let cardID: PersistentIdentifier
    let uuid: UUID
    let name: String
    let totalLimit: Double
    let closingDay: Int
    let dueDay: Int
    let colorHex: String
    let openOwnAmount: Double
    let openThirdPartyAmount: Double
    let prepaidOnOpenInvoices: Double
    let availableLimit: Double
    let currentInvoiceID: PersistentIdentifier?
    let currentInvoiceStatus: InvoiceStatus
    let currentMonthGross: Double
    let currentMonthOwn: Double
    let currentMonthThirdParty: Double
    let currentMonthPrepaid: Double
    let currentMonthNetPayable: Double
}

struct TransactionDTO: Identifiable, Sendable, Hashable {
    var id: PersistentIdentifier { persistentID }
    let persistentID: PersistentIdentifier
    let uuid: UUID
    let title: String
    let amount: Double
    let date: Date
    let paymentMethod: PaymentMethod
    let kind: TransactionKind
    let isThirdParty: Bool
    let installmentIndex: Int
    let totalInstallments: Int
    let isPaidOrSettled: Bool
    let categoryName: String?
    let categoryIcon: String?
    let categoryColorHex: String?
    let accountName: String?
    let borrowerID: PersistentIdentifier?
    let borrowerName: String?
    let borrowerPhone: String?
    let invoiceID: PersistentIdentifier?
    let cardName: String?

    var installmentBadge: String? {
        guard totalInstallments > 1 else { return nil }
        return "\(installmentIndex)/\(totalInstallments)"
    }
}

enum BorrowerMonthlyStatus: String, Sendable, Hashable {
    case pending = "Pendente"
    case partial = "Parcial"
    case receivedInAccount = "Recebido"
    case appliedToInvoice = "Abatido na Fatura"
    case mixedSettled = "Quitado"
}

struct BorrowerMonthlySummary: Identifiable, Sendable, Hashable {
    var id: String { "\(borrowerUUID.uuidString)-\(invoiceUUID.uuidString)" }
    let borrowerID: PersistentIdentifier
    let borrowerUUID: UUID
    let borrowerName: String
    let borrowerPhone: String?
    let avatarColorHex: String
    let invoiceID: PersistentIdentifier
    let invoiceUUID: UUID
    let cardName: String
    let month: Int
    let year: Int
    let totalDue: Double
    let receivedInAccount: Double
    let appliedToInvoice: Double
    let pendingAmount: Double
    let status: BorrowerMonthlyStatus
    let transactions: [TransactionDTO]
}

struct InvoiceDetailSnapshot: Sendable {
    let invoiceID: PersistentIdentifier
    let cardID: PersistentIdentifier
    let cardName: String
    let cardColorHex: String
    let closingDay: Int
    let dueDay: Int
    let month: Int
    let year: Int
    let status: InvoiceStatus
    let grossTotal: Double
    let ownTotal: Double
    let thirdPartyTotal: Double
    let prepaidAmount: Double
    let netPayable: Double
    let allTransactions: [TransactionDTO]
    let ownTransactions: [TransactionDTO]
    let borrowerSummaries: [BorrowerMonthlySummary]
}

struct AccountSummaryDTO: Identifiable, Sendable, Hashable {
    var id: PersistentIdentifier { persistentID }
    let persistentID: PersistentIdentifier
    let uuid: UUID
    let name: String
    let initialBalance: Double
    let currentBalance: Double
    let colorHex: String
    let iconName: String
}

struct ExtractDayGroup: Identifiable, Sendable, Hashable {
    var id: Date { dayStart }
    let dayStart: Date
    let title: String
    let transactions: [TransactionDTO]
}

struct InvestmentDTO: Identifiable, Sendable, Hashable {
    var id: PersistentIdentifier { persistentID }
    let persistentID: PersistentIdentifier
    let uuid: UUID
    let name: String
    let assetClass: AssetClass
    let institution: String
    let investedAmount: Double
    let currentBalance: Double
    let lastUpdated: Date

    var profitAmount: Double { currentBalance - investedAmount }
    var profitPercentage: Double {
        guard investedAmount > 0 else { return 0 }
        return (profitAmount / investedAmount) * 100.0
    }
}

struct AssetAllocationSlice: Identifiable, Sendable, Hashable {
    var id: String { assetClass.rawValue }
    let assetClass: AssetClass
    let totalValue: Double
    let percentage: Double
}

struct InvestmentPortfolioSnapshot: Sendable {
    let totalInvested: Double
    let totalCurrentBalance: Double
    let profitAmount: Double
    let profitPercentage: Double
    let allocations: [AssetAllocationSlice]
    let investments: [InvestmentDTO]
}

struct NewTransactionInput: Sendable {
    let title: String
    let amount: Double
    let date: Date
    let paymentMethod: PaymentMethod
    let kind: TransactionKind
    let installments: Int
    let isThirdParty: Bool
    let accountID: PersistentIdentifier?
    let destinationAccountID: PersistentIdentifier?
    let cardID: PersistentIdentifier?
    let categoryID: PersistentIdentifier?
    let borrowerID: PersistentIdentifier?
}

// MARK: - FinanceEngineActor

@ModelActor
actor FinanceEngineActor {

    // MARK: - Queries & Aggregations

    func fetchDashboardSnapshot(month: Int, year: Int) throws -> DashboardSnapshot {
        try InvoiceGeneratorService.closeElapsedInvoices(in: modelContext)

        let accounts = try modelContext.fetch(FetchDescriptor<Account>())
        let totalAccountsBalance = accounts.reduce(0.0) { $0 + $1.currentBalance }

        let investments = try modelContext.fetch(FetchDescriptor<Investment>())
        let totalInvested = investments.reduce(0.0) { $0 + $1.investedAmount }
        let totalInvestmentsBalance = investments.reduce(0.0) { $0 + $1.currentBalance }
        let invReturnPct = totalInvested > 0
            ? ((totalInvestmentsBalance - totalInvested) / totalInvested) * 100.0
            : 0.0

        // Month boundaries for account transactions
        let (startOfMonth, endOfMonth) = monthDateBounds(month: month, year: year)
        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { tx in
                tx.date >= startOfMonth && tx.date < endOfMonth
            }
        )
        let monthAccountCandidates = try modelContext.fetch(txDescriptor)

        // RN01: ThirdPartyReimbursement NEVER enters Personal Income
        let monthlyPersonalIncome = monthAccountCandidates
            .filter { $0.paymentMethod != .creditCard && $0.kind == .income }
            .reduce(0.0) { $0 + $1.amount }

        // Invoices for (month, year)
        let invDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.month == month && $0.year == year }
        )
        let monthInvoices = try modelContext.fetch(invDescriptor)

        var ownCardCost = 0.0
        var grossInvoiceTotal = 0.0
        var totalPrepaid = 0.0
        var totalThirdPartyPendingOrGross = 0.0
        var compositionPoints: [InvoiceCompositionPoint] = []

        // Aggregate category spendings: DebitPix personal expenses + CreditCard personal installments (!isThirdParty)
        var categorySpentMap: [PersistentIdentifier: Double] = [:]

        for tx in monthAccountCandidates where tx.paymentMethod == .debitPix && tx.kind == .expense && !tx.isThirdParty {
            if let catID = tx.category?.persistentModelID {
                categorySpentMap[catID, default: 0] += tx.amount
            }
        }

        for invoice in monthInvoices {
            invoice.recalculateCache()
            let own = invoice.cachedOwnTotal
            let thirdParty = invoice.cachedThirdPartyTotal
            let gross = invoice.cachedGrossTotal
            let prepaid = invoice.prepaidAmount

            ownCardCost += own
            grossInvoiceTotal += gross
            totalPrepaid += prepaid

            let borrowerSummaries = buildBorrowerSummaries(for: invoice)
            let pendingReceivable = borrowerSummaries.reduce(0.0) { $0 + $1.pendingAmount }
            totalThirdPartyPendingOrGross += pendingReceivable

            for tx in invoice.safeTransactions where !tx.isThirdParty {
                if let catID = tx.category?.persistentModelID {
                    categorySpentMap[catID, default: 0] += tx.amount
                }
            }

            let cardTitle = invoice.card?.name ?? "Cartão"
            if own > 0 || thirdParty > 0 || prepaid > 0 {
                compositionPoints.append(
                    InvoiceCompositionPoint(
                        id: "\(cardTitle)-own",
                        cardName: cardTitle,
                        segment: "Meus Gastos",
                        amount: own,
                        colorHex: "#0A84FF"
                    )
                )
                compositionPoints.append(
                    InvoiceCompositionPoint(
                        id: "\(cardTitle)-third",
                        cardName: cardTitle,
                        segment: "Terceiros",
                        amount: thirdParty,
                        colorHex: "#FF9F0A"
                    )
                )
                if prepaid > 0 {
                    compositionPoints.append(
                        InvoiceCompositionPoint(
                            id: "\(cardTitle)-prepaid",
                            cardName: cardTitle,
                            segment: "Abatimentos",
                            amount: prepaid,
                            colorHex: "#30D158"
                        )
                    )
                }
            }
        }

        let categories = try modelContext.fetch(FetchDescriptor<Category>())
        let categorySpendings: [CategorySpendingSummary] = categories
            .filter { !$0.isIncome }
            .map { category in
                let spent = categorySpentMap[category.persistentModelID] ?? 0.0
                return CategorySpendingSummary(
                    id: category.id,
                    persistentID: category.persistentModelID,
                    name: category.name,
                    iconName: category.iconName,
                    colorHex: category.colorHex,
                    spent: spent,
                    budget: category.monthlyBudget
                )
            }
            .filter { $0.spent > 0 || ($0.budget ?? 0) > 0 }
            .sorted { $0.spent > $1.spent }

        try? modelContext.save()

        return DashboardSnapshot(
            month: month,
            year: year,
            totalAccountsBalance: totalAccountsBalance,
            totalInvestedAmount: totalInvested,
            totalInvestmentsCurrentBalance: totalInvestmentsBalance,
            investmentReturnPercentage: invReturnPct,
            monthlyPersonalIncome: monthlyPersonalIncome,
            monthlyPersonalCardCost: ownCardCost,
            monthlyThirdPartyReceivable: totalThirdPartyPendingOrGross,
            monthlyGrossInvoiceTotal: grossInvoiceTotal,
            monthlyPrepaidAmount: totalPrepaid,
            categorySpendings: categorySpendings,
            invoiceCompositionPoints: compositionPoints
        )
    }

    func fetchCardMetricsList(month: Int, year: Int) throws -> [CardMetrics] {
        let cards = try modelContext.fetch(FetchDescriptor<CreditCard>(sortBy: [SortDescriptor(\.name)]))
        var results: [CardMetrics] = []
        results.reserveCapacity(cards.count)

        for card in cards {
            let invoices = card.safeInvoices
            let unpaidInvoices = invoices.filter { $0.status != .paid }

            var openOwn = 0.0
            var openThirdParty = 0.0
            var prepaidOnOpen = 0.0

            for inv in unpaidInvoices {
                inv.recalculateCache()
                openOwn += inv.cachedOwnTotal
                openThirdParty += inv.cachedThirdPartyTotal
                prepaidOnOpen += inv.prepaidAmount
            }

            // RN02: Limite Disponível = Limite Total - Parcelas Abertas (Próprias) - Parcelas Abertas (Terceiros) + Abatimentos Antecipados
            let availableLimit = card.totalLimit - openOwn - openThirdParty + prepaidOnOpen

            let currentInvoice = try InvoiceGeneratorService.findOrCreateInvoice(
                for: card,
                month: month,
                year: year,
                in: modelContext
            )
            currentInvoice.recalculateCache()

            results.append(
                CardMetrics(
                    cardID: card.persistentModelID,
                    uuid: card.id,
                    name: card.name,
                    totalLimit: card.totalLimit,
                    closingDay: card.closingDay,
                    dueDay: card.dueDay,
                    colorHex: card.colorHex,
                    openOwnAmount: openOwn,
                    openThirdPartyAmount: openThirdParty,
                    prepaidOnOpenInvoices: prepaidOnOpen,
                    availableLimit: availableLimit,
                    currentInvoiceID: currentInvoice.persistentModelID,
                    currentInvoiceStatus: currentInvoice.status,
                    currentMonthGross: currentInvoice.cachedGrossTotal,
                    currentMonthOwn: currentInvoice.cachedOwnTotal,
                    currentMonthThirdParty: currentInvoice.cachedThirdPartyTotal,
                    currentMonthPrepaid: currentInvoice.prepaidAmount,
                    currentMonthNetPayable: currentInvoice.cachedNetPayable
                )
            )
        }
        return results
    }

    func fetchInvoiceDetail(cardID: PersistentIdentifier, month: Int, year: Int) throws -> InvoiceDetailSnapshot {
        guard let card = modelContext.model(for: cardID) as? CreditCard else {
            throw CocoaError(.fileNoSuchFile)
        }

        let invoice = try InvoiceGeneratorService.findOrCreateInvoice(
            for: card,
            month: month,
            year: year,
            in: modelContext
        )
        invoice.recalculateCache()
        try? modelContext.save()

        let sortedTxs = invoice.safeTransactions.sorted { $0.date > $1.date }
        var allDTOs: [TransactionDTO] = []
        var ownDTOs: [TransactionDTO] = []
        allDTOs.reserveCapacity(sortedTxs.count)
        for tx in sortedTxs {
            let dto = makeDTO(from: tx)
            allDTOs.append(dto)
            if !tx.isThirdParty {
                ownDTOs.append(dto)
            }
        }
        let borrowerSummaries = buildBorrowerSummaries(for: invoice)

        return InvoiceDetailSnapshot(
            invoiceID: invoice.persistentModelID,
            cardID: card.persistentModelID,
            cardName: card.name,
            cardColorHex: card.colorHex,
            closingDay: card.closingDay,
            dueDay: card.dueDay,
            month: month,
            year: year,
            status: invoice.status,
            grossTotal: invoice.cachedGrossTotal,
            ownTotal: invoice.cachedOwnTotal,
            thirdPartyTotal: invoice.cachedThirdPartyTotal,
            prepaidAmount: invoice.prepaidAmount,
            netPayable: invoice.cachedNetPayable,
            allTransactions: allDTOs,
            ownTransactions: ownDTOs,
            borrowerSummaries: borrowerSummaries
        )
    }

    func fetchAllThirdPartyLoans(month: Int, year: Int) throws -> [BorrowerMonthlySummary] {
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.month == month && $0.year == year }
        )
        let invoices = try modelContext.fetch(descriptor)
        var summaries: [BorrowerMonthlySummary] = []
        for invoice in invoices {
            summaries.append(contentsOf: buildBorrowerSummaries(for: invoice))
        }
        return summaries.sorted { $0.pendingAmount > $1.pendingAmount }
    }

    func fetchAccountExtract(accountFilter: PersistentIdentifier? = nil) throws -> (accounts: [AccountSummaryDTO], groups: [ExtractDayGroup]) {
        let accounts = try modelContext.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
        let accountDTOs = accounts.map {
            AccountSummaryDTO(
                persistentID: $0.persistentModelID,
                uuid: $0.id,
                name: $0.name,
                initialBalance: $0.initialBalance,
                currentBalance: $0.currentBalance,
                colorHex: $0.colorHex,
                iconName: $0.iconName
            )
        }

        let creditCardRaw = PaymentMethod.creditCard.rawValue
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.paymentMethodRaw != creditCardRaw },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let fetched = try modelContext.fetch(descriptor)
        let filtered: [Transaction]
        if let accountFilter {
            filtered = fetched.filter {
                $0.account?.persistentModelID == accountFilter
            }
        } else {
            filtered = fetched
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { tx in
            calendar.startOfDay(for: tx.date)
        }
        var dayGroups: [ExtractDayGroup] = []
        for day in grouped.keys.sorted(by: >) {
            let transactions = grouped[day] ?? []
            var dayTxs: [TransactionDTO] = []
            dayTxs.reserveCapacity(transactions.count)
            for tx in transactions {
                dayTxs.append(makeDTO(from: tx))
            }
            dayGroups.append(
                ExtractDayGroup(
                    dayStart: day,
                    title: Formatters.daySectionTitle(day),
                    transactions: dayTxs
                )
            )
        }

        return (accountDTOs, dayGroups)
    }

    func fetchInvestmentPortfolio() throws -> InvestmentPortfolioSnapshot {
        let investments = try modelContext.fetch(FetchDescriptor<Investment>(sortBy: [SortDescriptor(\.currentBalance, order: .reverse)]))
        let totalInvested = investments.reduce(0.0) { $0 + $1.investedAmount }
        let totalBalance = investments.reduce(0.0) { $0 + $1.currentBalance }
        let profitAmount = totalBalance - totalInvested
        let profitPct = totalInvested > 0 ? (profitAmount / totalInvested) * 100.0 : 0.0

        let byClass = Dictionary(grouping: investments) { $0.assetClass }
        var allocations: [AssetAllocationSlice] = []
        for assetClass in AssetClass.allCases {
            let sum = (byClass[assetClass] ?? []).reduce(0.0) { $0 + $1.currentBalance }
            guard sum > 0 else { continue }
            let pct = totalBalance > 0 ? (sum / totalBalance) * 100.0 : 0.0
            allocations.append(AssetAllocationSlice(assetClass: assetClass, totalValue: sum, percentage: pct))
        }

        let dtos = investments.map {
            InvestmentDTO(
                persistentID: $0.persistentModelID,
                uuid: $0.id,
                name: $0.name,
                assetClass: $0.assetClass,
                institution: $0.institution,
                investedAmount: $0.investedAmount,
                currentBalance: $0.currentBalance,
                lastUpdated: $0.lastUpdated
            )
        }

        return InvestmentPortfolioSnapshot(
            totalInvested: totalInvested,
            totalCurrentBalance: totalBalance,
            profitAmount: profitAmount,
            profitPercentage: profitPct,
            allocations: allocations,
            investments: dtos
        )
    }

    // MARK: - Mutations

    func recordTransaction(_ input: NewTransactionInput) throws -> [BudgetThresholdAlert] {
        var alerts: [BudgetThresholdAlert] = []
        let calendar = Calendar.current
        let txMonth = calendar.component(.month, from: input.date)
        let txYear = calendar.component(.year, from: input.date)

        let category = input.categoryID.flatMap { modelContext.model(for: $0) as? Category }
        let borrower = input.borrowerID.flatMap { modelContext.model(for: $0) as? Borrower }

        switch input.paymentMethod {
        case .creditCard:
            guard let cardID = input.cardID,
                  let card = modelContext.model(for: cardID) as? CreditCard else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }
            let touchedInvoices = try InvoiceGeneratorService.generateInstallments(
                title: input.title,
                totalAmount: input.amount,
                purchaseDate: input.date,
                installments: input.installments,
                card: card,
                category: category,
                isThirdParty: input.isThirdParty,
                borrower: borrower,
                in: modelContext
            )

            try modelContext.save()

            if !input.isThirdParty, let category {
                // Evaluate budget alerts on the first affected invoice's month/year
                let firstPeriod = InvoiceGeneratorService.targetInvoiceMonthYear(
                    purchaseDate: input.date,
                    closingDay: card.closingDay,
                    installmentIndex: 1
                )
                if let alert = try evaluateBudgetAlert(for: category, month: firstPeriod.month, year: firstPeriod.year) {
                    alerts.append(alert)
                }
            }
            _ = touchedInvoices

        case .debitPix, .reimbursement:
            guard let accountID = input.accountID,
                  let account = modelContext.model(for: accountID) as? Account else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }
            let tx = Transaction(
                title: input.title,
                amount: input.amount,
                date: input.date,
                paymentMethod: input.paymentMethod,
                kind: input.kind,
                isThirdParty: input.kind == .thirdPartyReimbursement,
                isPaidOrSettled: true,
                account: account,
                category: input.kind == .thirdPartyReimbursement ? nil : category,
                borrower: borrower
            )
            contextInsertAndBalanceUpdate(tx, account: account)
            try modelContext.save()

            if input.kind == .expense, let category {
                if let alert = try evaluateBudgetAlert(for: category, month: txMonth, year: txYear) {
                    alerts.append(alert)
                }
            }

        case .transfer:
            guard let sourceID = input.accountID,
                  let source = modelContext.model(for: sourceID) as? Account,
                  let destID = input.destinationAccountID,
                  let dest = modelContext.model(for: destID) as? Account,
                  source.persistentModelID != dest.persistentModelID else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }

            let outTx = Transaction(
                title: "Transferência para \(dest.name)",
                amount: input.amount,
                date: input.date,
                paymentMethod: .transfer,
                kind: .transfer,
                isPaidOrSettled: true,
                destinationAccountId: dest.id,
                account: source
            )
            let inTx = Transaction(
                title: "Transferência de \(source.name)",
                amount: input.amount,
                date: input.date,
                paymentMethod: .transfer,
                kind: .transfer,
                isPaidOrSettled: true,
                destinationAccountId: source.id,
                account: dest
            )
            source.currentBalance -= input.amount
            dest.currentBalance += input.amount
            modelContext.insert(outTx)
            modelContext.insert(inTx)
            try modelContext.save()
        }

        return alerts
    }

    func settleThirdPartyTransaction(
        transactionID: PersistentIdentifier,
        type: SettlementType,
        destinationAccountID: PersistentIdentifier?
    ) throws {
        guard let tx = modelContext.model(for: transactionID) as? Transaction,
              let invoice = tx.invoice,
              let borrower = tx.borrower,
              !tx.isPaidOrSettled else {
            return
        }

        let destAccount = destinationAccountID.flatMap { modelContext.model(for: $0) as? Account }
        try applySettlement(
            amount: tx.amount,
            type: type,
            borrower: borrower,
            invoice: invoice,
            destinationAccount: destAccount
        )
        tx.isPaidOrSettled = true
        invoice.recalculateCache()
        try modelContext.save()
    }

    func settleBorrowerInvoice(
        borrowerID: PersistentIdentifier,
        invoiceID: PersistentIdentifier,
        amount: Double,
        type: SettlementType,
        destinationAccountID: PersistentIdentifier?
    ) throws {
        guard let borrower = modelContext.model(for: borrowerID) as? Borrower,
              let invoice = modelContext.model(for: invoiceID) as? Invoice,
              amount > 0 else {
            return
        }

        let destAccount = destinationAccountID.flatMap { modelContext.model(for: $0) as? Account }
        try applySettlement(
            amount: amount,
            type: type,
            borrower: borrower,
            invoice: invoice,
            destinationAccount: destAccount
        )

        // Check if total settled covers the borrower's monthly debt on this invoice
        let summaryList = buildBorrowerSummaries(for: invoice)
        if let updated = summaryList.first(where: { $0.borrowerID == borrowerID }),
           updated.pendingAmount <= 0.01 {
            for tx in invoice.safeTransactions where tx.isThirdParty && tx.borrower?.persistentModelID == borrowerID {
                tx.isPaidOrSettled = true
            }
        }
        invoice.recalculateCache()
        try modelContext.save()
    }

    func markInvoiceAsPaid(
        invoiceID: PersistentIdentifier,
        paymentAccountID: PersistentIdentifier?
    ) throws {
        guard let invoice = modelContext.model(for: invoiceID) as? Invoice else { return }
        invoice.recalculateCache()
        let amountToPay = invoice.cachedNetPayable

        if let accountID = paymentAccountID,
           let account = modelContext.model(for: accountID) as? Account,
           amountToPay > 0 {
            let paymentTx = Transaction(
                title: "Pagamento Fatura \(invoice.card?.name ?? "Cartão") \(Formatters.shortMonthTitle(month: invoice.month, year: invoice.year))",
                amount: amountToPay,
                date: Date(),
                paymentMethod: .debitPix,
                kind: .transfer,
                isPaidOrSettled: true,
                account: account
            )
            account.currentBalance -= amountToPay
            modelContext.insert(paymentTx)
        }

        invoice.status = .paid
        for tx in invoice.safeTransactions where !tx.isThirdParty {
            tx.isPaidOrSettled = true
        }
        try modelContext.save()
    }

    func addInvestmentContribution(
        investmentID: PersistentIdentifier?,
        name: String,
        assetClass: AssetClass,
        institution: String,
        amount: Double,
        debitAccountID: PersistentIdentifier?
    ) throws {
        guard amount > 0 else { return }

        if let investmentID,
           let existing = modelContext.model(for: investmentID) as? Investment {
            existing.investedAmount += amount
            existing.currentBalance += amount
            existing.lastUpdated = Date()
        } else {
            let newInvestment = Investment(
                name: name,
                assetClass: assetClass,
                institution: institution,
                investedAmount: amount,
                currentBalance: amount,
                lastUpdated: Date()
            )
            modelContext.insert(newInvestment)
        }

        if let debitAccountID,
           let account = modelContext.model(for: debitAccountID) as? Account {
            account.currentBalance -= amount
            let tx = Transaction(
                title: "Aporte: \(name)",
                amount: amount,
                date: Date(),
                paymentMethod: .transfer,
                kind: .transfer,
                isPaidOrSettled: true,
                account: account
            )
            modelContext.insert(tx)
        }

        try modelContext.save()
    }

    func updateInvestmentBalance(investmentID: PersistentIdentifier, newBalance: Double) throws {
        guard let investment = modelContext.model(for: investmentID) as? Investment else { return }
        investment.currentBalance = max(0, newBalance)
        investment.lastUpdated = Date()
        try modelContext.save()
    }

    func createBorrower(name: String, phone: String?, avatarColorHex: String) throws -> PersistentIdentifier {
        let borrower = Borrower(name: name, phone: phone, avatarColorHex: avatarColorHex)
        modelContext.insert(borrower)
        try modelContext.save()
        return borrower.persistentModelID
    }

    func deleteTransaction(transactionID: PersistentIdentifier) throws {
        guard let tx = modelContext.model(for: transactionID) as? Transaction else { return }

        if tx.paymentMethod != .creditCard, let account = tx.account {
            switch tx.kind {
            case .income, .thirdPartyReimbursement:
                account.currentBalance -= tx.amount
            case .expense, .transfer:
                account.currentBalance += tx.amount
            }
        }

        let affectedInvoice = tx.invoice
        modelContext.delete(tx)
        affectedInvoice?.recalculateCache()
        try modelContext.save()
    }

    // MARK: - Private Helpers

    private func contextInsertAndBalanceUpdate(_ tx: Transaction, account: Account) {
        switch tx.kind {
        case .income, .thirdPartyReimbursement:
            account.currentBalance += tx.amount
        case .expense, .transfer:
            account.currentBalance -= tx.amount
        }
        modelContext.insert(tx)
    }

    private func applySettlement(
        amount: Double,
        type: SettlementType,
        borrower: Borrower,
        invoice: Invoice,
        destinationAccount: Account?
    ) throws {
        let settlement = ThirdPartySettlement(
            amount: amount,
            date: Date(),
            settlementType: type,
            borrower: borrower,
            invoice: invoice,
            destinationAccount: type == .receivedInAccount ? destinationAccount : nil
        )
        modelContext.insert(settlement)

        switch type {
        case .receivedInAccount:
            if let destinationAccount {
                destinationAccount.currentBalance += amount
                let reimbursement = Transaction(
                    title: "Reembolso \(borrower.name) (\(invoice.card?.name ?? "Cartão"))",
                    amount: amount,
                    date: Date(),
                    paymentMethod: .reimbursement,
                    kind: .thirdPartyReimbursement,
                    isThirdParty: true,
                    isPaidOrSettled: true,
                    account: destinationAccount,
                    borrower: borrower
                )
                modelContext.insert(reimbursement)
            }
        case .appliedToInvoice:
            invoice.prepaidAmount += amount
        }
    }

    private func buildBorrowerSummaries(for invoice: Invoice) -> [BorrowerMonthlySummary] {
        let thirdPartyTxs = invoice.safeTransactions.filter { $0.isThirdParty }
        let groupedTxs = Dictionary(grouping: thirdPartyTxs) { tx in
            tx.borrower?.persistentModelID
        }

        let settlementsByBorrower = Dictionary(grouping: invoice.safeSettlements) { settlement in
            settlement.borrower?.persistentModelID
        }

        var summaries: [BorrowerMonthlySummary] = []
        for (key, txs) in groupedTxs {
            guard let borrowerID = key,
                  let borrower = txs.first?.borrower else { continue }

            let totalDue = txs.reduce(0.0) { $0 + $1.amount }
            let borrowerSettlements = settlementsByBorrower[borrowerID] ?? []
            let received = borrowerSettlements
                .filter { $0.settlementType == .receivedInAccount }
                .reduce(0.0) { $0 + $1.amount }
            let applied = borrowerSettlements
                .filter { $0.settlementType == .appliedToInvoice }
                .reduce(0.0) { $0 + $1.amount }

            let totalSettled = received + applied
            let pending = max(0.0, totalDue - totalSettled)

            let status: BorrowerMonthlyStatus
            if pending <= 0.01 {
                if applied > 0 && received <= 0.01 {
                    status = .appliedToInvoice
                } else if received > 0 && applied <= 0.01 {
                    status = .receivedInAccount
                } else {
                    status = .mixedSettled
                }
            } else if totalSettled > 0.01 {
                status = .partial
            } else {
                status = .pending
            }

            let sortedTxs = txs.sorted { $0.date > $1.date }
            var dtos: [TransactionDTO] = []
            dtos.reserveCapacity(sortedTxs.count)
            for tx in sortedTxs {
                dtos.append(makeDTO(from: tx))
            }

            summaries.append(
                BorrowerMonthlySummary(
                    borrowerID: borrower.persistentModelID,
                    borrowerUUID: borrower.id,
                    borrowerName: borrower.name,
                    borrowerPhone: borrower.phone,
                    avatarColorHex: borrower.avatarColorHex,
                    invoiceID: invoice.persistentModelID,
                    invoiceUUID: invoice.id,
                    cardName: invoice.card?.name ?? "Cartão",
                    month: invoice.month,
                    year: invoice.year,
                    totalDue: totalDue,
                    receivedInAccount: received,
                    appliedToInvoice: applied,
                    pendingAmount: pending,
                    status: status,
                    transactions: dtos
                )
            )
        }
        return summaries.sorted { $0.pendingAmount > $1.pendingAmount }
    }

    private func evaluateBudgetAlert(for category: Category, month: Int, year: Int) throws -> BudgetThresholdAlert? {
        guard !category.isIncome, let budget = category.monthlyBudget, budget > 0 else {
            return nil
        }

        let (startOfMonth, endOfMonth) = monthDateBounds(month: month, year: year)
        let debitTxs = try modelContext.fetch(
            FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    $0.date >= startOfMonth && $0.date < endOfMonth
                }
            )
        )

        let targetCategoryID = category.persistentModelID
        var spent = 0.0
        for tx in debitTxs where tx.paymentMethod == .debitPix && tx.kind == .expense && !tx.isThirdParty {
            if tx.category?.persistentModelID == targetCategoryID {
                spent += tx.amount
            }
        }

        let invoices = try modelContext.fetch(
            FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { $0.month == month && $0.year == year }
            )
        )
        for inv in invoices {
            for tx in inv.safeTransactions where !tx.isThirdParty {
                if tx.category?.persistentModelID == targetCategoryID {
                    spent += tx.amount
                }
            }
        }

        let percentage = (spent / budget) * 100.0
        if percentage >= 100.0 {
            return BudgetThresholdAlert(
                categoryId: category.id,
                categoryName: category.name,
                spent: spent,
                budget: budget,
                percentage: percentage,
                level: .critical100,
                month: month,
                year: year
            )
        } else if percentage >= 80.0 {
            return BudgetThresholdAlert(
                categoryId: category.id,
                categoryName: category.name,
                spent: spent,
                budget: budget,
                percentage: percentage,
                level: .warning80,
                month: month,
                year: year
            )
        }
        return nil
    }

    private func makeDTO(from tx: Transaction) -> TransactionDTO {
        TransactionDTO(
            persistentID: tx.persistentModelID,
            uuid: tx.id,
            title: tx.title,
            amount: tx.amount,
            date: tx.date,
            paymentMethod: tx.paymentMethod,
            kind: tx.kind,
            isThirdParty: tx.isThirdParty,
            installmentIndex: tx.installmentIndex,
            totalInstallments: tx.totalInstallments,
            isPaidOrSettled: tx.isPaidOrSettled,
            categoryName: tx.category?.name,
            categoryIcon: tx.category?.iconName,
            categoryColorHex: tx.category?.colorHex,
            accountName: tx.account?.name,
            borrowerID: tx.borrower?.persistentModelID,
            borrowerName: tx.borrower?.name,
            borrowerPhone: tx.borrower?.phone,
            invoiceID: tx.invoice?.persistentModelID,
            cardName: tx.invoice?.card?.name
        )
    }

    private func monthDateBounds(month: Int, year: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let start = calendar.date(from: components) ?? Date()
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }
}

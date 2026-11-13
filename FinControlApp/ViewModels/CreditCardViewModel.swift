import Foundation
import Observation
import SwiftData

enum InvoiceFilterTab: String, CaseIterable, Sendable {
    case overview = "Visão Geral"
    case myExpenses = "Meus Gastos"
    case thirdPartyByPerson = "Cartão Emprestado"
}

@Observable
@MainActor
final class CreditCardViewModel {
    var selectedMonth: Int
    var selectedYear: Int
    var cards: [CardMetrics] = []
    var selectedCardID: PersistentIdentifier?
    var invoiceDetail: InvoiceDetailSnapshot?
    var allBorrowerSummaries: [BorrowerMonthlySummary] = []
    var selectedFilter: InvoiceFilterTab = .overview
    var isLoading: Bool = false
    var settlementSuccessTrigger: Bool = false
    var errorMessage: String?

    private var engine: FinanceEngineActor?

    init(date: Date = Date()) {
        let calendar = Calendar.current
        self.selectedMonth = calendar.component(.month, from: date)
        self.selectedYear = calendar.component(.year, from: date)
    }

    func configure(container: ModelContainer) {
        if engine == nil {
            engine = FinanceEngineActor(modelContainer: container)
        }
        Task {
            await loadCardsAndLoans()
        }
    }

    func shiftMonth(by delta: Int) {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        guard let current = calendar.date(from: components),
              let next = calendar.date(byAdding: .month, value: delta, to: current) else {
            return
        }
        selectedMonth = calendar.component(.month, from: next)
        selectedYear = calendar.component(.year, from: next)
        Task {
            await loadCardsAndLoans()
            if let cardID = selectedCardID {
                await loadInvoiceDetail(for: cardID)
            }
        }
    }

    func loadCardsAndLoans() async {
        guard let engine else { return }
        isLoading = cards.isEmpty
        defer { isLoading = false }

        do {
            cards = try await engine.fetchCardMetricsList(month: selectedMonth, year: selectedYear)
            allBorrowerSummaries = try await engine.fetchAllThirdPartyLoans(month: selectedMonth, year: selectedYear)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadInvoiceDetail(for cardID: PersistentIdentifier) async {
        guard let engine else { return }
        selectedCardID = cardID
        do {
            invoiceDetail = try await engine.fetchInvoiceDetail(
                cardID: cardID,
                month: selectedMonth,
                year: selectedYear
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func settleTransaction(
        transactionID: PersistentIdentifier,
        type: SettlementType,
        destinationAccountID: PersistentIdentifier?
    ) async {
        guard let engine else { return }
        do {
            try await engine.settleThirdPartyTransaction(
                transactionID: transactionID,
                type: type,
                destinationAccountID: destinationAccountID
            )
            settlementSuccessTrigger.toggle()
            await reloadCurrentContext()
            NotificationCenter.default.post(name: .finControlDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func settleBorrowerMonthly(
        borrowerID: PersistentIdentifier,
        invoiceID: PersistentIdentifier,
        amount: Double,
        type: SettlementType,
        destinationAccountID: PersistentIdentifier?
    ) async {
        guard let engine else { return }
        do {
            try await engine.settleBorrowerInvoice(
                borrowerID: borrowerID,
                invoiceID: invoiceID,
                amount: amount,
                type: type,
                destinationAccountID: destinationAccountID
            )
            settlementSuccessTrigger.toggle()
            await reloadCurrentContext()
            NotificationCenter.default.post(name: .finControlDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func payInvoice(invoiceID: PersistentIdentifier, accountID: PersistentIdentifier?) async {
        guard let engine else { return }
        do {
            try await engine.markInvoiceAsPaid(invoiceID: invoiceID, paymentAccountID: accountID)
            settlementSuccessTrigger.toggle()
            await reloadCurrentContext()
            NotificationCenter.default.post(name: .finControlDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadCurrentContext() async {
        await loadCardsAndLoans()
        if let selectedCardID {
            await loadInvoiceDetail(for: selectedCardID)
        }
    }
}

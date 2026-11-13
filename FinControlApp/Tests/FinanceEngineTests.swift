import XCTest
import SwiftData
@testable import FinControlApp

@MainActor
final class FinanceEngineTests: XCTestCase {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Account.self,
            Category.self,
            CreditCard.self,
            Borrower.self,
            Invoice.self,
            Transaction.self,
            ThirdPartySettlement.self,
            Investment.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testRN01_ReimbursementNeverCountsAsPersonalIncome() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let account = Account(name: "Nubank", initialBalance: 1000, currentBalance: 1000)
        let salaryCat = Category(name: "Salário", isIncome: true)
        let joao = Borrower(name: "João")
        context.insert(account)
        context.insert(salaryCat)
        context.insert(joao)
        try context.save()

        let engine = FinanceEngineActor(modelContainer: container)
        let now = Date()

        _ = try await engine.recordTransaction(
            NewTransactionInput(
                title: "Salário",
                amount: 5000,
                date: now,
                paymentMethod: .debitPix,
                kind: .income,
                installments: 1,
                isThirdParty: false,
                accountID: account.persistentModelID,
                destinationAccountID: nil,
                cardID: nil,
                categoryID: salaryCat.persistentModelID,
                borrowerID: nil
            )
        )

        _ = try await engine.recordTransaction(
            NewTransactionInput(
                title: "Reembolso João",
                amount: 800,
                date: now,
                paymentMethod: .reimbursement,
                kind: .thirdPartyReimbursement,
                installments: 1,
                isThirdParty: true,
                accountID: account.persistentModelID,
                destinationAccountID: nil,
                cardID: nil,
                categoryID: nil,
                borrowerID: joao.persistentModelID
            )
        )

        let cal = Calendar.current
        let snapshot = try await engine.fetchDashboardSnapshot(
            month: cal.component(.month, from: now),
            year: cal.component(.year, from: now)
        )

        XCTAssertEqual(snapshot.totalAccountsBalance, 6800, accuracy: 0.001)
        XCTAssertEqual(snapshot.monthlyPersonalIncome, 5000, accuracy: 0.001)
    }

    func testRN02AndRN03_AvailableLimitAndInvoiceAccountingSeparation() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let card = CreditCard(name: "Ultra", totalLimit: 10_000, closingDay: 25, dueDay: 5)
        let food = Category(name: "Alimentação", isIncome: false, monthlyBudget: 1_000)
        let maria = Borrower(name: "Maria")
        context.insert(card)
        context.insert(food)
        context.insert(maria)
        try context.save()

        let engine = FinanceEngineActor(modelContainer: container)

        // Purchase on day 10 (before closingDay 25 -> current month invoice)
        var comps = Calendar.current.dateComponents([.year, .month], from: Date())
        comps.day = 10
        let purchaseDate = Calendar.current.date(from: comps) ?? Date()
        let month = comps.month ?? 1
        let year = comps.year ?? 2026

        _ = try await engine.recordTransaction(
            NewTransactionInput(
                title: "Mercado",
                amount: 600,
                date: purchaseDate,
                paymentMethod: .creditCard,
                kind: .expense,
                installments: 1,
                isThirdParty: false,
                accountID: nil,
                destinationAccountID: nil,
                cardID: card.persistentModelID,
                categoryID: food.persistentModelID,
                borrowerID: nil
            )
        )

        _ = try await engine.recordTransaction(
            NewTransactionInput(
                title: "Passagem Maria",
                amount: 1400,
                date: purchaseDate,
                paymentMethod: .creditCard,
                kind: .expense,
                installments: 1,
                isThirdParty: true,
                accountID: nil,
                destinationAccountID: nil,
                cardID: card.persistentModelID,
                categoryID: nil,
                borrowerID: maria.persistentModelID
            )
        )

        var detail = try await engine.fetchInvoiceDetail(cardID: card.persistentModelID, month: month, year: year)
        XCTAssertEqual(detail.grossTotal, 2000, accuracy: 0.001)
        XCTAssertEqual(detail.ownTotal, 600, accuracy: 0.001)
        XCTAssertEqual(detail.thirdPartyTotal, 1400, accuracy: 0.001)
        XCTAssertEqual(detail.netPayable, 2000, accuracy: 0.001)

        var metricsList = try await engine.fetchCardMetricsList(month: month, year: year)
        XCTAssertEqual(metricsList.first?.availableLimit ?? -1, 8000, accuracy: 0.001)

        // Apply R$ 1400 settlement directly to invoice (RN04 Option 2)
        try await engine.settleBorrowerInvoice(
            borrowerID: maria.persistentModelID,
            invoiceID: detail.invoiceID,
            amount: 1400,
            type: .appliedToInvoice,
            destinationAccountID: nil
        )

        detail = try await engine.fetchInvoiceDetail(cardID: card.persistentModelID, month: month, year: year)
        XCTAssertEqual(detail.prepaidAmount, 1400, accuracy: 0.001)
        XCTAssertEqual(detail.netPayable, 600, accuracy: 0.001)

        metricsList = try await engine.fetchCardMetricsList(month: month, year: year)
        // Available limit restored from 8000 to 9400 after prepaid settlement
        XCTAssertEqual(metricsList.first?.availableLimit ?? -1, 9400, accuracy: 0.001)
    }

    func testRN04_InstallmentClosingDayAndCentSplit() {
        let split = InvoiceGeneratorService.splitAmountInCents(totalAmount: 100.0, installments: 3)
        XCTAssertEqual(split.count, 3)
        XCTAssertEqual(split.reduce(0, +), 100.0, accuracy: 0.0001)
        XCTAssertEqual(split[0], 33.34, accuracy: 0.0001)
        XCTAssertEqual(split[1], 33.33, accuracy: 0.0001)
        XCTAssertEqual(split[2], 33.33, accuracy: 0.0001)

        let calendar = Calendar(identifier: .gregorian)
        let beforeClosing = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15))!
        let onClosing = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20))!

        let p1 = InvoiceGeneratorService.targetInvoiceMonthYear(
            purchaseDate: beforeClosing,
            closingDay: 20,
            installmentIndex: 1,
            calendar: calendar
        )
        XCTAssertEqual(p1.month, 11)
        XCTAssertEqual(p1.year, 2026)

        let p2 = InvoiceGeneratorService.targetInvoiceMonthYear(
            purchaseDate: onClosing,
            closingDay: 20,
            installmentIndex: 2,
            calendar: calendar
        )
        // Purchase on closingDay 20 -> installment 1 in Dec/2026, installment 2 in Jan/2027
        XCTAssertEqual(p2.month, 1)
        XCTAssertEqual(p2.year, 2027)
    }

    func testRN05_BudgetAlerts80And100ExcludeThirdParty() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let card = CreditCard(name: "Itaú", totalLimit: 5000, closingDay: 28, dueDay: 5)
        let leisure = Category(name: "Lazer", isIncome: false, monthlyBudget: 1000)
        let lucas = Borrower(name: "Lucas")
        context.insert(card)
        context.insert(leisure)
        context.insert(lucas)
        try context.save()

        let engine = FinanceEngineActor(modelContainer: container)
        var comps = Calendar.current.dateComponents([.year, .month], from: Date())
        comps.day = 5
        let date = Calendar.current.date(from: comps) ?? Date()

        // Third-party purchase of 1500 must NOT trigger personal budget alert
        let thirdPartyAlerts = try await engine.recordTransaction(
            NewTransactionInput(
                title: "Show Lucas",
                amount: 1500,
                date: date,
                paymentMethod: .creditCard,
                kind: .expense,
                installments: 1,
                isThirdParty: true,
                accountID: nil,
                destinationAccountID: nil,
                cardID: card.persistentModelID,
                categoryID: leisure.persistentModelID,
                borrowerID: lucas.persistentModelID
            )
        )
        XCTAssertTrue(thirdPartyAlerts.isEmpty)

        // Personal purchase of 850 (85% of 1000) -> .warning80
        let alerts80 = try await engine.recordTransaction(
            NewTransactionInput(
                title: "Cinema & Jantar",
                amount: 850,
                date: date,
                paymentMethod: .creditCard,
                kind: .expense,
                installments: 1,
                isThirdParty: false,
                accountID: nil,
                destinationAccountID: nil,
                cardID: card.persistentModelID,
                categoryID: leisure.persistentModelID,
                borrowerID: nil
            )
        )
        XCTAssertEqual(alerts80.first?.level, .warning80)

        // Additional 200 -> 1050 (105% of 1000) -> .critical100
        let alerts100 = try await engine.recordTransaction(
            NewTransactionInput(
                title: "Ingressos",
                amount: 200,
                date: date,
                paymentMethod: .creditCard,
                kind: .expense,
                installments: 1,
                isThirdParty: false,
                accountID: nil,
                destinationAccountID: nil,
                cardID: card.persistentModelID,
                categoryID: leisure.persistentModelID,
                borrowerID: nil
            )
        )
        XCTAssertEqual(alerts100.first?.level, .critical100)
    }
}

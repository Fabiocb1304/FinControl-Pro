import Foundation
import SwiftData

@MainActor
enum SeedDataService {
    /// Populates realistic sample data on first launch so all dashboards, charts,
    /// third-party loans, and investments work immediately for testing.
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // 1. Accounts
        let nubankAccount = Account(
            name: "Nubank",
            initialBalance: 4_500.00,
            currentBalance: 6_840.50,
            colorHex: "#8A05BE",
            iconName: "building.columns.fill"
        )
        let itauAccount = Account(
            name: "Itaú Personnalité",
            initialBalance: 10_000.00,
            currentBalance: 12_350.00,
            colorHex: "#EC7000",
            iconName: "creditcard.and.123"
        )
        let walletAccount = Account(
            name: "Carteira",
            initialBalance: 450.00,
            currentBalance: 320.00,
            colorHex: "#30D158",
            iconName: "banknote.fill"
        )
        [nubankAccount, itauAccount, walletAccount].forEach { context.insert($0) }

        // 2. Categories
        let foodCat = Category(name: "Alimentação", iconName: "fork.knife", colorHex: "#FF9F0A", isIncome: false, monthlyBudget: 1_800)
        let housingCat = Category(name: "Moradia", iconName: "house.fill", colorHex: "#0A84FF", isIncome: false, monthlyBudget: 3_200)
        let transportCat = Category(name: "Transporte", iconName: "car.fill", colorHex: "#5E5CE6", isIncome: false, monthlyBudget: 900)
        let leisureCat = Category(name: "Lazer", iconName: "gamecontroller.fill", colorHex: "#FF375F", isIncome: false, monthlyBudget: 800)
        let healthCat = Category(name: "Saúde", iconName: "heart.fill", colorHex: "#30D158", isIncome: false, monthlyBudget: 600)
        let salaryCat = Category(name: "Salário", iconName: "briefcase.fill", colorHex: "#34C759", isIncome: true, monthlyBudget: nil)
        [foodCat, housingCat, transportCat, leisureCat, healthCat, salaryCat].forEach { context.insert($0) }

        // 3. Borrowers
        let joao = Borrower(name: "João Silva", phone: "11998877665", avatarColorHex: "#FF9F0A")
        let maria = Borrower(name: "Maria Clara", phone: "11991234567", avatarColorHex: "#BF5AF2")
        let lucas = Borrower(name: "Lucas Pereira", phone: "11987654321", avatarColorHex: "#64D2FF")
        [joao, maria, lucas].forEach { context.insert($0) }

        // 4. Credit Cards & Monthly Invoices
        let ultraCard = CreditCard(
            name: "Nubank Ultravioleta",
            totalLimit: 18_000,
            closingDay: 22,
            dueDay: 1,
            colorHex: "#4B1B78"
        )
        let itauCard = CreditCard(
            name: "Itaú Black",
            totalLimit: 25_000,
            closingDay: 18,
            dueDay: 25,
            colorHex: "#1C1C1E"
        )
        [ultraCard, itauCard].forEach { context.insert($0) }

        let currentUltraInvoice = Invoice(month: currentMonth, year: currentYear, status: .open, prepaidAmount: 450.00, card: ultraCard)
        let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        let nextMonth = calendar.component(.month, from: nextMonthDate)
        let nextYear = calendar.component(.year, from: nextMonthDate)
        let nextUltraInvoice = Invoice(month: nextMonth, year: nextYear, status: .open, prepaidAmount: 0, card: ultraCard)

        let currentItauInvoice = Invoice(month: currentMonth, year: currentYear, status: .open, prepaidAmount: 0, card: itauCard)
        [currentUltraInvoice, nextUltraInvoice, currentItauInvoice].forEach { context.insert($0) }

        // 5. Account Transactions (Income, Expense, Transfer, Reimbursement)
        let daysAgo: (Int) -> Date = { offset in
            calendar.date(byAdding: .day, value: -offset, to: now) ?? now
        }

        let salaryTx = Transaction(
            title: "Salário Mensal",
            amount: 11_500.00,
            date: daysAgo(10),
            paymentMethod: .debitPix,
            kind: .income,
            isPaidOrSettled: true,
            account: itauAccount,
            category: salaryCat
        )
        let rentTx = Transaction(
            title: "Aluguel + Condomínio",
            amount: 2_850.00,
            date: daysAgo(8),
            paymentMethod: .debitPix,
            kind: .expense,
            isPaidOrSettled: true,
            account: itauAccount,
            category: housingCat
        )
        let marketTx = Transaction(
            title: "Supermercado Pão de Açúcar",
            amount: 640.50,
            date: daysAgo(3),
            paymentMethod: .debitPix,
            kind: .expense,
            isPaidOrSettled: true,
            account: nubankAccount,
            category: foodCat
        )
        let pharmacyTx = Transaction(
            title: "Drogasil",
            amount: 195.00,
            date: daysAgo(1),
            paymentMethod: .debitPix,
            kind: .expense,
            isPaidOrSettled: true,
            account: nubankAccount,
            category: healthCat
        )
        // Reembolso de terceiro recebido na conta (RN01: não soma em Receita Pessoal)
        let reimbursementTx = Transaction(
            title: "Reembolso Maria Clara (Fatura)",
            amount: 550.00,
            date: daysAgo(2),
            paymentMethod: .reimbursement,
            kind: .thirdPartyReimbursement,
            isThirdParty: true,
            isPaidOrSettled: true,
            account: nubankAccount,
            borrower: maria
        )

        // 6. Credit Card Transactions (Own vs Third Party)
        let ownFoodCard = Transaction(
            title: "iFood & Restaurantes",
            amount: 820.00,
            date: daysAgo(4),
            paymentMethod: .creditCard,
            kind: .expense,
            isThirdParty: false,
            installmentIndex: 1,
            totalInstallments: 1,
            account: nil,
            category: foodCat,
            invoice: currentUltraInvoice
        )
        let ownTransportCard = Transaction(
            title: "Uber & Combustível",
            amount: 460.00,
            date: daysAgo(2),
            paymentMethod: .creditCard,
            kind: .expense,
            isThirdParty: false,
            installmentIndex: 1,
            totalInstallments: 1,
            category: transportCat,
            invoice: currentUltraInvoice
        )
        let ownLeisureCard = Transaction(
            title: "Ingressos Show & Cinema",
            amount: 690.00,
            date: daysAgo(1),
            paymentMethod: .creditCard,
            kind: .expense,
            isThirdParty: false,
            installmentIndex: 1,
            totalInstallments: 1,
            category: leisureCat,
            invoice: currentItauInvoice
        )

        // Third-party installment purchases
        let notebookGroupId = UUID()
        let joaoNotebook1 = Transaction(
            parentTransactionId: notebookGroupId,
            title: "Notebook Dell (João)",
            amount: 900.00,
            date: daysAgo(6),
            paymentMethod: .creditCard,
            kind: .expense,
            isThirdParty: true,
            installmentIndex: 1,
            totalInstallments: 3,
            isPaidOrSettled: false,
            invoice: currentUltraInvoice,
            borrower: joao
        )
        let joaoNotebook2 = Transaction(
            parentTransactionId: notebookGroupId,
            title: "Notebook Dell (João)",
            amount: 900.00,
            date: daysAgo(6),
            paymentMethod: .creditCard,
            kind: .expense,
            isThirdParty: true,
            installmentIndex: 2,
            totalInstallments: 3,
            isPaidOrSettled: false,
            invoice: nextUltraInvoice,
            borrower: joao
        )

        let mariaFlight = Transaction(
            title: "Passagem Aérea LATAM",
            amount: 550.00,
            date: daysAgo(5),
            paymentMethod: .creditCard,
            kind: .expense,
            isThirdParty: true,
            installmentIndex: 1,
            totalInstallments: 1,
            isPaidOrSettled: true,
            invoice: currentUltraInvoice,
            borrower: maria
        )

        let lucasBike = Transaction(
            title: "Bicicleta Aro 29",
            amount: 450.00,
            date: daysAgo(7),
            paymentMethod: .creditCard,
            kind: .expense,
            isThirdParty: true,
            installmentIndex: 1,
            totalInstallments: 2,
            isPaidOrSettled: true,
            invoice: currentUltraInvoice,
            borrower: lucas
        )

        [
            salaryTx, rentTx, marketTx, pharmacyTx, reimbursementTx,
            ownFoodCard, ownTransportCard, ownLeisureCard,
            joaoNotebook1, joaoNotebook2, mariaFlight, lucasBike
        ].forEach { context.insert($0) }

        // Settlements matching Maria (ReceivedInAccount) and Lucas (AppliedToInvoice - matches prepaidAmount 450)
        let mariaSettlement = ThirdPartySettlement(
            amount: 550.00,
            date: daysAgo(2),
            settlementType: .receivedInAccount,
            borrower: maria,
            invoice: currentUltraInvoice,
            destinationAccount: nubankAccount
        )
        let lucasSettlement = ThirdPartySettlement(
            amount: 450.00,
            date: daysAgo(3),
            settlementType: .appliedToInvoice,
            borrower: lucas,
            invoice: currentUltraInvoice,
            destinationAccount: nil
        )
        [mariaSettlement, lucasSettlement].forEach { context.insert($0) }

        // 7. Investments
        let selic = Investment(
            name: "Tesouro Selic 2029",
            assetClass: .fixedIncome,
            institution: "XP Investimentos",
            investedAmount: 25_000.00,
            currentBalance: 28_420.00
        )
        let petr4 = Investment(
            name: "PETR4",
            assetClass: .stocks,
            institution: "NuInvest",
            investedAmount: 8_000.00,
            currentBalance: 9_340.00
        )
        let hglg11 = Investment(
            name: "HGLG11",
            assetClass: .realEstateFunds,
            institution: "BTG Pactual",
            investedAmount: 10_000.00,
            currentBalance: 10_680.00
        )
        let btc = Investment(
            name: "Bitcoin (BTC)",
            assetClass: .crypto,
            institution: "Mercado Bitcoin",
            investedAmount: 5_000.00,
            currentBalance: 6_450.00
        )
        [selic, petr4, hglg11, btc].forEach { context.insert($0) }

        // Recalculate invoice caches
        currentUltraInvoice.recalculateCache()
        nextUltraInvoice.recalculateCache()
        currentItauInvoice.recalculateCache()

        try? context.save()
    }
}

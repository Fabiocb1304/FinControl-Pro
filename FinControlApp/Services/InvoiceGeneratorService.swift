import Foundation
import SwiftData

enum InvoiceGeneratorService {
    /// Determines the (month, year) of a given installment based on the card's closing day.
    /// Purchases on or after `closingDay` roll into the next billing cycle.
    static func targetInvoiceMonthYear(
        purchaseDate: Date,
        closingDay: Int,
        installmentIndex: Int,
        calendar: Calendar = .current
    ) -> (month: Int, year: Int) {
        let day = calendar.component(.day, from: purchaseDate)
        let baseMonthOffset = day >= closingDay ? 1 : 0
        let totalMonthOffset = baseMonthOffset + max(0, installmentIndex - 1)

        var startComponents = calendar.dateComponents([.year, .month], from: purchaseDate)
        startComponents.day = 1
        let baseDate = calendar.date(from: startComponents) ?? purchaseDate
        let targetDate = calendar.date(byAdding: .month, value: totalMonthOffset, to: baseDate) ?? purchaseDate

        return (
            month: calendar.component(.month, from: targetDate),
            year: calendar.component(.year, from: targetDate)
        )
    }

    /// Splits a monetary amount into `N` installments without floating-point cent drift.
    static func splitAmountInCents(totalAmount: Double, installments: Int) -> [Double] {
        let count = max(1, installments)
        let totalCents = Int((totalAmount * 100.0).rounded())
        let baseCents = totalCents / count
        let remainder = totalCents % count

        return (0..<count).map { index in
            let cents = baseCents + (index < remainder ? 1 : 0)
            return Double(cents) / 100.0
        }
    }

    /// Fetches or creates the monthly `Invoice` for the specified `CreditCard`.
    static func findOrCreateInvoice(
        for card: CreditCard,
        month: Int,
        year: Int,
        in context: ModelContext
    ) throws -> Invoice {
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { invoice in
                invoice.month == month && invoice.year == year
            }
        )
        let candidates = try context.fetch(descriptor)
        if let existing = candidates.first(where: { $0.card?.persistentModelID == card.persistentModelID }) {
            return existing
        }

        let newInvoice = Invoice(
            month: month,
            year: year,
            status: .open,
            prepaidAmount: 0.0,
            card: card
        )
        context.insert(newInvoice)
        return newInvoice
    }

    /// Creates 1...N installment `Transaction` records linked to their respective monthly invoices.
    @discardableResult
    static func generateInstallments(
        title: String,
        totalAmount: Double,
        purchaseDate: Date,
        installments: Int,
        card: CreditCard,
        category: Category?,
        isThirdParty: Bool,
        borrower: Borrower?,
        in context: ModelContext
    ) throws -> [Invoice] {
        let count = min(max(installments, 1), 24)
        let amounts = splitAmountInCents(totalAmount: totalAmount, installments: count)
        let parentGroupId = count > 1 ? UUID() : nil
        var touchedInvoices: [PersistentIdentifier: Invoice] = [:]

        for index in 1...count {
            let period = targetInvoiceMonthYear(
                purchaseDate: purchaseDate,
                closingDay: card.closingDay,
                installmentIndex: index
            )
            let invoice = try findOrCreateInvoice(
                for: card,
                month: period.month,
                year: period.year,
                in: context
            )
            touchedInvoices[invoice.persistentModelID] = invoice

            let tx = Transaction(
                parentTransactionId: parentGroupId,
                title: title,
                amount: amounts[index - 1],
                date: purchaseDate,
                paymentMethod: .creditCard,
                kind: .expense,
                isThirdParty: isThirdParty,
                installmentIndex: index,
                totalInstallments: count,
                isPaidOrSettled: false,
                account: nil,
                category: isThirdParty ? nil : category,
                invoice: invoice,
                borrower: isThirdParty ? borrower : nil
            )
            context.insert(tx)
        }

        for invoice in touchedInvoices.values {
            invoice.recalculateCache()
        }

        return Array(touchedInvoices.values)
    }

    /// Automatically marks open invoices whose closing day has passed as `Closed`.
    static func closeElapsedInvoices(referenceDate: Date = Date(), in context: ModelContext) throws {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: referenceDate)
        let currentMonth = calendar.component(.month, from: referenceDate)
        let currentDay = calendar.component(.day, from: referenceDate)

        let openRaw = InvoiceStatus.open.rawValue
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.statusRaw == openRaw }
        )
        let openInvoices = try context.fetch(descriptor)

        for invoice in openInvoices {
            guard let card = invoice.card else { continue }
            let isPastMonth = (invoice.year < currentYear) || (invoice.year == currentYear && invoice.month < currentMonth)
            let isCurrentMonthPastClosing = (invoice.year == currentYear && invoice.month == currentMonth && currentDay >= card.closingDay)

            if isPastMonth || isCurrentMonthPastClosing {
                invoice.status = .closed
            }
            invoice.recalculateCache()
        }
    }
}

import Foundation
import SwiftData

enum PaymentMethod: String, Codable, CaseIterable, Sendable {
    case debitPix = "DebitPix"
    case creditCard = "CreditCard"
    case transfer = "Transfer"
    case reimbursement = "Reimbursement"

    var localizedTitle: String {
        switch self {
        case .debitPix: return "Débito / Pix"
        case .creditCard: return "Cartão de Crédito"
        case .transfer: return "Transferência"
        case .reimbursement: return "Reembolso"
        }
    }

    var systemImage: String {
        switch self {
        case .debitPix: return "qrcode"
        case .creditCard: return "creditcard.fill"
        case .transfer: return "arrow.left.arrow.right"
        case .reimbursement: return "person.crop.circle.badge.checkmark"
        }
    }
}

/// Distinguishes cashflow nature in RN01 while keeping `paymentMethodRaw` aligned with the spec.
enum TransactionKind: String, Codable, CaseIterable, Sendable {
    case income = "Income"
    case expense = "Expense"
    case transfer = "Transfer"
    case thirdPartyReimbursement = "ThirdPartyReimbursement"

    var localizedTitle: String {
        switch self {
        case .income: return "Receita"
        case .expense: return "Despesa"
        case .transfer: return "Transferência"
        case .thirdPartyReimbursement: return "Reembolso de Terceiro"
        }
    }
}

@Model
final class Transaction {
    var id: UUID = UUID()
    var parentTransactionId: UUID?
    var title: String = ""
    var amount: Double = 0.0
    var date: Date = Date()
    var paymentMethodRaw: String = PaymentMethod.debitPix.rawValue
    var transactionKindRaw: String = TransactionKind.expense.rawValue
    var isThirdParty: Bool = false
    var installmentIndex: Int = 1
    var totalInstallments: Int = 1
    var isPaidOrSettled: Bool = false
    var destinationAccountId: UUID?

    var account: Account?
    var category: Category?
    var invoice: Invoice?
    var borrower: Borrower?

    init(
        id: UUID = UUID(),
        parentTransactionId: UUID? = nil,
        title: String,
        amount: Double,
        date: Date = Date(),
        paymentMethod: PaymentMethod,
        kind: TransactionKind = .expense,
        isThirdParty: Bool = false,
        installmentIndex: Int = 1,
        totalInstallments: Int = 1,
        isPaidOrSettled: Bool = false,
        destinationAccountId: UUID? = nil,
        account: Account? = nil,
        category: Category? = nil,
        invoice: Invoice? = nil,
        borrower: Borrower? = nil
    ) {
        self.id = id
        self.parentTransactionId = parentTransactionId
        self.title = title
        self.amount = amount
        self.date = date
        self.paymentMethodRaw = paymentMethod.rawValue
        self.transactionKindRaw = kind.rawValue
        self.isThirdParty = isThirdParty
        self.installmentIndex = installmentIndex
        self.totalInstallments = totalInstallments
        self.isPaidOrSettled = isPaidOrSettled
        self.destinationAccountId = destinationAccountId
        self.account = account
        self.category = category
        self.invoice = invoice
        self.borrower = borrower
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .debitPix }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: transactionKindRaw) ?? .expense }
        set { transactionKindRaw = newValue.rawValue }
    }

    var installmentBadge: String? {
        guard totalInstallments > 1 else { return nil }
        return "\(installmentIndex)/\(totalInstallments)"
    }
}

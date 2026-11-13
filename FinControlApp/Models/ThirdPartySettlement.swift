import Foundation
import SwiftData

enum SettlementType: String, Codable, CaseIterable, Sendable {
    case receivedInAccount = "ReceivedInAccount"
    case appliedToInvoice = "AppliedToInvoice"

    var localizedTitle: String {
        switch self {
        case .receivedInAccount: return "Recebido na Conta"
        case .appliedToInvoice: return "Abatido Direto na Fatura"
        }
    }

    var descriptionText: String {
        switch self {
        case .receivedInAccount:
            return "O valor entra no saldo da conta como reembolso, sem contar como receita pessoal."
        case .appliedToInvoice:
            return "Adiantado na fatura: reduz o saldo a pagar e libera o limite imediatamente."
        }
    }
}

@Model
final class ThirdPartySettlement {
    var id: UUID = UUID()
    var amount: Double = 0.0
    var date: Date = Date()
    var settlementTypeRaw: String = SettlementType.receivedInAccount.rawValue

    var borrower: Borrower?
    var invoice: Invoice?
    var destinationAccount: Account?

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        settlementType: SettlementType,
        borrower: Borrower? = nil,
        invoice: Invoice? = nil,
        destinationAccount: Account? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.settlementTypeRaw = settlementType.rawValue
        self.borrower = borrower
        self.invoice = invoice
        self.destinationAccount = destinationAccount
    }

    var settlementType: SettlementType {
        get { SettlementType(rawValue: settlementTypeRaw) ?? .receivedInAccount }
        set { settlementTypeRaw = newValue.rawValue }
    }
}

import Foundation
import SwiftData

enum InvoiceStatus: String, Codable, CaseIterable, Sendable {
    case open = "Open"
    case closed = "Closed"
    case paid = "Paid"

    var localizedTitle: String {
        switch self {
        case .open: return "Aberta"
        case .closed: return "Fechada"
        case .paid: return "Paga"
        }
    }
}

@Model
final class Invoice {
    var id: UUID = UUID()
    var month: Int = 1
    var year: Int = 2026
    var statusRaw: String = InvoiceStatus.open.rawValue
    var prepaidAmount: Double = 0.0

    // Cached monthly summary fields for instant Dashboard rendering (120 FPS)
    var cachedOwnTotal: Double = 0.0
    var cachedThirdPartyTotal: Double = 0.0
    var cachedGrossTotal: Double = 0.0
    var cachedNetPayable: Double = 0.0

    var card: CreditCard?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.invoice)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .cascade, inverse: \ThirdPartySettlement.invoice)
    var settlements: [ThirdPartySettlement]? = []

    init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        status: InvoiceStatus = .open,
        prepaidAmount: Double = 0.0,
        card: CreditCard? = nil
    ) {
        self.id = id
        self.month = min(max(month, 1), 12)
        self.year = year
        self.statusRaw = status.rawValue
        self.prepaidAmount = prepaidAmount
        self.card = card
    }

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var safeTransactions: [Transaction] {
        transactions ?? []
    }

    var safeSettlements: [ThirdPartySettlement] {
        settlements ?? []
    }

    /// Recomputes and caches RN03 monthly invoice totals on the model.
    func recalculateCache() {
        let items = safeTransactions
        let own = items.filter { !$0.isThirdParty }.reduce(0.0) { $0 + $1.amount }
        let thirdParty = items.filter { $0.isThirdParty }.reduce(0.0) { $0 + $1.amount }
        let gross = own + thirdParty
        let netPayable = max(0.0, gross - prepaidAmount)

        self.cachedOwnTotal = own
        self.cachedThirdPartyTotal = thirdParty
        self.cachedGrossTotal = gross
        self.cachedNetPayable = netPayable
    }
}

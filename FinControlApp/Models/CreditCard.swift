import Foundation
import SwiftData

@Model
final class CreditCard {
    var id: UUID = UUID()
    var name: String = ""
    var totalLimit: Double = 0.0
    var closingDay: Int = 1
    var dueDay: Int = 10
    var colorHex: String = "#1C1C1E"

    @Relationship(deleteRule: .cascade, inverse: \Invoice.card)
    var invoices: [Invoice]? = []

    init(
        id: UUID = UUID(),
        name: String,
        totalLimit: Double,
        closingDay: Int,
        dueDay: Int,
        colorHex: String = "#1C1C1E"
    ) {
        self.id = id
        self.name = name
        self.totalLimit = totalLimit
        self.closingDay = min(max(closingDay, 1), 31)
        self.dueDay = min(max(dueDay, 1), 31)
        self.colorHex = colorHex
    }

    var safeInvoices: [Invoice] {
        invoices ?? []
    }
}

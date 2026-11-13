import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var initialBalance: Double = 0.0
    var currentBalance: Double = 0.0
    var colorHex: String = "#0A84FF"
    var iconName: String = "building.columns.fill"

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \ThirdPartySettlement.destinationAccount)
    var incomingSettlements: [ThirdPartySettlement]? = []

    init(
        id: UUID = UUID(),
        name: String,
        initialBalance: Double = 0.0,
        currentBalance: Double? = nil,
        colorHex: String = "#0A84FF",
        iconName: String = "building.columns.fill"
    ) {
        self.id = id
        self.name = name
        self.initialBalance = initialBalance
        self.currentBalance = currentBalance ?? initialBalance
        self.colorHex = colorHex
        self.iconName = iconName
    }

    var safeTransactions: [Transaction] {
        transactions ?? []
    }
}

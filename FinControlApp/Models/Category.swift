import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "tag.fill"
    var colorHex: String = "#5E5CE6"
    var isIncome: Bool = false
    var monthlyBudget: Double?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "tag.fill",
        colorHex: String = "#5E5CE6",
        isIncome: Bool = false,
        monthlyBudget: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isIncome = isIncome
        self.monthlyBudget = monthlyBudget
    }

    var safeTransactions: [Transaction] {
        transactions ?? []
    }
}

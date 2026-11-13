import Foundation
import SwiftData

@Model
final class Borrower {
    var id: UUID = UUID()
    var name: String = ""
    var phone: String?
    var avatarColorHex: String = "#FF9F0A"

    @Relationship(deleteRule: .cascade, inverse: \Transaction.borrower)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .cascade, inverse: \ThirdPartySettlement.borrower)
    var settlements: [ThirdPartySettlement]? = []

    init(
        id: UUID = UUID(),
        name: String,
        phone: String? = nil,
        avatarColorHex: String = "#FF9F0A"
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.avatarColorHex = avatarColorHex
    }

    var safeTransactions: [Transaction] {
        transactions ?? []
    }

    var safeSettlements: [ThirdPartySettlement] {
        settlements ?? []
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

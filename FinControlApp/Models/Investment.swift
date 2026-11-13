import Foundation
import SwiftData

enum AssetClass: String, Codable, CaseIterable, Sendable {
    case fixedIncome = "FixedIncome"
    case stocks = "Stocks"
    case realEstateFunds = "RealEstateFunds"
    case crypto = "Crypto"

    var localizedTitle: String {
        switch self {
        case .fixedIncome: return "Renda Fixa"
        case .stocks: return "Ações"
        case .realEstateFunds: return "FIIs"
        case .crypto: return "Cripto"
        }
    }

    var colorHex: String {
        switch self {
        case .fixedIncome: return "#30D158"
        case .stocks: return "#0A84FF"
        case .realEstateFunds: return "#FF9F0A"
        case .crypto: return "#BF5AF2"
        }
    }

    var systemImage: String {
        switch self {
        case .fixedIncome: return "banknote.fill"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .realEstateFunds: return "building.2.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        }
    }
}

@Model
final class Investment {
    var id: UUID = UUID()
    var name: String = ""
    var assetClassRaw: String = AssetClass.fixedIncome.rawValue
    var institution: String = ""
    var investedAmount: Double = 0.0
    var currentBalance: Double = 0.0
    var lastUpdated: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        assetClass: AssetClass,
        institution: String,
        investedAmount: Double,
        currentBalance: Double,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.assetClassRaw = assetClass.rawValue
        self.institution = institution
        self.investedAmount = investedAmount
        self.currentBalance = currentBalance
        self.lastUpdated = lastUpdated
    }

    var assetClass: AssetClass {
        get { AssetClass(rawValue: assetClassRaw) ?? .fixedIncome }
        set { assetClassRaw = newValue.rawValue }
    }

    var profitAmount: Double {
        currentBalance - investedAmount
    }

    var profitPercentage: Double {
        guard investedAmount > 0 else { return 0 }
        return (profitAmount / investedAmount) * 100.0
    }
}

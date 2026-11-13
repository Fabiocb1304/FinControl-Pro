import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class InvestmentViewModel {
    var portfolio: InvestmentPortfolioSnapshot?
    var isLoading: Bool = false
    var actionSuccessTrigger: Bool = false
    var errorMessage: String?

    private var engine: FinanceEngineActor?

    func configure(container: ModelContainer) {
        if engine == nil {
            engine = FinanceEngineActor(modelContainer: container)
        }
        Task {
            await load()
        }
    }

    func load() async {
        guard let engine else { return }
        isLoading = portfolio == nil
        defer { isLoading = false }

        do {
            portfolio = try await engine.fetchInvestmentPortfolio()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addContribution(
        investmentID: PersistentIdentifier?,
        name: String,
        assetClass: AssetClass,
        institution: String,
        amount: Double,
        debitAccountID: PersistentIdentifier?
    ) async {
        guard let engine else { return }
        do {
            try await engine.addInvestmentContribution(
                investmentID: investmentID,
                name: name,
                assetClass: assetClass,
                institution: institution,
                amount: amount,
                debitAccountID: debitAccountID
            )
            actionSuccessTrigger.toggle()
            await load()
            NotificationCenter.default.post(name: .finControlDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateBalance(investmentID: PersistentIdentifier, newBalance: Double) async {
        guard let engine else { return }
        do {
            try await engine.updateInvestmentBalance(investmentID: investmentID, newBalance: newBalance)
            actionSuccessTrigger.toggle()
            await load()
            NotificationCenter.default.post(name: .finControlDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

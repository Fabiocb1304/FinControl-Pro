import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AccountExtractViewModel {
    var accounts: [AccountSummaryDTO] = []
    var dayGroups: [ExtractDayGroup] = []
    var selectedAccountID: PersistentIdentifier? = nil
    var isLoading: Bool = false
    var errorMessage: String?

    private var engine: FinanceEngineActor?

    var totalBalance: Double {
        accounts.reduce(0.0) { $0 + $1.currentBalance }
    }

    func configure(container: ModelContainer) {
        if engine == nil {
            engine = FinanceEngineActor(modelContainer: container)
        }
        Task {
            await load()
        }
    }

    func selectAccount(_ accountID: PersistentIdentifier?) {
        selectedAccountID = (selectedAccountID == accountID) ? nil : accountID
        Task {
            await load()
        }
    }

    func load() async {
        guard let engine else { return }
        isLoading = accounts.isEmpty
        defer { isLoading = false }

        do {
            let result = try await engine.fetchAccountExtract(accountFilter: selectedAccountID)
            accounts = result.accounts
            dayGroups = result.groups
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTransaction(_ id: PersistentIdentifier) async {
        guard let engine else { return }
        do {
            try await engine.deleteTransaction(transactionID: id)
            await load()
            NotificationCenter.default.post(name: .finControlDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

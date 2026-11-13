import Foundation
import Observation
import SwiftData

extension Notification.Name {
    static let finControlDataDidChange = Notification.Name("finControlDataDidChange")
}

@Observable
@MainActor
final class DashboardViewModel {
    var selectedMonth: Int
    var selectedYear: Int
    var isPrivacyHidden: Bool = false
    var snapshot: DashboardSnapshot?
    var isLoading: Bool = false
    var errorMessage: String?

    private var engine: FinanceEngineActor?

    init(date: Date = Date()) {
        let calendar = Calendar.current
        self.selectedMonth = calendar.component(.month, from: date)
        self.selectedYear = calendar.component(.year, from: date)
    }

    func configure(container: ModelContainer) {
        if engine == nil {
            engine = FinanceEngineActor(modelContainer: container)
        }
        Task {
            await load()
        }
    }

    func shiftMonth(by delta: Int) {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        guard let current = calendar.date(from: components),
              let next = calendar.date(byAdding: .month, value: delta, to: current) else {
            return
        }
        selectedMonth = calendar.component(.month, from: next)
        selectedYear = calendar.component(.year, from: next)
        Task {
            await load()
        }
    }

    func load() async {
        guard let engine else { return }
        isLoading = snapshot == nil
        defer { isLoading = false }

        do {
            snapshot = try await engine.fetchDashboardSnapshot(
                month: selectedMonth,
                year: selectedYear
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

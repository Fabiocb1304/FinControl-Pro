import Foundation
import UserNotifications

struct BudgetThresholdAlert: Sendable, Hashable {
    enum Level: Int, Sendable {
        case warning80 = 80
        case critical100 = 100
    }

    let categoryId: UUID
    let categoryName: String
    let spent: Double
    let budget: Double
    let percentage: Double
    let level: Level
    let month: Int
    let year: Int
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func dispatchBudgetAlerts(_ alerts: [BudgetThresholdAlert]) async {
        guard !alerts.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        for alert in alerts {
            let identifier = "budget-\(alert.categoryId.uuidString)-\(alert.year)-\(alert.month)-\(alert.level.rawValue)"
            let content = UNMutableNotificationContent()

            switch alert.level {
            case .warning80:
                content.title = "Atenção ao Orçamento: \(alert.categoryName)"
                content.body = "Você atingiu \(Int(alert.percentage.rounded()))% da meta mensal (\(Formatters.currency(alert.spent)) de \(Formatters.currency(alert.budget)))."
            case .critical100:
                content.title = "Meta Excedida: \(alert.categoryName)"
                content.body = "Gastos em \(Formatters.currency(alert.spent)) ultrapassaram o teto de \(Formatters.currency(alert.budget)) (\(Int(alert.percentage.rounded()))%)."
            }
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func scheduleInvoiceDueReminder(
        cardId: UUID,
        cardName: String,
        dueDay: Int,
        month: Int,
        year: Int,
        netPayable: Double
    ) async {
        guard netPayable > 0 else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = dueDay
        components.hour = 9
        components.minute = 0

        guard let dueDate = calendar.date(from: components),
              let reminderDate = calendar.date(byAdding: .day, value: -2, to: dueDate),
              reminderDate > Date() else {
            return
        }

        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let content = UNMutableNotificationContent()
        content.title = "Vencimento próximo: \(cardName)"
        content.body = "Sua fatura de \(Formatters.monthYearTitle(month: month, year: year)) vence em 2 dias. Saldo a pagar: \(Formatters.currency(netPayable))."
        content.sound = .default

        let identifier = "invoice-due-\(cardId.uuidString)-\(year)-\(month)"
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}

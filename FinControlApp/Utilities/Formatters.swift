import Foundation

enum Formatters {
    static let ptBR = Locale(identifier: "pt_BR")

    static func currency(_ value: Double) -> String {
        value.formatted(
            .currency(code: "BRL")
                .locale(ptBR)
                .precision(.fractionLength(2))
        )
    }

    static func percentage(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        let formatted = (value / 100.0).formatted(
            .percent
                .locale(ptBR)
                .precision(.fractionLength(1...2))
        )
        return "\(sign)\(formatted)"
    }

    static func monthYearTitle(month: Int, year: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%02d/%04d", month, year)
        }
        let raw = date.formatted(
            Date.FormatStyle()
                .locale(ptBR)
                .month(.wide)
                .year()
        )
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    static func shortMonthTitle(month: Int, year: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%02d/%02d", month, year % 100)
        }
        return date.formatted(
            Date.FormatStyle()
                .locale(ptBR)
                .month(.abbreviated)
        ).capitalized
    }

    static func daySectionTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoje"
        }
        if calendar.isDateInYesterday(date) {
            return "Ontem"
        }
        return date.formatted(
            Date.FormatStyle()
                .locale(ptBR)
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
        ).capitalized
    }

    static func whatsAppChargeMessage(
        borrowerName: String,
        cardName: String,
        month: Int,
        year: Int,
        items: [(title: String, installment: String?, amount: Double)],
        pendingAmount: Double
    ) -> String {
        let period = monthYearTitle(month: month, year: year)
        var lines: [String] = [
            "Olá, \(borrowerName)! Segue o resumo do cartão *\(cardName)* referente a *\(period)*:",
            ""
        ]
        for item in items {
            let suffix = item.installment.map { " (\($0))" } ?? ""
            lines.append("• \(item.title)\(suffix): \(currency(item.amount))")
        }
        lines.append("")
        lines.append("*Total a acertar: \(currency(pendingAmount))*")
        return lines.joined(separator: "\n")
    }

    static func whatsAppURL(phone: String?, message: String) -> URL? {
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let phone, !phone.isEmpty {
            let digits = phone.filter(\.isNumber)
            let normalized = digits.hasPrefix("55") ? digits : "55\(digits)"
            return URL(string: "https://wa.me/\(normalized)?text=\(encoded)")
        }
        return URL(string: "https://wa.me/?text=\(encoded)")
    }
}

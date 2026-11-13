import SwiftUI

struct AnimatedCurrencyText: View {
    let value: Double
    var font: Font = .system(.title2, design: .rounded, weight: .bold)
    var color: Color = .primary
    var isPrivacyHidden: Bool = false
    var showSign: Bool = false

    private var formattedString: String {
        let base = Formatters.currency(abs(value))
        if value < 0 {
            return "-\(base)"
        } else if showSign && value > 0 {
            return "+\(base)"
        }
        return base
    }

    var body: some View {
        Text(formattedString)
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
            .animation(.spring(duration: 0.35, bounce: 0.15), value: value)
            .redacted(reason: isPrivacyHidden ? .placeholder : [])
    }
}

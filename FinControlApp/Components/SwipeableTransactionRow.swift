import SwiftUI

/// Custom 120 FPS swipeable row compatible with `LazyVStack` inside `ScrollView`.
/// - Swipe Right (leading reveal): "Marcar como Recebido / Abater" on unsettled third-party expenses.
/// - Swipe Left (trailing reveal): "Cobrar via WhatsApp" (`ShareLink` + direct `wa.me` action) on third-party expenses.
struct SwipeableTransactionRow: View {
    let transaction: TransactionDTO
    var isPrivacyHidden: Bool = false
    var onSettleTapped: (() -> Void)? = nil
    var whatsAppChargeText: String? = nil

    @State private var offsetX: CGFloat = 0
    @State private var hapticSelectionTrigger = false
    @Environment(\.openURL) private var openURL

    private let actionWidth: CGFloat = 112

    private var canSwipeRight: Bool {
        transaction.isThirdParty && !transaction.isPaidOrSettled && onSettleTapped != nil
    }

    private var canSwipeLeft: Bool {
        transaction.isThirdParty && whatsAppChargeText != nil
    }

    var body: some View {
        ZStack {
            if offsetX > 0 && canSwipeRight {
                HStack {
                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            offsetX = 0
                        }
                        onSettleTapped?()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("Receber / Abater")
                                .font(.caption2.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Spacer()
                }
            }

            if offsetX < 0 && canSwipeLeft, let chargeText = whatsAppChargeText {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Button {
                            if let url = Formatters.whatsAppURL(phone: transaction.borrowerPhone, message: chargeText) {
                                openURL(url)
                            }
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                offsetX = 0
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "message.fill")
                                    .font(.title3)
                                Text("WhatsApp")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(width: 72)
                            .frame(maxHeight: .infinity)
                            .background(Color(hex: "#25D366").gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        ShareLink(item: chargeText) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                Text("Enviar")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(width: 58)
                            .frame(maxHeight: .infinity)
                            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            }

            rowContent
                .offset(x: offsetX)
                .gesture(swipeGesture)
        }
        .sensoryFeedback(.selection, trigger: hapticSelectionTrigger)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if let badge = transaction.installmentBadge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    if transaction.isThirdParty {
                        Label(transaction.borrowerName ?? "Terceiro", systemImage: "person.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                    } else if let categoryName = transaction.categoryName {
                        Text(categoryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(transaction.kind.localizedTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let accountName = transaction.accountName {
                        Text("• \(accountName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let cardName = transaction.cardName {
                        Text("• \(cardName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                AnimatedCurrencyText(
                    value: signedAmount,
                    font: .system(.subheadline, design: .rounded, weight: .bold),
                    color: amountColor,
                    isPrivacyHidden: isPrivacyHidden,
                    showSign: transaction.kind == .income || transaction.kind == .thirdPartyReimbursement
                )

                if transaction.isThirdParty {
                    Text(transaction.isPaidOrSettled ? "Acertado" : "Pendente")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(transaction.isPaidOrSettled ? .green : .orange)
                } else {
                    Text(transaction.date.formatted(.dateTime.day().month(.abbreviated).locale(Formatters.ptBR)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if offsetX != 0 {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    offsetX = 0
                }
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                guard canSwipeRight || canSwipeLeft else { return }
                let translation = value.translation.width
                if translation > 0 && canSwipeRight {
                    offsetX = min(translation, actionWidth + 16)
                } else if translation < 0 && canSwipeLeft {
                    offsetX = max(translation, -148)
                }
            }
            .onEnded { value in
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    if value.translation.width > 56 && canSwipeRight {
                        offsetX = actionWidth + 8
                        hapticSelectionTrigger.toggle()
                    } else if value.translation.width < -56 && canSwipeLeft {
                        offsetX = -138
                        hapticSelectionTrigger.toggle()
                    } else {
                        offsetX = 0
                    }
                }
            }
    }

    private var iconName: String {
        if transaction.kind == .thirdPartyReimbursement {
            return "person.crop.circle.badge.checkmark"
        }
        if transaction.isThirdParty {
            return "person.2.fill"
        }
        return transaction.categoryIcon ?? transaction.paymentMethod.systemImage
    }

    private var iconColor: Color {
        if transaction.kind == .thirdPartyReimbursement {
            return .green
        }
        if transaction.isThirdParty {
            return .orange
        }
        if let hex = transaction.categoryColorHex {
            return Color(hex: hex)
        }
        return transaction.kind == .income ? .green : .blue
    }

    private var signedAmount: Double {
        switch transaction.kind {
        case .income, .thirdPartyReimbursement:
            return transaction.amount
        case .expense:
            return transaction.paymentMethod == .creditCard ? transaction.amount : -transaction.amount
        case .transfer:
            return transaction.amount
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .income:
            return .green
        case .thirdPartyReimbursement:
            return .mint
        case .expense:
            return transaction.isThirdParty ? .orange : .primary
        case .transfer:
            return .secondary
        }
    }
}

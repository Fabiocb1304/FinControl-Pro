import SwiftUI
import SwiftData

struct CardsListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CreditCardViewModel()
    @Namespace private var cardNamespace
    @State private var activeDetailCard: CardMetrics?
    @State private var selectionTrigger = false

    var isPrivacyHidden: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                if let selectedCard = activeDetailCard {
                    InvoiceDetailView(
                        card: selectedCard,
                        viewModel: viewModel,
                        namespace: cardNamespace,
                        isPrivacyHidden: isPrivacyHidden
                    ) {
                        activeDetailCard = nil
                    }
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    .zIndex(2)
                } else {
                    mainScrollContent
                        .zIndex(1)
                }
            }
            .navigationTitle(activeDetailCard == nil ? "Cartões & Empréstimos" : "")
            .navigationBarHidden(activeDetailCard != nil)
        }
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .onAppear {
            viewModel.configure(container: modelContext.container)
        }
        .onReceive(NotificationCenter.default.publisher(for: .finControlDataDidChange)) { _ in
            Task {
                await viewModel.loadCardsAndLoans()
                if let activeDetailCard {
                    await viewModel.loadInvoiceDetail(for: activeDetailCard.cardID)
                }
            }
        }
    }

    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthSwitcher

                cardsCarousel

                VStack(alignment: .leading, spacing: 12) {
                    Text("Empréstimos de Cartão no Mês")
                        .font(.title3.weight(.bold))
                        .padding(.horizontal, 16)

                    ThirdPartyLoansView(
                        summaries: viewModel.allBorrowerSummaries,
                        isPrivacyHidden: isPrivacyHidden
                    ) { summary, type, accountID in
                        Task {
                            await viewModel.settleBorrowerMonthly(
                                borrowerID: summary.borrowerID,
                                invoiceID: summary.invoiceID,
                                amount: summary.pendingAmount > 0.01 ? summary.pendingAmount : summary.totalDue,
                                type: type,
                                destinationAccountID: accountID
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                selectionTrigger.toggle()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    viewModel.shiftMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Formatters.monthYearTitle(month: viewModel.selectedMonth, year: viewModel.selectedYear))
                .font(.headline.weight(.semibold))
                .contentTransition(.numericText())

            Spacer()

            Button {
                selectionTrigger.toggle()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    viewModel.shiftMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private var cardsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.cards) { card in
                    creditCardTile(card)
                        .frame(width: 318)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.94)
                                .rotation3DEffect(
                                    .degrees(phase.value * -8),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                        }
                        .onTapGesture {
                            selectionTrigger.toggle()
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                activeDetailCard = card
                            }
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func creditCardTile(_ card: CardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Fecha dia \(card.closingDay) • Vence dia \(card.dueDay)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fatura do Mês (Saldo a Pagar)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                    AnimatedCurrencyText(
                        value: card.currentMonthNetPayable,
                        font: .system(.title2, design: .rounded, weight: .bold),
                        color: .white,
                        isPrivacyHidden: isPrivacyHidden
                    )
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Meu Custo Real")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                    AnimatedCurrencyText(
                        value: card.currentMonthOwn,
                        font: .system(.subheadline, design: .rounded, weight: .semibold),
                        color: Color(hex: "#64D2FF"),
                        isPrivacyHidden: isPrivacyHidden
                    )
                }
            }

            threeColorLimitBar(card)

            HStack {
                Text("Disponível: \(Formatters.currency(card.availableLimit))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("Toque para detalhar →")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: card.colorHex), Color(hex: card.colorHex).opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .matchedGeometryEffect(id: "card-\(card.uuid.uuidString)", in: cardNamespace)
    }

    private func threeColorLimitBar(_ card: CardMetrics) -> some View {
        let total = max(card.totalLimit, 1.0)
        // Net own and third-party ratio relative to total limit
        let ownRatio = min(max(card.openOwnAmount / total, 0), 1)
        let thirdRatio = min(max(card.openThirdPartyAmount / total, 0), max(0, 1 - ownRatio))
        let availableRatio = max(0, 1 - ownRatio - thirdRatio)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if ownRatio > 0 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: "#0A84FF"))
                            .frame(width: geo.size.width * ownRatio)
                    }
                    if thirdRatio > 0 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: "#FF9F0A"))
                            .frame(width: geo.size.width * thirdRatio)
                    }
                    if availableRatio > 0 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.25))
                    }
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: ownRatio + thirdRatio)

            HStack(spacing: 12) {
                legendDot(color: Color(hex: "#0A84FF"), text: "Meu uso")
                legendDot(color: Color(hex: "#FF9F0A"), text: "Terceiros")
                legendDot(color: Color.white.opacity(0.4), text: "Livre")
                Spacer()
            }
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

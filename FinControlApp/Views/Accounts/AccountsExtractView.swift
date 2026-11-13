import SwiftUI
import SwiftData

struct AccountsExtractView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AccountExtractViewModel()
    @State private var selectionTrigger = false

    var isPrivacyHidden: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    accountsHorizontalStrip

                    extractLazyTimeline
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Extrato de Contas")
            .sensoryFeedback(.selection, trigger: selectionTrigger)
            .onAppear {
                viewModel.configure(container: modelContext.container)
            }
            .onReceive(NotificationCenter.default.publisher(for: .finControlDataDidChange)) { _ in
                Task { await viewModel.load() }
            }
        }
    }

    private var accountsHorizontalStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                GlassCardView(
                    cornerRadius: 18,
                    padding: 14,
                    tintColor: viewModel.selectedAccountID == nil ? .blue : nil
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Todas as Contas", systemImage: "tray.full.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        AnimatedCurrencyText(
                            value: viewModel.totalBalance,
                            font: .system(.headline, design: .rounded, weight: .bold),
                            isPrivacyHidden: isPrivacyHidden
                        )
                    }
                    .frame(minWidth: 140, alignment: .leading)
                }
                .onTapGesture {
                    selectionTrigger.toggle()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        viewModel.selectAccount(nil)
                    }
                }

                ForEach(viewModel.accounts) { account in
                    let isSelected = viewModel.selectedAccountID == account.persistentID
                    GlassCardView(
                        cornerRadius: 18,
                        padding: 14,
                        tintColor: isSelected ? Color(hex: account.colorHex) : nil
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(account.name, systemImage: account.iconName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: account.colorHex))
                                .lineLimit(1)
                            AnimatedCurrencyText(
                                value: account.currentBalance,
                                font: .system(.headline, design: .rounded, weight: .bold),
                                isPrivacyHidden: isPrivacyHidden
                            )
                        }
                        .frame(minWidth: 145, alignment: .leading)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isSelected ? Color(hex: account.colorHex) : .clear, lineWidth: 1.5)
                    }
                    .onTapGesture {
                        selectionTrigger.toggle()
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            viewModel.selectAccount(account.persistentID)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var extractLazyTimeline: some View {
        LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
            if viewModel.dayGroups.isEmpty {
                GlassCardView(cornerRadius: 20, padding: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Sem movimentações em conta")
                            .font(.subheadline.weight(.semibold))
                        Text("Receitas, débitos, Pix e reembolsos aparecerão aqui agrupados por dia.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
            } else {
                ForEach(viewModel.dayGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        ForEach(group.transactions) { tx in
                            SwipeableTransactionRow(
                                transaction: tx,
                                isPrivacyHidden: isPrivacyHidden
                            )
                            .padding(.horizontal, 16)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteTransaction(tx.persistentID) }
                                } label: {
                                    Label("Excluir Lançamento", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

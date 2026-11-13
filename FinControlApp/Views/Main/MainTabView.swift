import SwiftUI

enum MainTab: Int, CaseIterable, Sendable {
    case dashboard = 0
    case cards = 1
    case accounts = 2
    case investments = 3

    var title: String {
        switch self {
        case .dashboard: return "Resumo"
        case .cards: return "Cartões"
        case .accounts: return "Contas"
        case .investments: return "Investir"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .cards: return "creditcard.fill"
        case .accounts: return "list.bullet.rectangle.portrait.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .dashboard
    @State private var showAddTransactionSheet: Bool = false
    @State private var isPrivacyHidden: Bool = false
    @State private var tabSwitchTrigger: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(isPrivacyHidden: $isPrivacyHidden)
                case .cards:
                    CardsListView(isPrivacyHidden: isPrivacyHidden)
                case .accounts:
                    AccountsExtractView(isPrivacyHidden: isPrivacyHidden)
                case .investments:
                    InvestmentsPortfolioView(isPrivacyHidden: isPrivacyHidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 76)
            }

            customFloatingTabBar
        }
        .sensoryFeedback(.selection, trigger: tabSwitchTrigger)
        .sheet(isPresented: $showAddTransactionSheet) {
            AddTransactionSheet()
        }
    }

    private var customFloatingTabBar: some View {
        HStack(spacing: 4) {
            tabButton(.dashboard)
            tabButton(.cards)

            // Central (+) Quick Entry Button
            Button {
                tabSwitchTrigger.toggle()
                showAddTransactionSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: .blue.opacity(0.35), radius: 8, x: 0, y: 4)

                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 6)
            .offset(y: -6)
            .accessibilityLabel("Novo lançamento")

            tabButton(.accounts)
            tabButton(.investments)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            tabSwitchTrigger.toggle()
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                Text(tab.title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.blue : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

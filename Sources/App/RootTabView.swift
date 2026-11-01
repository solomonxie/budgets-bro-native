import SwiftUI

/// Nav shell per docs/design/uiux/README.md's diagram — flush tabs with an
/// explicit background, Settings as a header button (not a tab slot),
/// Spend intercepts its own tab press instead of switching the displayed
/// tab. Hand-rolled bottom bar rather than SwiftUI's `TabView`: iOS 26+'s
/// default tab bar renders as a floating translucent pill even with a
/// background style applied, which the design explicitly calls out as
/// wrong for this near-black theme — "iOS's translucent blur reads as a
/// stray dark bar."
struct RootTabView: View {
    enum Tab: Hashable {
        case budget, accounts, insights
    }

    @State private var selectedTab: Tab = .budget
    @State private var isAddTransactionPresented = false
    @State private var isSettingsPresented = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .budget:
                    NavigationStack { BudgetView().toolbar { settingsToolbarItem } }
                case .accounts:
                    NavigationStack { AccountsView().toolbar { settingsToolbarItem } }
                case .insights:
                    NavigationStack { InsightsView().toolbar { settingsToolbarItem } }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(selectedTab: $selectedTab) {
                isAddTransactionPresented = true
            }
        }
        .background(Theme.page)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(Theme.accent)
        .fullScreenCover(isPresented: $isAddTransactionPresented) {
            AddTransactionView()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }
}

private struct BottomTabBar: View {
    @Binding var selectedTab: RootTabView.Tab
    let onSpendTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.border)
            HStack(spacing: 0) {
                tabButton(.budget, icon: .budget, label: "Budget")
                spendButton
                tabButton(.accounts, icon: .accounts, label: "Accounts")
                tabButton(.insights, icon: .insights, label: "Insights")
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(Theme.surface)
    }

    private var spendButton: some View {
        Button(action: onSpendTap) {
            VStack(spacing: 4) {
                TabBarIcon(name: .add, color: Theme.textMuted)
                Text("Spend")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func tabButton(_ tab: RootTabView.Tab, icon: TabIconName, label: String) -> some View {
        let tint = selectedTab == tab ? Theme.accent : Theme.textMuted
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                TabBarIcon(name: icon, color: tint)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    RootTabView()
}

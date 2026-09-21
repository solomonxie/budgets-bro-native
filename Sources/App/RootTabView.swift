import SwiftUI

/// Nav shell per docs/design/uiux/README.md's diagram — flush tabs, Settings
/// as a header button (not a tab slot), Spend intercepts its own tab press
/// instead of switching the displayed tab.
struct RootTabView: View {
    private enum Tab: Hashable {
        case budget, spend, accounts, insights
    }

    @State private var selectedTab: Tab = .budget
    @State private var previousTab: Tab = .budget
    @State private var isAddTransactionPresented = false
    @State private var isSettingsPresented = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BudgetView()
                    .toolbar { settingsToolbarItem }
            }
            .tabItem { Text("Budget") }
            .tag(Tab.budget)

            Color.clear
                .tabItem { Text("✛ Spend") }
                .tag(Tab.spend)

            NavigationStack {
                AccountsView()
                    .toolbar { settingsToolbarItem }
            }
            .tabItem { Text("Accounts") }
            .tag(Tab.accounts)

            NavigationStack {
                InsightsView()
                    .toolbar { settingsToolbarItem }
            }
            .tabItem { Text("Insights") }
            .tag(Tab.insights)
        }
        .tint(Theme.accent)
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .spend else {
                previousTab = newValue
                return
            }
            selectedTab = previousTab
            isAddTransactionPresented = true
        }
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
                Image(systemName: "gearshape")
            }
        }
    }
}

#Preview {
    RootTabView()
}

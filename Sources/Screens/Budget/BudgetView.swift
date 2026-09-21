import SwiftUI

/// Per docs/design/uiux/budget.md — placeholder until Phase 3 (T3.1).
struct BudgetView: View {
    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            Text("Budget")
                .foregroundStyle(.white)
        }
        .navigationTitle("Budget")
    }
}
